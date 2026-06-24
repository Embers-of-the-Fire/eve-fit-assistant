"""Session state model and SessionStore for the V2 CLI session workflow.

Provides the Session Pydantic model (the .session.json schema) and SessionStore
that manages the file on disk. This module has zero CLI surface.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import ConfigDict
from pydantic import Field
from pydantic import field_validator

from bootstrap.remote import SessionManagerCommittedError
from bootstrap.remote import SessionManagerInvalidError
from bootstrap.remote.channel import Channel
from bootstrap.remote.models import write_json_atomic


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.remote.hash import SnapshotType


class SessionExistsError(Exception):
    """Raised when init is called but a session already exists."""


class SessionDuplicateServerError(Exception):
    """Raised when staging a second resource snapshot for an already-staged server."""


class StagedSnapshots(BaseModel):
    resources: list[str] = Field(default_factory=list)
    releases: list[str] = Field(default_factory=list)


class Session(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    schema_version: int = Field(default=1, alias="schemaVersion")
    channel: str
    committed: bool = False
    staged: StagedSnapshots = Field(default_factory=StagedSnapshots)

    @field_validator("channel")
    @classmethod
    def _validate_channel(cls, v: str) -> str:
        if v not in (Channel.TESTING, Channel.STABLE):
            raise ValueError(f"Invalid channel: {v!r}")
        return v

    @field_validator("schema_version")
    @classmethod
    def _validate_schema_version(cls, v: int) -> int:
        if v != 1:
            raise ValueError(f"schema_version must be 1, got {v}")
        return v


class SessionStore:
    """Manages the .session.json file on disk.

    All operations work within a single root directory (the schema root, e.g.
    cache/shared/).
    """

    def __init__(self, root: Path) -> None:
        self.root = root

    @property
    def session_path(self) -> Path:
        """<root>/.session.json"""
        return self.root / ".session.json"

    def exists(self) -> bool:
        """Return True if .session.json is present and parseable."""
        if not self.session_path.is_file():
            return False
        try:
            self.load()
        except (ValueError, FileNotFoundError):
            return False
        else:
            return True

    def load(self) -> Session:
        """Parse and return the Session from .session.json.

        Raises FileNotFoundError if the file does not exist, ValueError on
        parse failure.
        """
        if not self.session_path.is_file():
            raise FileNotFoundError(f"No session file at {self.session_path}")
        return Session.model_validate_json(self.session_path.read_text(encoding="utf-8"))

    def save(self, session: Session) -> None:
        """Write the session to .session.json atomically."""
        write_json_atomic(self.session_path, session)

    def init(
        self,
        channel: str,
        force_overwrite: bool = False,
    ) -> Session:
        """Create a new session.

        If a session already exists and force_overwrite is False, raises
        SessionExistsError. With force_overwrite=True, an existing session
        (committed or not) is discarded and replaced.
        """
        if self.session_path.is_file():
            if not force_overwrite:
                raise SessionExistsError(
                    f"A session already exists at {self.session_path}. "
                    "Use --force-overwrite to replace it."
                )
            self.session_path.unlink()

        session = Session(
            channel=channel,
            committed=False,
            staged=StagedSnapshots(),
        )
        self.save(session)
        return session

    def discard(self, force: bool = False) -> None:
        """Delete .session.json.

        If no session exists, raises SessionManagerInvalidError.
        If the session is committed and force is False, raises
        SessionManagerCommittedError.
        """
        if not self.session_path.is_file():
            raise SessionManagerInvalidError("No active session.")
        session = self.load()
        if session.committed and not force:
            raise SessionManagerCommittedError("Session is committed. Use --force to discard.")
        self.session_path.unlink()

    def is_committed(self) -> bool:
        """Return True if the session is committed."""
        if not self.session_path.is_file():
            return False
        return self.load().committed

    def mark_committed(self) -> None:
        """Load the session, set committed=True, save, and release the lock.

        After marking committed, the session file is removed — the generation
        has been created and no further session operations are needed.
        """
        session = self.load()
        session.committed = True
        self.save(session)
        self.session_path.unlink(missing_ok=True)

    def ensure_editable(self) -> None:
        """Raise SessionManagerCommittedError if the session is committed."""
        if self.is_committed():
            raise SessionManagerCommittedError("Session is committed. Use --force to override.")

    def add_snapshot(
        self,
        snap_type: SnapshotType,
        hash_value: str,
        *,
        server_id: str | None = None,
        staged_server_ids: dict[str, str] | None = None,
    ) -> Session:
        """Stage a snapshot hash.

        When *snap_type* is ``"resource"`` and *server_id* and
        *staged_server_ids* are both supplied, rejects the operation if
        *server_id* is already present in *staged_server_ids* (defense-in-depth
        — the CLI is expected to have already performed this check).

        Raises SessionManagerCommittedError if committed.
        Raises SessionDuplicateServerError on per-server duplicate.
        """
        self.ensure_editable()
        session = self.load()
        staged = session.staged
        if (
            snap_type == "resource"
            and server_id is not None
            and staged_server_ids is not None
            and server_id in staged_server_ids
        ):
            conflict = staged_server_ids[server_id]
            raise SessionDuplicateServerError(
                f"Server '{server_id}' already has a staged snapshot "
                f"({conflict[:16]}...) in this session."
            )

        if snap_type == "resource":
            staged.resources.append(hash_value)
        elif snap_type == "release":
            staged.releases.append(hash_value)
        self.save(session)
        return session

    def replace_snapshot(
        self,
        old_hash: str,
        new_hash: str,
        *,
        snap_type: SnapshotType = "resource",
    ) -> Session:
        """Atomically replace a staged snapshot hash with a new one.

        Raises ValueError if *old_hash* is not currently staged.
        Server-ID matching is expected to be validated by the caller.
        """
        self.ensure_editable()
        session = self.load()
        staged = session.staged
        if snap_type == "resource":
            if old_hash not in staged.resources:
                raise ValueError(f"Replace target {old_hash} is not currently staged as resource.")
            idx = staged.resources.index(old_hash)
            staged.resources[idx] = new_hash
        elif snap_type == "release":
            if old_hash not in staged.releases:
                raise ValueError(f"Replace target {old_hash} is not currently staged as release.")
            idx = staged.releases.index(old_hash)
            staged.releases[idx] = new_hash
        self.save(session)
        return session

    def remove_snapshot(self, snap_type: SnapshotType, hash_value: str) -> Session:
        """Remove a staged snapshot hash. Raises ValueError if not staged."""
        self.ensure_editable()
        session = self.load()
        staged = session.staged
        if snap_type == "resource":
            if hash_value not in staged.resources:
                raise ValueError(f"Hash {hash_value} is not staged as resource.")
            staged.resources.remove(hash_value)
        elif snap_type == "release":
            if hash_value not in staged.releases:
                raise ValueError(f"Hash {hash_value} is not staged as release.")
            staged.releases.remove(hash_value)
        self.save(session)
        return session
