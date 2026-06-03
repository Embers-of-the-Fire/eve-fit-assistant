"""Data models for remote content sessions.

LockFile  — session identity and liveness.
TodoList  — ordered, idempotent sequence of staged operations.
SessionStatus — lightweight summary for the status command.
"""

from __future__ import annotations

from typing import TYPE_CHECKING
from typing import Literal

from pydantic import BaseModel
from pydantic import ConfigDict
from pydantic import Field


if TYPE_CHECKING:
    from pathlib import Path


# ---------------------------------------------------------------------------
# Session lockfile
# ---------------------------------------------------------------------------


class LockFile(BaseModel):
    """Identity record written at session start; removed at commit or abort."""

    model_config = ConfigDict(frozen=True)

    session_id: str
    timestamp: str
    host: str
    pid: int
    backend: Literal["minio", "s3", "local"]


# ---------------------------------------------------------------------------
# Operations (todo.json entries)
# ---------------------------------------------------------------------------


class AddAnnouncementOp(BaseModel):
    type: Literal["add-announcement"] = "add-announcement"
    document_id: str
    fields: dict[str, object] = Field(default_factory=dict)
    staged_files: dict[str, str] = Field(default_factory=dict)


class AddBundleOp(BaseModel):
    type: Literal["add-bundle"] = "add-bundle"
    artifact_id: str
    bundle_id: str
    variant: Literal["full", "incremental"]
    fields: dict[str, object] = Field(default_factory=dict)
    staged_files: dict[str, str] = Field(default_factory=dict)


class RemoveOp(BaseModel):
    type: Literal["remove"] = "remove"
    target_type: Literal["document", "artifact"]
    target_id: str


class PromoteDocumentOp(BaseModel):
    type: Literal["promote-document"] = "promote-document"
    document_id: str
    fields: dict[str, object] = Field(default_factory=dict)


class PromoteBundleOp(BaseModel):
    type: Literal["promote-bundle"] = "promote-bundle"
    artifact_id: str
    bundle_id: str
    variant: Literal["full", "incremental"]
    fields: dict[str, object] = Field(default_factory=dict)


# ---------------------------------------------------------------------------
# Todo list (the ordered journal of staged operations)
# ---------------------------------------------------------------------------


class TodoList(BaseModel):
    """Mutable journal persisted at session/todo.json.  Operations are
    applied in order when regenerating merged output."""

    version: int = 1
    session_id: str
    committed: bool = False
    operations: list[
        AddAnnouncementOp | AddBundleOp | RemoveOp | PromoteDocumentOp | PromoteBundleOp
    ] = Field(default_factory=list)
    lock_snapshot: dict[str, object] = Field(default_factory=dict)


# ---------------------------------------------------------------------------
# Session status (for the status command)
# ---------------------------------------------------------------------------


class SessionStatus(BaseModel):
    session_id: str
    backend: str
    timestamp: str
    host: str
    pid: int
    operation_count: int
    committed: bool


# ---------------------------------------------------------------------------
# Remote state (snapshot of remote catalogs + index)
# ---------------------------------------------------------------------------


class RemoteState(BaseModel):
    """The three JSON files that make up a channel's remote state."""

    index: dict[str, object]
    documents_catalog: dict[str, object]
    bundles_catalog: dict[str, object]


# ---------------------------------------------------------------------------
# Misc / helpers
# ---------------------------------------------------------------------------


def _session_path(sessions_root: Path, session_id: str) -> Path:
    """Return the canonical session directory path."""
    return sessions_root / session_id


def _persist_json(path: Path, model: BaseModel) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(model.model_dump_json(indent=4, by_alias=True) + "\n", encoding="utf-8")


def _load_json_model[T: BaseModel](path: Path, model_cls: type[T]) -> T:
    import json as _json

    text = path.read_text(encoding="utf-8")
    return model_cls.model_validate(_json.loads(text))
