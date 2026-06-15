"""Tests for data.lib.remote.session_model — Session model and SessionStore."""

from __future__ import annotations

import json

import pytest

from pydantic import ValidationError

from data.lib.remote.__init__ import SessionManagerCommittedError
from data.lib.remote.__init__ import SessionManagerInvalidError
from data.lib.remote.session_model import Session
from data.lib.remote.session_model import SessionExistsError
from data.lib.remote.session_model import SessionStore


class TestSessionModel:
    def test_channel_validation(self) -> None:
        with pytest.raises(ValidationError, match="Invalid channel"):
            Session(channel="invalid")

    def test_testing_channel_is_valid(self) -> None:
        s = Session(channel="testing")
        assert s.channel == "testing"

    def test_stable_channel_is_valid(self) -> None:
        s = Session(channel="stable")
        assert s.channel == "stable"

    def test_schema_version_default(self) -> None:
        s = Session(channel="testing")
        assert s.schema_version == 1

    def test_staged_defaults_empty(self) -> None:
        s = Session(channel="testing")
        assert s.staged.resources == []
        assert s.staged.releases == []
        assert s.staged.announcements == []

    def test_committed_defaults_false(self) -> None:
        s = Session(channel="testing")
        assert s.committed is False

    def test_json_field_aliases(self) -> None:
        s = Session(channel="testing")
        data = json.loads(s.model_dump_json(by_alias=True))
        assert "schemaVersion" in data
        assert "schema_version" not in data
        assert data["schemaVersion"] == 1
        assert data["channel"] == "testing"
        assert data["committed"] is False

    def test_populate_by_name_accepts_alias(self) -> None:
        data = {
            "schemaVersion": 1,
            "channel": "testing",
        }
        s = Session.model_validate(data)
        assert s.schema_version == 1

    def test_populate_by_name_accepts_python_name(self) -> None:
        data = {
            "schema_version": 1,
            "channel": "testing",
        }
        s = Session.model_validate(data)
        assert s.schema_version == 1


class TestSessionStore:
    def test_init_creates_session_file(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        assert store.session_path.is_file()

    def test_init_overwrite_without_force_raises(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        with pytest.raises(SessionExistsError, match="A session already exists"):
            store.init(channel="testing")

    def test_init_overwrite_with_force_succeeds(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.init(
            channel="stable",
            force_overwrite=True,
        )
        session = store.load()
        assert session.channel == "stable"

    def test_init_overwrite_committed_with_force(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.mark_committed()
        store.init(
            channel="stable",
            force_overwrite=True,
        )
        session = store.load()
        assert session.channel == "stable"
        assert session.committed is False

    def test_load_roundtrip(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        original = store.init(channel="testing")
        loaded = store.load()
        assert loaded.channel == original.channel
        assert loaded.committed == original.committed
        assert loaded.schema_version == original.schema_version

    def test_load_no_file_raises(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        with pytest.raises(FileNotFoundError):
            store.load()

    def test_discard_removes_file(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        assert store.session_path.is_file()
        store.discard()
        assert not store.session_path.is_file()

    def test_discard_committed_without_force_raises(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.mark_committed()
        with pytest.raises(SessionManagerCommittedError):
            store.discard()

    def test_discard_committed_with_force_succeeds(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.mark_committed()
        store.discard(force=True)
        assert not store.session_path.is_file()

    def test_discard_no_session_raises(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        with pytest.raises(SessionManagerInvalidError):
            store.discard()

    def test_mark_committed(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        assert store.is_committed() is False
        store.mark_committed()
        assert store.is_committed() is True

    def test_ensure_editable_on_committed_raises(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.mark_committed()
        with pytest.raises(SessionManagerCommittedError):
            store.ensure_editable()

    def test_ensure_editable_on_uncommitted_passes(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.ensure_editable()

    def test_staged_initializes_empty(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        session = store.init(channel="testing")
        assert session.staged.resources == []
        assert session.staged.releases == []
        assert session.staged.announcements == []

    def test_exists_true_for_valid_session(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        assert store.exists() is True

    def test_exists_false_for_no_file(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        assert store.exists() is False

    def test_exists_false_for_corrupt_file(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.session_path.parent.mkdir(parents=True, exist_ok=True)
        store.session_path.write_text("not json", encoding="utf-8")
        assert store.exists() is False

    def test_save_updates_file(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        session = store.init(channel="testing")
        session.committed = True  # toggle a field to verify save/load
        store.save(session)
        loaded = store.load()
        assert loaded.committed is True

    def test_init_populates_all_fields(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        session = store.init(channel="stable")
        assert session.channel == "stable"
        assert session.committed is False
        assert session.schema_version == 1

    # --- add_snapshot tests --------------------------------------------------

    def test_add_snapshot_resource(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.add_snapshot("resource", "aaa")
        store.add_snapshot("resource", "bbb")
        session = store.load()
        assert session.staged.resources == ["aaa", "bbb"]
        assert session.staged.releases == []
        assert session.staged.announcements == []

    def test_add_snapshot_release(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.add_snapshot("release", "rrr")
        session = store.load()
        assert session.staged.releases == ["rrr"]

    def test_add_snapshot_announcement(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.add_snapshot("announcement", "ann")
        session = store.load()
        assert session.staged.announcements == ["ann"]

    def test_add_snapshot_duplicate_allowed(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.add_snapshot("resource", "dup")
        store.add_snapshot("resource", "dup")
        session = store.load()
        assert session.staged.resources == ["dup", "dup"]

    def test_add_snapshot_on_committed_raises(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.mark_committed()
        with pytest.raises(SessionManagerCommittedError):
            store.add_snapshot("resource", "abc")

    # --- remove_snapshot tests -----------------------------------------------

    def test_remove_snapshot_resource(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.add_snapshot("resource", "aaa")
        store.add_snapshot("resource", "bbb")
        store.remove_snapshot("resource", "aaa")
        session = store.load()
        assert session.staged.resources == ["bbb"]

    def test_remove_snapshot_release(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.add_snapshot("release", "rrr")
        store.remove_snapshot("release", "rrr")
        session = store.load()
        assert session.staged.releases == []

    def test_remove_snapshot_announcement(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.add_snapshot("announcement", "ann")
        store.remove_snapshot("announcement", "ann")
        session = store.load()
        assert session.staged.announcements == []

    def test_remove_snapshot_not_staged_raises(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        with pytest.raises(ValueError, match="not staged as resource"):
            store.remove_snapshot("resource", "missing")

    def test_remove_snapshot_wrong_type_raises(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.add_snapshot("resource", "aaa")
        with pytest.raises(ValueError, match="not staged as release"):
            store.remove_snapshot("release", "aaa")

    def test_remove_snapshot_on_committed_raises(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.add_snapshot("resource", "abc")
        store.mark_committed()
        with pytest.raises(SessionManagerCommittedError):
            store.remove_snapshot("resource", "abc")

    def test_remove_first_of_duplicates(self, tmp_path: pytest.fixture) -> None:
        store = SessionStore(tmp_path)
        store.init(channel="testing")
        store.add_snapshot("resource", "dup")
        store.add_snapshot("resource", "dup")
        store.remove_snapshot("resource", "dup")
        session = store.load()
        assert session.staged.resources == ["dup"]
