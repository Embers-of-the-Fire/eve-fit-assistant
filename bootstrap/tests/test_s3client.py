"""Tests for S3Client missing-object vs missing-bucket classification.

HEAD requests carry no error body, so botocore reports a missing bucket the
same way as a missing key: a bare "404" status code. S3Client must confirm
the bucket with HeadBucket before reporting an object as absent. These tests
stub the real boto3 client so the classification path matches production;
bootstrap/tests/test_remote_sync.py covers the Syncer layer above it.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

import pytest

from botocore.stub import ANY
from botocore.stub import Stubber

from bootstrap.remote.s3client import ClientError
from bootstrap.remote.s3client import S3Client


if TYPE_CHECKING:
    from pathlib import Path


def _make_client() -> tuple[S3Client, Stubber]:
    client = S3Client(
        endpoint="http://mock.invalid",
        bucket="bucket",
        access_key="key",
        secret_key="secret",  # noqa: S106
    )
    stubber = Stubber(client._client)
    stubber.activate()
    return client, stubber


class TestObjectExists:
    def test_existing_object_returns_true(self) -> None:
        client, stubber = _make_client()
        stubber.add_response("head_object", {})
        assert client.object_exists("some/key") is True
        stubber.assert_no_pending_responses()

    def test_missing_key_returns_false(self) -> None:
        """Bare HEAD 404 + existing bucket: the key is genuinely absent."""
        client, stubber = _make_client()
        stubber.add_client_error("head_object", service_error_code="404")
        stubber.add_response("head_bucket", {})
        assert client.object_exists("some/key") is False
        stubber.assert_no_pending_responses()

    def test_missing_bucket_raises(self) -> None:
        """Bare HEAD 404 + missing bucket: not an absent object — raise."""
        client, stubber = _make_client()
        stubber.add_client_error("head_object", service_error_code="404")
        stubber.add_client_error("head_bucket", service_error_code="404")
        with pytest.raises(ClientError, match="NoSuchBucket"):
            client.object_exists("some/key")
        stubber.assert_no_pending_responses()

    def test_bucket_permission_error_raises(self) -> None:
        """A non-404 HeadBucket failure is a real error, not an absent object."""
        client, stubber = _make_client()
        stubber.add_client_error("head_object", service_error_code="404")
        stubber.add_client_error("head_bucket", service_error_code="403")
        with pytest.raises(ClientError, match="403"):
            client.object_exists("some/key")
        stubber.assert_no_pending_responses()

    def test_non_404_head_error_raises_without_bucket_check(self) -> None:
        client, stubber = _make_client()
        stubber.add_client_error("head_object", service_error_code="403")
        with pytest.raises(ClientError, match="403"):
            client.object_exists("some/key")
        stubber.assert_no_pending_responses()


class TestUploadFile:
    def test_content_type_guessed_from_key(self, tmp_path: Path) -> None:
        """Without explicit attrs, Content-Type defaults to the key's guess."""
        src = tmp_path / "catalog.json"
        src.write_text("{}")
        client, stubber = _make_client()
        stubber.add_response(
            "put_object",
            {},
            expected_params={
                "Bucket": "bucket",
                "Key": "announcements/catalog.json",
                "Body": ANY,
                "ChecksumAlgorithm": "CRC32",
                "ContentType": "application/json",
            },
        )
        client.upload_file(src, "announcements/catalog.json")
        stubber.assert_no_pending_responses()

    def test_explicit_content_type_wins(self, tmp_path: Path) -> None:
        src = tmp_path / "catalog.json"
        src.write_text("{}")
        client, stubber = _make_client()
        stubber.add_response(
            "put_object",
            {},
            expected_params={
                "Bucket": "bucket",
                "Key": "some/catalog.json",
                "Body": ANY,
                "ChecksumAlgorithm": "CRC32",
                "ContentType": "application/vnd.custom+json",
            },
        )
        client.upload_file(
            src, "some/catalog.json", attrs={"Content-Type": "application/vnd.custom+json"}
        )
        stubber.assert_no_pending_responses()

    def test_unknown_extension_sends_no_content_type(self, tmp_path: Path) -> None:
        """Hash-named blobs keep attrs untouched and gain no guessed type."""
        src = tmp_path / "deadbeef"
        src.write_bytes(b"\x00" * 4)
        client, stubber = _make_client()
        stubber.add_response(
            "put_object",
            {},
            expected_params={
                "Bucket": "bucket",
                "Key": "efa/v2/assets/blobs/de/ad/deadbeef",
                "Body": ANY,
                "ChecksumAlgorithm": "CRC32",
                "CacheControl": "immutable, max-age=31536000",
            },
        )
        client.upload_file(
            src,
            "efa/v2/assets/blobs/de/ad/deadbeef",
            attrs={"Cache-Control": "immutable, max-age=31536000"},
        )
        stubber.assert_no_pending_responses()


class TestDownloadFile:
    def test_missing_key_returns_false(self, tmp_path: Path) -> None:
        """The transfer manager's preliminary HeadObject 404 + existing bucket."""
        client, stubber = _make_client()
        stubber.add_client_error("head_object", service_error_code="404")
        stubber.add_response("head_bucket", {})
        dest = tmp_path / "out.bin"
        assert client.download_file("some/key", dest) is False
        assert not dest.exists()
        stubber.assert_no_pending_responses()

    def test_missing_bucket_raises(self, tmp_path: Path) -> None:
        """Preliminary HeadObject 404 + missing bucket must raise, not return False."""
        client, stubber = _make_client()
        stubber.add_client_error("head_object", service_error_code="404")
        stubber.add_client_error("head_bucket", service_error_code="404")
        with pytest.raises(ClientError, match="NoSuchBucket"):
            client.download_file("some/key", tmp_path / "out.bin")
        stubber.assert_no_pending_responses()

    def test_non_404_error_raises_without_bucket_check(self, tmp_path: Path) -> None:
        client, stubber = _make_client()
        stubber.add_client_error("head_object", service_error_code="403")
        with pytest.raises(ClientError, match="403"):
            client.download_file("some/key", tmp_path / "out.bin")
        stubber.assert_no_pending_responses()
