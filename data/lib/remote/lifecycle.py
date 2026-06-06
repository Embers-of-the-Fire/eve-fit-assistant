"""Base session lifecycle manager.

Provides the shared skeleton that ``SessionManager`` and ``PromotionSessionManager``
inherit: session directory layout, lockfile / todo I/O, current-session pointer
management, and abort.
"""

from __future__ import annotations

import shutil

from typing import TYPE_CHECKING

from data.lib.remote.models import LockFile
from data.lib.remote.models import TodoList
from data.lib.remote.models import _load_json_model
from data.lib.remote.models import _persist_json
from data.lib.remote.models import _session_path


if TYPE_CHECKING:
    from pathlib import Path


class _BaseSessionManager:
    """Shared session lifecycle: directory layout, lockfile/todo I/O, abort."""

    CURRENT_SESSION_FILE: str = ""
    _NOT_ACTIVE_ERROR: type[Exception] = Exception
    _COMMITTED_ERROR: type[Exception] = Exception

    def __init__(
        self,
        sessions_root: Path,
        session_id: str,
        *,
        lockfile: LockFile | None = None,
        todo: TodoList | None = None,
    ) -> None:
        self.sessions_root = sessions_root
        self.session_id = session_id
        self._session_dir = _session_path(sessions_root, session_id)
        self._lockfile: LockFile | None = lockfile
        self._todo: TodoList | None = todo

    # ---- properties --------------------------------------------------------

    @property
    def session_dir(self) -> Path:
        return self._session_dir

    @property
    def remote_state_dir(self) -> Path:
        return self._session_dir / "remote-state"

    @property
    def merged_dir(self) -> Path:
        return self._session_dir / "merged"

    @property
    def todo_path(self) -> Path:
        return self._session_dir / "todo.json"

    @property
    def lockfile_path(self) -> Path:
        return self._session_dir / "lockfile.json"

    # ---- lock / todo helpers -----------------------------------------------

    def _ensure_not_committed(self) -> None:
        self._load_todo()
        if self._todo and self._todo.committed:
            raise self._COMMITTED_ERROR(
                f"Session {self.session_id} has already been committed and is immutable."
            )

    def _load_todo(self) -> TodoList:
        if self._todo is None:
            self._todo = _load_json_model(self.todo_path, TodoList)
        return self._todo

    def _save_todo(self) -> None:
        if self._todo is not None:
            _persist_json(self.todo_path, self._todo)

    def _load_lockfile(self) -> LockFile:
        if self._lockfile is None:
            if self.lockfile_path.is_file():
                self._lockfile = _load_json_model(self.lockfile_path, LockFile)
            else:
                todo = self._load_todo()
                if todo.lock_snapshot:
                    self._lockfile = LockFile(
                        session_id=self.session_id,
                        backend=str(todo.lock_snapshot["backend"]),
                        timestamp=str(todo.lock_snapshot["timestamp"]),
                        host=str(todo.lock_snapshot["host"]),
                        pid=int(todo.lock_snapshot["pid"]),
                    )
                else:
                    raise FileNotFoundError(
                        f"Lockfile not found and no snapshot in todo: {self.lockfile_path}"
                    )
        return self._lockfile

    # ---- factory: from existing session ------------------------------------

    @classmethod
    def from_current(cls, sessions_root: Path) -> _BaseSessionManager:
        session_id = cls._read_current_session(sessions_root)
        if session_id is None:
            raise cls._NOT_ACTIVE_ERROR("No session is currently active.")
        return cls.from_session_id(sessions_root, session_id)

    @classmethod
    def from_session_id(cls, sessions_root: Path, session_id: str) -> _BaseSessionManager:
        session_dir = _session_path(sessions_root, session_id)
        if not session_dir.is_dir():
            raise FileNotFoundError(f"Session directory does not exist: {session_dir}")

        lockfile: LockFile | None = None
        lockfile_path = session_dir / "lockfile.json"
        if lockfile_path.is_file():
            lockfile = _load_json_model(lockfile_path, LockFile)

        todo: TodoList | None = None
        todo_path = session_dir / "todo.json"
        if todo_path.is_file():
            todo = _load_json_model(todo_path, TodoList)

        return cls(sessions_root, session_id, lockfile=lockfile, todo=todo)

    # ---- abort -------------------------------------------------------------

    def abort(self) -> None:
        if self._session_dir.exists():
            shutil.rmtree(self._session_dir, ignore_errors=True)
        self._clear_current_session(self.sessions_root, self.session_id)

    # ---- current session pointer helpers -----------------------------------

    @classmethod
    def _current_session_path(cls, sessions_root: Path) -> Path:
        return sessions_root / cls.CURRENT_SESSION_FILE

    @classmethod
    def _read_current_session(cls, sessions_root: Path) -> str | None:
        p = cls._current_session_path(sessions_root)
        if not p.is_file():
            return None
        session_id = p.read_text(encoding="utf-8").strip()
        if not session_id:
            return None
        if not _session_path(sessions_root, session_id).is_dir():
            return None
        return session_id

    @classmethod
    def _write_current_session(cls, sessions_root: Path, session_id: str) -> None:
        sessions_root.mkdir(parents=True, exist_ok=True)
        cls._current_session_path(sessions_root).write_text(session_id + "\n", encoding="utf-8")

    @classmethod
    def _clear_current_session(cls, sessions_root: Path, session_id: str) -> None:
        p = cls._current_session_path(sessions_root)
        current = cls._read_current_session(sessions_root)
        if current == session_id:
            p.unlink(missing_ok=True)
