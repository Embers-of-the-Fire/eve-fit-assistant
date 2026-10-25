"""Tests for Syncer download failure classification (bootstrap/remote/sync.py).

Only a confirmed-missing remote object may be reported as ``False``; every
other download failure (nonzero mc exit, timeout, missing executable) must
raise, so `--allow-missing-head` never masks a real failure as an absent
channel.
"""

from __future__ import annotations

import subprocess

from typing import TYPE_CHECKING
from typing import Any

import pytest

from bootstrap.remote import sync as sync_module
from bootstrap.remote.sync import Syncer


if TYPE_CHECKING:
    from pathlib import Path


def _completed(returncode: int, stderr: str = "") -> subprocess.CompletedProcess[str]:
    return subprocess.CompletedProcess(args=["mc"], returncode=returncode, stdout="", stderr=stderr)


@pytest.fixture
def syncer(tmp_path: Path) -> Syncer:
    s = Syncer(tmp_path, alias_name="alias", bucket="bucket", mc_bin="mc")
    s._alias_set = True
    s._s3_prefix = "alias/bucket/efa/v2"
    return s


class TestDownloadClassification:
    def test_success_returns_true(
        self, syncer: Syncer, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        monkeypatch.setattr(sync_module.subprocess, "run", lambda *a, **kw: _completed(0))
        assert syncer._download_head_metadata("stable") is True

    def test_confirmed_missing_returns_false(
        self, syncer: Syncer, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr(
            sync_module.subprocess,
            "run",
            lambda *a, **kw: _completed(
                1, "mc: <ERROR> Unable to prepare URL for copying. Object does not exist"
            ),
        )
        assert syncer._download_head_metadata("stable") is False

    def test_s3_no_such_key_returns_false(
        self, syncer: Syncer, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        monkeypatch.setattr(
            sync_module.subprocess,
            "run",
            lambda *a, **kw: _completed(
                1, "mc: <ERROR> Failed to copy. The specified key does not exist."
            ),
        )
        assert syncer._download_head_metadata("stable") is False

    def test_access_denied_raises(self, syncer: Syncer, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(
            sync_module.subprocess,
            "run",
            lambda *a, **kw: _completed(
                1, "mc: <ERROR> Unable to prepare URL for copying. Access Denied."
            ),
        )
        with pytest.raises(OSError, match="Failed to download"):
            syncer._download_head_metadata("stable")

    def test_missing_bucket_raises(self, syncer: Syncer, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(
            sync_module.subprocess,
            "run",
            lambda *a, **kw: _completed(
                1,
                "mc: <ERROR> Unable to prepare URL for copying. Bucket `nobucket` does not exist.",
            ),
        )
        with pytest.raises(OSError, match="Failed to download"):
            syncer._download_head_metadata("stable")

    def test_bad_access_key_raises(self, syncer: Syncer, monkeypatch: pytest.MonkeyPatch) -> None:
        monkeypatch.setattr(
            sync_module.subprocess,
            "run",
            lambda *a, **kw: _completed(
                1,
                "mc: <ERROR> Unable to prepare URL for copying. "
                "The Access Key Id you provided does not exist in our records.",
            ),
        )
        with pytest.raises(OSError, match="Failed to download"):
            syncer._download_head_metadata("stable")

    def test_timeout_raises(self, syncer: Syncer, monkeypatch: pytest.MonkeyPatch) -> None:
        def fake_run(*a: Any, **kw: Any) -> subprocess.CompletedProcess[str]:
            raise subprocess.TimeoutExpired(cmd=["mc"], timeout=300)

        monkeypatch.setattr(sync_module.subprocess, "run", fake_run)
        with pytest.raises(OSError, match="timed out"):
            syncer._download_head_metadata("stable")

    def test_missing_executable_raises(
        self, syncer: Syncer, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        def fake_run(*a: Any, **kw: Any) -> subprocess.CompletedProcess[str]:
            raise FileNotFoundError(2, "No such file or directory", "mc")

        monkeypatch.setattr(sync_module.subprocess, "run", fake_run)
        with pytest.raises(OSError, match="executable not found"):
            syncer._download_head_metadata("stable")


class TestSyncChannelFailurePropagation:
    def test_head_failure_raises_instead_of_reporting_absent(
        self, syncer: Syncer, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        def fake_run(cmd: list[str], **kw: Any) -> subprocess.CompletedProcess[str]:
            if cmd[2].endswith("channels.json"):
                return _completed(0)
            return _completed(1, "mc: <ERROR> Unable to prepare URL for copying. Access Denied.")

        monkeypatch.setattr(sync_module.subprocess, "run", fake_run)
        with pytest.raises(OSError, match="Failed to download"):
            syncer.sync_channel("stable")

    def test_confirmed_missing_head_returns_early(
        self, syncer: Syncer, monkeypatch: pytest.MonkeyPatch
    ) -> None:
        def fake_run(cmd: list[str], **kw: Any) -> subprocess.CompletedProcess[str]:
            if cmd[2].endswith("channels.json"):
                return _completed(0)
            if "metadata.json" in cmd[2]:
                return _completed(
                    1, "mc: <ERROR> Unable to prepare URL for copying. Object does not exist"
                )
            pytest.fail(f"unexpected download after missing head: {cmd}")
            raise AssertionError

        monkeypatch.setattr(sync_module.subprocess, "run", fake_run)
        result = syncer.sync_channel("stable")
        assert result.head_meta is False
        assert result.suppressions is False

    def test_missing_suppressions_still_tolerated(
        self, syncer: Syncer, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        head_dir = tmp_path / "channels" / "heads" / "stable"

        def fake_run(cmd: list[str], **kw: Any) -> subprocess.CompletedProcess[str]:
            src = cmd[2]
            if src.endswith("suppressions.json"):
                return _completed(
                    1, "mc: <ERROR> Unable to prepare URL for copying. Object does not exist"
                )
            if src.endswith("metadata.json"):
                head_dir.mkdir(parents=True, exist_ok=True)
                (head_dir / "metadata.json").write_text('{"generationHash": ""}')
            return _completed(0)

        monkeypatch.setattr(sync_module.subprocess, "run", fake_run)
        result = syncer.sync_channel("stable")
        assert result.head_meta is True
        assert result.suppressions is False

    def test_suppressions_failure_raises(
        self, syncer: Syncer, monkeypatch: pytest.MonkeyPatch, tmp_path: Path
    ) -> None:
        head_dir = tmp_path / "channels" / "heads" / "stable"

        def fake_run(cmd: list[str], **kw: Any) -> subprocess.CompletedProcess[str]:
            src = cmd[2]
            if src.endswith("suppressions.json"):
                return _completed(1, "mc: <ERROR> Failed to copy. Access Denied.")
            if src.endswith("metadata.json"):
                head_dir.mkdir(parents=True, exist_ok=True)
                (head_dir / "metadata.json").write_text('{"generationHash": ""}')
            return _completed(0)

        monkeypatch.setattr(sync_module.subprocess, "run", fake_run)
        with pytest.raises(OSError, match="Failed to download"):
            syncer.sync_channel("stable")
