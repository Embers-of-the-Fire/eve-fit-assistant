"""Shared S3 client — thin boto3 wrapper for remote publishing, syncing, and CI storage.

Every S3-compatible target (the local RustFS mock, production R2/S3) goes
through :class:`S3Client` so credentials stay out of process argv and missing-
object classification is uniform (boto3 ``ClientError`` codes instead of
parsing CLI stderr).

Objects are addressed with path-style URLs so local mock servers without
virtual-host DNS keep working; managed endpoints (R2/S3) accept both styles.
"""

from __future__ import annotations

import json
import mimetypes

from typing import TYPE_CHECKING

import boto3

from boto3.s3.transfer import TransferConfig
from botocore.config import Config
from botocore.exceptions import BotoCoreError
from botocore.exceptions import ClientError


if TYPE_CHECKING:
    from pathlib import Path


# Error codes that prove an object is absent. Bucket-level absence
# (NoSuchBucket) is deliberately excluded: a missing bucket is a real
# configuration failure and must raise, never be mistaken for an absent
# channel head.
#
# Caveat: HEAD requests (HeadObject — issued directly by object_exists and
# internally by boto3's transfer manager before download_file) have no error
# body, so botocore falls back to the HTTP status as Error.Code. A missing
# bucket and a missing key then both surface as a bare "404", which is in
# this set. A bare "404" from a HEAD-based call must therefore be confirmed
# against HeadBucket (S3Client._confirm_bucket_exists) before being treated
# as "object absent".
_MISSING_CODES = frozenset({"404", "NoSuchKey", "NotFound"})

# The only member of _MISSING_CODES that botocore synthesizes from a bare
# HTTP status on a bodiless (HEAD) error response. NoSuchKey/NotFound come
# from a parsed XML error body, which only exists when the bucket exists.
_AMBIGUOUS_HEAD_404 = "404"

# Legacy ``mc --attr`` headers mapped to boto3 ExtraArgs fields.
_ATTR_EXTRA_ARGS = {
    "Cache-Control": "CacheControl",
    "Content-Type": "ContentType",
}


def is_missing_error(exc: ClientError) -> bool:
    """True when the error confirms the object/bucket is absent (404 family)."""
    return exc.response.get("Error", {}).get("Code", "") in _MISSING_CODES


def extra_args_from_attrs(attrs: dict[str, str] | None) -> dict[str, str]:
    """Map legacy ``mc --attr`` style headers to boto3 ExtraArgs."""
    extra: dict[str, str] = {}
    for key, value in (attrs or {}).items():
        mapped = _ATTR_EXTRA_ARGS.get(key)
        if mapped is None:
            raise ValueError(f"Unsupported upload attribute: {key!r}")
        extra[mapped] = value
    return extra


def wrap_s3_error(exc: Exception, title: str) -> OSError:
    """Convert a boto3 failure into an OSError with a stable, greppable message."""
    return OSError(f"{title}: {exc}")


class S3Client:
    """boto3 client bound to one endpoint/bucket/credential set.

    Safe to share across threads: boto3 clients are thread-safe and the
    connection pool is sized from ``workers``.
    """

    def __init__(
        self,
        *,
        endpoint: str,
        bucket: str,
        access_key: str,
        secret_key: str,
        workers: int = 8,
        read_timeout: int = 300,
    ) -> None:
        if not endpoint.strip():
            raise ValueError("S3 endpoint must not be empty.")
        if not bucket.strip():
            raise ValueError("S3 bucket must not be empty.")
        if not access_key:
            raise ValueError("S3 access key must not be empty.")
        if not secret_key:
            raise ValueError("S3 secret key must not be empty.")
        self.endpoint = endpoint
        self.bucket = bucket
        self._client = boto3.client(
            "s3",
            endpoint_url=endpoint,
            aws_access_key_id=access_key,
            aws_secret_access_key=secret_key,
            config=Config(
                s3={"addressing_style": "path"},
                retries={"max_attempts": 5, "mode": "standard"},
                connect_timeout=10,
                read_timeout=read_timeout,
                max_pool_connections=max(2 * workers, 10),
            ),
        )
        self._transfer = TransferConfig(max_concurrency=max(workers, 1))

    # -- Existence -------------------------------------------------------------

    def _confirm_bucket_exists(self) -> None:
        """Disambiguate a bare HEAD 404: raise NoSuchBucket when the bucket is gone.

        HeadBucket is itself bodiless, so a missing bucket again surfaces as a
        bare "404"; other failures (e.g. 403) propagate unchanged. When this
        returns without raising, the bucket exists and the original 404 really
        meant "object absent".
        """
        try:
            self._client.head_bucket(Bucket=self.bucket)
        except ClientError as exc:
            if is_missing_error(exc):
                raise ClientError(
                    {
                        "Error": {
                            "Code": "NoSuchBucket",
                            "Message": (
                                f"Bucket {self.bucket!r} does not exist "
                                "(HEAD 404 confirmed via HeadBucket)"
                            ),
                        }
                    },
                    "HeadBucket",
                ) from exc
            raise

    def _is_missing(self, exc: ClientError, *, head_based: bool) -> bool:
        """True when *exc* confirms the object is absent.

        For HEAD-based calls a bare "404" is ambiguous (missing key vs missing
        bucket), so the bucket is confirmed with HeadBucket first; a missing
        bucket raises NoSuchBucket instead of reading as an absent object.
        """
        if not is_missing_error(exc):
            return False
        if head_based and exc.response.get("Error", {}).get("Code") == _AMBIGUOUS_HEAD_404:
            self._confirm_bucket_exists()
        return True

    def object_exists(self, key: str) -> bool:
        """True if the object exists; raises on any non-404 failure."""
        try:
            self._client.head_object(Bucket=self.bucket, Key=key)
        except ClientError as exc:
            if self._is_missing(exc, head_based=True):
                return False
            raise
        return True

    def list_keys(self, prefix: str) -> list[str]:
        """All object keys under *prefix* (empty list when nothing matches)."""
        keys: list[str] = []
        paginator = self._client.get_paginator("list_objects_v2")
        for page in paginator.paginate(Bucket=self.bucket, Prefix=prefix):
            for item in page.get("Contents", []):
                keys.append(item["Key"])
        return keys

    # -- Upload ------------------------------------------------------------------

    def upload_file(self, src: Path, key: str, *, attrs: dict[str, str] | None = None) -> None:
        """Upload one file, optionally with Cache-Control/Content-Type attrs.

        When no explicit Content-Type attr is given, one is guessed from the
        object key via :func:`mimetypes.guess_type` (``mc cp``/``mc mirror``
        behavior). boto3 sends no Content-Type otherwise, so S3/R2/RustFS
        would store binary/octet-stream — which costs JSON metadata its CDN
        compression. Keys without a known extension keep no Content-Type.
        """
        extra = extra_args_from_attrs(attrs)
        if "ContentType" not in extra:
            guessed = mimetypes.guess_type(key)[0]
            if guessed is not None:
                extra["ContentType"] = guessed
        self._client.upload_file(
            str(src),
            self.bucket,
            key,
            ExtraArgs=extra,
            Config=self._transfer,
        )

    def upload_dir(self, src_dir: Path, prefix: str) -> None:
        """Upload every file under *src_dir* to *prefix* (no deletions)."""
        base = prefix.rstrip("/")
        for f in sorted(src_dir.rglob("*")):
            if f.is_file():
                self.upload_file(f, f"{base}/{f.relative_to(src_dir)}")

    # -- Download ----------------------------------------------------------------

    def read_bytes(self, key: str) -> bytes:
        """Return the object's bytes; raises ClientError (404 when absent)."""
        return self._client.get_object(Bucket=self.bucket, Key=key)["Body"].read()

    def download_file(self, key: str, dest: Path) -> bool:
        """Download one object.

        Returns False only when the object is confirmed missing; raises
        (ClientError/BotoCoreError) on any other failure so a failed download
        is never mistaken for an absent object.
        """
        dest.parent.mkdir(parents=True, exist_ok=True)
        try:
            self._client.download_file(self.bucket, key, str(dest), Config=self._transfer)
        except ClientError as exc:
            # A bare "404" comes from the transfer manager's preliminary
            # HeadObject (bodiless), which cannot distinguish a missing key
            # from a missing bucket; confirm the bucket before reporting
            # the object as absent.
            if self._is_missing(exc, head_based=True):
                dest.unlink(missing_ok=True)
                return False
            raise
        return True

    def download_dir(self, prefix: str, dest_dir: Path) -> bool:
        """Download every object under *prefix* into *dest_dir*.

        Returns False only when the prefix holds no objects at all.
        """
        keys = self.list_keys(prefix.rstrip("/") + "/")
        if not keys:
            return False
        dest_dir.mkdir(parents=True, exist_ok=True)
        base = prefix.rstrip("/") + "/"
        for key in keys:
            rel = key.removeprefix(base)
            self.download_file(key, dest_dir / rel)
        return True

    # -- Mirror ------------------------------------------------------------------

    def mirror_up(self, src_dir: Path, prefix: str, *, delete: bool = False) -> None:
        """Mirror a local tree to *prefix*, overwriting existing objects.

        With ``delete=True``, remote objects without a local counterpart are
        removed (``mc mirror --overwrite --remove`` equivalent).
        """
        base = prefix.rstrip("/")
        local_rel: set[str] = set()
        for f in sorted(src_dir.rglob("*")):
            if not f.is_file():
                continue
            rel = str(f.relative_to(src_dir))
            local_rel.add(rel)
            self.upload_file(f, f"{base}/{rel}")
        if delete:
            stale = [
                key for key in self.list_keys(base + "/") if key[len(base) + 1 :] not in local_rel
            ]
            for chunk_start in range(0, len(stale), 1000):
                chunk = stale[chunk_start : chunk_start + 1000]
                self._client.delete_objects(
                    Bucket=self.bucket,
                    Delete={"Objects": [{"Key": key} for key in chunk]},
                )

    def mirror_down(self, prefix: str, dest_dir: Path) -> None:
        """Mirror all objects under *prefix* into *dest_dir*, overwriting."""
        base = prefix.rstrip("/") + "/"
        dest_dir.mkdir(parents=True, exist_ok=True)
        for key in self.list_keys(base):
            rel = key.removeprefix(base)
            self.download_file(key, dest_dir / rel)

    # -- Bucket administration ---------------------------------------------------

    def create_bucket(self) -> None:
        """Create the bucket if it does not exist (idempotent)."""
        try:
            self._client.create_bucket(Bucket=self.bucket)
        except ClientError as exc:
            code = exc.response.get("Error", {}).get("Code", "")
            if code not in ("BucketAlreadyOwnedByYou", "BucketAlreadyExists"):
                raise

    def set_public_download(self, enabled: bool) -> None:
        """Enable/disable anonymous read access via a bucket policy."""
        if enabled:
            policy = {
                "Version": "2012-10-17",
                "Statement": [
                    {
                        "Effect": "Allow",
                        "Principal": {"AWS": "*"},
                        "Action": ["s3:GetObject"],
                        "Resource": [f"arn:aws:s3:::{self.bucket}/*"],
                    }
                ],
            }
            self._client.put_bucket_policy(Bucket=self.bucket, Policy=json.dumps(policy))
        else:
            try:
                self._client.delete_bucket_policy(Bucket=self.bucket)
            except ClientError as exc:
                if exc.response.get("Error", {}).get("Code", "") != "NoSuchBucketPolicy":
                    raise


__all__ = [
    "BotoCoreError",
    "ClientError",
    "S3Client",
    "extra_args_from_attrs",
    "is_missing_error",
    "wrap_s3_error",
]
