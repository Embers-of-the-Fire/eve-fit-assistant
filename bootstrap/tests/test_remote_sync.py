"""Tests for Syncer download failure classification (bootstrap/remote/sync.py).

Only a confirmed-missing remote object (S3 404/NoSuchKey) may be reported as
``False``; every other download failure (access denied, missing bucket,
timeout, connection error) must raise, so `--allow-missing-head` never masks
a real failure as an absent channel.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

import pytest

from bootstrap.remote.s3client import ClientError
from bootstrap.remote.sync import Syncer


if TYPE_CHECKING:
    from collections.abc import Callable
    from pathlib import Path


def _client_error(code: str, message: str = "") -> ClientError:
    return ClientError({"Error": {"Code": code, "Message": message}}, "GetObject")


class _FakeS3Client:
    """Stand-in for S3Client driven by a per-key handler.

    The handler receives (key, dest) and returns True (downloaded), False
    (confirmed missing), or raises ClientError/BotoCoreError (failure).
    """

    def __init__(self, handler: Callable[[str, Path], bool]) -> None:
        self._handler = handler

    def download_file(self, key: str, dest: Path) -> bool:
        return self._handler(key, dest)

    def download_dir(self, key: str, dest_dir: Path) -> bool:
        return self._handler(key, dest_dir)


def _make_syncer(tmp_path: Path, handler: Callable[[str, Path], bool]) -> Syncer:
    return Syncer(tmp_path, client=_FakeS3Client(handler), bucket="bucket")


class TestDownloadClassification:
    def test_success_returns_true(self, tmp_path: Path) -> None:
        syncer = _make_syncer(tmp_path, lambda key, dest: True)
        assert syncer._download_head_metadata("stable") is True

    def test_confirmed_missing_returns_false(self, tmp_path: Path) -> None:
        syncer = _make_syncer(tmp_path, lambda key, dest: False)
        assert syncer._download_head_metadata("stable") is False

    def test_recursive_missing_prefix_returns_false(self, tmp_path: Path) -> None:
        syncer = _make_syncer(tmp_path, lambda key, dest: False)
        assert syncer._download_generation("aa") is False

    def test_recursive_failure_raises(self, tmp_path: Path) -> None:
        def handler(key: str, dest: Path) -> bool:
            if key.startswith("efa/v2/channels/refs/"):
                raise _client_error("AccessDenied", "Access Denied.")
            return True

        syncer = _make_syncer(tmp_path, handler)
        with pytest.raises(OSError, match="Failed to download"):
            syncer._download_generation("aa")

    def test_mixed_results_abort_generation_walk(self, tmp_path: Path) -> None:
        head_dir = tmp_path / "channels" / "heads" / "stable"

        def handler(key: str, dest: Path) -> bool:
            if key.endswith("refs/aa"):
                raise _client_error("AccessDenied", "Access Denied.")
            if key.endswith("metadata.json") and "/heads/" in key:
                head_dir.mkdir(parents=True, exist_ok=True)
                (head_dir / "metadata.json").write_text('{"generationHash": "aa"}')
                return True
            return True

        syncer = _make_syncer(tmp_path, handler)
        with pytest.raises(OSError, match="Failed to download"):
            syncer.sync_channel("stable")

    def test_access_denied_raises(self, tmp_path: Path) -> None:
        def handler(key: str, dest: Path) -> bool:
            raise _client_error("AccessDenied", "Access Denied.")

        syncer = _make_syncer(tmp_path, handler)
        with pytest.raises(OSError, match="Failed to download"):
            syncer._download_head_metadata("stable")

    def test_missing_bucket_raises(self, tmp_path: Path) -> None:
        """A missing bucket is a configuration failure, not an absent object.

        NoSuchBucket only reaches the Syncer from body-carrying (GET) errors;
        on the HEAD-based download path a missing bucket arrives as a bare
        "404" and is reclassified by S3Client — see test_s3client.py.
        """

        def handler(key: str, dest: Path) -> bool:
            raise _client_error("NoSuchBucket", "The specified bucket does not exist.")

        syncer = _make_syncer(tmp_path, handler)
        with pytest.raises(OSError, match="Failed to download"):
            syncer._download_head_metadata("stable")

    def test_bad_access_key_raises(self, tmp_path: Path) -> None:
        def handler(key: str, dest: Path) -> bool:
            raise _client_error("InvalidAccessKeyId", "The access key does not exist.")

        syncer = _make_syncer(tmp_path, handler)
        with pytest.raises(OSError, match="Failed to download"):
            syncer._download_head_metadata("stable")

    def test_timeout_raises(self, tmp_path: Path) -> None:
        from botocore.exceptions import ReadTimeoutError

        def handler(key: str, dest: Path) -> bool:
            raise ReadTimeoutError(endpoint_url="http://mock.invalid")

        syncer = _make_syncer(tmp_path, handler)
        with pytest.raises(OSError, match="Failed to download"):
            syncer._download_head_metadata("stable")

    def test_connection_error_raises(self, tmp_path: Path) -> None:
        from botocore.exceptions import EndpointConnectionError

        def handler(key: str, dest: Path) -> bool:
            raise EndpointConnectionError(endpoint_url="http://mock.invalid")

        syncer = _make_syncer(tmp_path, handler)
        with pytest.raises(OSError, match="Failed to download"):
            syncer._download_head_metadata("stable")


class TestSyncChannelFailurePropagation:
    def test_head_failure_raises_instead_of_reporting_absent(self, tmp_path: Path) -> None:
        def handler(key: str, dest: Path) -> bool:
            if key.endswith("channels.json"):
                return True
            raise _client_error("AccessDenied", "Access Denied.")

        syncer = _make_syncer(tmp_path, handler)
        with pytest.raises(OSError, match="Failed to download"):
            syncer.sync_channel("stable")

    def test_confirmed_missing_head_returns_early(self, tmp_path: Path) -> None:
        def handler(key: str, dest: Path) -> bool:
            if key.endswith("channels.json"):
                return True
            if key.endswith("metadata.json"):
                return False
            pytest.fail(f"unexpected download after missing head: {key}")
            raise AssertionError

        syncer = _make_syncer(tmp_path, handler)
        result = syncer.sync_channel("stable")
        assert result.head_meta is False
        assert result.suppressions is False

    def test_missing_suppressions_still_tolerated(self, tmp_path: Path) -> None:
        head_dir = tmp_path / "channels" / "heads" / "stable"

        def handler(key: str, dest: Path) -> bool:
            if key.endswith("suppressions.json"):
                return False
            if key.endswith("metadata.json"):
                head_dir.mkdir(parents=True, exist_ok=True)
                (head_dir / "metadata.json").write_text('{"generationHash": ""}')
            return True

        syncer = _make_syncer(tmp_path, handler)
        result = syncer.sync_channel("stable")
        assert result.head_meta is True
        assert result.suppressions is False

    def test_suppressions_failure_raises(self, tmp_path: Path) -> None:
        head_dir = tmp_path / "channels" / "heads" / "stable"

        def handler(key: str, dest: Path) -> bool:
            if key.endswith("suppressions.json"):
                raise _client_error("AccessDenied", "Access Denied.")
            if key.endswith("metadata.json"):
                head_dir.mkdir(parents=True, exist_ok=True)
                (head_dir / "metadata.json").write_text('{"generationHash": ""}')
            return True

        syncer = _make_syncer(tmp_path, handler)
        with pytest.raises(OSError, match="Failed to download"):
            syncer.sync_channel("stable")
