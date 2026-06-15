from __future__ import annotations

import json
import os
import platform

from typing import TYPE_CHECKING
from unittest.mock import patch

import pytest

from data.lib.remote.channel import Channel
from data.lib.remote.models import AddAnnouncementsOp
from data.lib.remote.models import AddReleaseOp
from data.lib.remote.models import AddResourcesOp
from data.lib.remote.models import LockFile
from data.lib.remote.models import TodoList
from data.lib.remote.models import _load_json_model
from data.lib.remote.session import SessionManager


if TYPE_CHECKING:
    from pathlib import Path


def _make_local_origin(origin_dir: Path, channel: str) -> Path:
    """Create a minimal V2 local origin directory structure."""
    ch_dir = origin_dir / "efa" / "v2" / channel
    manifest_dir = ch_dir / "manifest"
    manifest_dir.mkdir(parents=True)

    index = {"manifestVersion": 1, "activatedGeneration": ""}
    generations: dict[str, object] = {}

    _write(ch_dir / "manifest" / "index.json", index)
    _write(ch_dir / "manifest" / "generations.json", generations)

    return origin_dir


def _write(path: Path, data: dict[str, object]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, indent=4, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def _make_announcement_source(source_dir: Path) -> Path:
    """Create announcement source directory with two announcements."""
    ann_dir = source_dir / "announcements"
    files_dir = ann_dir / "files"
    registry_dir = ann_dir / "registry"

    for locale in ("en", "zh"):
        (files_dir / locale).mkdir(parents=True)
        (files_dir / locale / "ann-001").write_text(f"# Hello ({locale})", encoding="utf-8")
        (files_dir / locale / "ann-002").write_text(f"# World ({locale})", encoding="utf-8")

    registry_dir.mkdir(parents=True)

    _write(
        registry_dir / "ann-001.json",
        {
            "id": "ann-001",
            "firstPublishedAt": "2025-01-01T00:00:00Z",
            "updatedAt": "2025-01-01T00:00:00Z",
            "isVersionUpdate": False,
        },
    )
    _write(
        registry_dir / "ann-002.json",
        {
            "id": "ann-002",
            "firstPublishedAt": "2025-01-02T00:00:00Z",
            "updatedAt": "2025-01-02T00:00:00Z",
            "isVersionUpdate": True,
            "versionRange": ">=2.0.0",
        },
    )
    return source_dir


def _make_dummy_apk(apk_path: Path, content: str = "dummy apk content") -> None:
    apk_path.parent.mkdir(parents=True, exist_ok=True)
    apk_path.write_text(content, encoding="utf-8")


def test_prepare_creates_directory_structure(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    assert mgr.session_id.startswith("session-")
    assert mgr.session_dir.is_dir()
    assert mgr.session_dir == sessions_root / mgr.session_id
    assert (mgr.session_dir / "lockfile.json").is_file()
    assert (mgr.session_dir / "todo.json").is_file()
    assert (mgr.session_dir / "staged").is_dir()
    assert (mgr.session_dir / "merged").is_dir()
    assert (mgr.session_dir / "remote-state").is_dir()


def test_prepare_writes_lockfile_correctly(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    lockfile = _load_json_model(mgr.session_dir / "lockfile.json", LockFile)
    assert lockfile.session_id == mgr.session_id
    assert lockfile.backend == "local"
    assert lockfile.resource_root == "efa/v2/"
    assert lockfile.host == platform.node()
    assert lockfile.pid == os.getpid()


def test_prepare_writes_todo_correctly(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    todo = _load_json_model(mgr.session_dir / "todo.json", TodoList)
    assert todo.session_id == mgr.session_id
    assert todo.committed is False
    assert todo.generation is not None
    assert todo.generation.startswith("gen-")
    assert todo.operations == []
    assert todo.lock_snapshot["description"] == "Test session"


def test_prepare_records_current_session(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    current_path = sessions_root / "current"
    assert current_path.is_file()
    assert current_path.read_text(encoding="utf-8").strip() == mgr.session_id


def test_prepare_two_sessions_have_different_ids(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr1 = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="First",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    mgr2 = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Second",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    assert mgr1.session_id != mgr2.session_id
    assert mgr1.session_dir.is_dir()
    assert mgr2.session_dir.is_dir()


def test_prepare_fetches_remote_state(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "stable")

    # Add some content to the remote state to verify it's copied
    existing = origin_dir / "efa" / "v2" / "stable" / "manifest" / ".generations"
    existing.mkdir(parents=True, exist_ok=True)
    _write(existing / "old-gen" / "catalog.json", {"id": "old-gen"})

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.STABLE,
        origin_dir=origin_dir,
    )

    remote_state = mgr.remote_state_dir / "stable"
    assert remote_state.is_dir()
    assert (remote_state / "manifest" / "index.json").is_file()
    assert (remote_state / "manifest" / ".generations" / "old-gen" / "catalog.json").is_file()


def test_prepare_cleanup_on_failure(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"

    with pytest.raises(FileNotFoundError):
        SessionManager.prepare(
            sessions_root,
            backend="local",
            description="Test session",
            channel=Channel.TESTING,
            origin_dir=tmp_path / "nonexistent",
        )

    # Session directory should be cleaned up
    session_dirs = [d for d in sessions_root.iterdir() if d.is_dir() and d.name not in ("current",)]
    assert len(session_dirs) == 0


def test_add_resources_writes_server_catalogs(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    server_catalogs = [
        {
            "id": "server-1",
            "lastUpdatedAt": "2025-01-01T00:00:00Z",
            "name": {"en": "Server One"},
            "metadata": {},
            "checkouts": [],
        },
        {
            "id": "server-2",
            "lastUpdatedAt": "2025-01-02T00:00:00Z",
            "name": {"en": "Server Two"},
            "metadata": {},
            "checkouts": [],
        },
    ]

    mgr.add_resources(
        server_catalogs=server_catalogs,
        checkout_catalogs=[],
        description="Test generation",
    )

    gen_id = mgr._load_todo().generation
    servers_dir = mgr.staged_dir / "manifest" / ".generations" / gen_id / "resources" / "servers"
    assert servers_dir.is_dir()
    assert (servers_dir / "server-1.json").is_file()
    assert (servers_dir / "server-2.json").is_file()

    content = json.loads((servers_dir / "server-1.json").read_text(encoding="utf-8"))
    assert content["id"] == "server-1"

    # Verify catalog.json
    catalog = json.loads(
        (
            mgr.staged_dir / "manifest" / ".generations" / gen_id / "resources" / "catalog.json"
        ).read_text(encoding="utf-8")
    )
    assert sorted(catalog["servers"]) == ["server-1", "server-2"]


def test_add_resources_writes_checkout_catalogs(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    checkout_id = "a" * 64
    checkout_catalogs = [
        {
            "id": checkout_id,
            "createdAt": "2025-01-01T00:00:00Z",
            "serverId": "server-1",
            "metadata": {},
            "files": [],
        },
    ]

    mgr.add_resources(
        server_catalogs=[],
        checkout_catalogs=checkout_catalogs,
        description="Test generation",
    )

    gen_id = mgr._load_todo().generation
    prefix = checkout_id[:2]

    # Per-generation path
    gen_cc = (
        mgr.staged_dir
        / "manifest"
        / ".generations"
        / gen_id
        / "resources"
        / "checkouts"
        / f"{checkout_id}.json"
    )
    assert gen_cc.is_file()

    # Flat registry path
    flat_cc = mgr.staged_dir / "manifest" / "checkouts" / prefix / f"{checkout_id}.json"
    assert flat_cc.is_file()

    content = json.loads(gen_cc.read_text(encoding="utf-8"))
    assert content["id"] == checkout_id


def test_add_resources_appends_todo_operation(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    mgr.add_resources(
        server_catalogs=[{"id": "s1", "name": {}}],
        checkout_catalogs=[],
        description="Gen desc",
    )

    todo = _load_json_model(mgr.session_dir / "todo.json", TodoList)
    assert len(todo.operations) == 1
    op = todo.operations[0]
    assert isinstance(op, AddResourcesOp)
    assert op.description == "Gen desc"
    assert op.server_catalogs == [{"id": "s1", "name": {}}]


def test_add_resources_rejects_missing_server_id(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    with pytest.raises(ValueError, match="missing non-empty string 'id'"):
        mgr.add_resources(
            server_catalogs=[{"name": {}}],
            checkout_catalogs=[],
        )


def test_add_resources_rejects_missing_checkout_id(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    with pytest.raises(ValueError, match="missing non-empty string 'id'"):
        mgr.add_resources(
            server_catalogs=[],
            checkout_catalogs=[{"serverId": "s1"}],
        )


def test_add_announcements_copies_files(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")
    source_dir = _make_announcement_source(tmp_path / "source")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    mgr.add_announcements(source_dir=source_dir)

    staged = mgr.staged_dir / "announcements"
    assert (staged / "files" / "en" / "ann-001").is_file()
    assert (staged / "files" / "zh" / "ann-001").is_file()
    assert (staged / "files" / "en" / "ann-002").is_file()
    assert (staged / "registry" / "ann-001.json").is_file()
    assert (staged / "registry" / "ann-002.json").is_file()


def test_add_announcements_appends_todo_operation(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")
    source_dir = _make_announcement_source(tmp_path / "source")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    mgr.add_announcements(source_dir=source_dir)

    todo = _load_json_model(mgr.session_dir / "todo.json", TodoList)
    assert len(todo.operations) == 1
    assert isinstance(todo.operations[0], AddAnnouncementsOp)
    assert todo.operations[0].source_dir == str(source_dir)


def test_add_announcements_requires_files_dir(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    empty = tmp_path / "empty-source"
    empty.mkdir()

    with pytest.raises(FileNotFoundError, match="Announcement files directory not found"):
        mgr.add_announcements(source_dir=empty)


def test_add_release_hashes_and_stages_apk(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    apk_path = tmp_path / "app.apk"
    _make_dummy_apk(apk_path, "test apk binary")

    mgr.add_release(version="2.0.0", apk_path=apk_path)

    todo = _load_json_model(mgr.session_dir / "todo.json", TodoList)
    assert len(todo.operations) == 1
    assert isinstance(todo.operations[0], AddReleaseOp)
    op = todo.operations[0]
    assert isinstance(op, AddReleaseOp)
    assert op.version == "2.0.0"
    assert len(op.apk_hash) == 64

    # Verify APK staged at correct path
    prefix = op.apk_hash[:2]
    staged_apk = mgr.staged_dir / "resources" / "releases" / prefix / op.apk_hash
    assert staged_apk.is_file()
    assert staged_apk.read_text(encoding="utf-8") == "test apk binary"


def test_add_release_with_announcement(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    apk_path = tmp_path / "app.apk"
    _make_dummy_apk(apk_path)

    mgr.add_release(
        version="2.0.0",
        apk_path=apk_path,
        announcement_id="ann-001",
    )

    todo = _load_json_model(mgr.session_dir / "todo.json", TodoList)
    op = todo.operations[0]
    assert isinstance(op, AddReleaseOp)
    assert op.announcement_id == "ann-001"


def test_regenerate_merged_produces_tree(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    mgr.add_resources(
        server_catalogs=[{"id": "s1", "name": {"en": "S1"}}],
        checkout_catalogs=[],
        description="Gen desc",
    )

    merged_root = mgr.regenerate_merged(Channel.TESTING)

    channel_dir = merged_root / "efa" / "v2" / "testing"
    assert channel_dir.is_dir()
    assert (channel_dir / "manifest" / "index.json").is_file()
    assert (channel_dir / "manifest" / "generations.json").is_file()

    gen_id = mgr._load_todo().generation
    gen_dir = channel_dir / "manifest" / ".generations" / gen_id
    assert gen_dir.is_dir()
    assert (gen_dir / "catalog.json").is_file()


def test_regenerate_merged_writes_correct_index(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    mgr.add_resources(
        server_catalogs=[{"id": "s1", "name": {}}],
        checkout_catalogs=[],
        description="Test generation",
    )

    merged_root = mgr.regenerate_merged(Channel.TESTING)

    index = json.loads(
        (merged_root / "efa" / "v2" / "testing" / "manifest" / "index.json").read_text(
            encoding="utf-8"
        )
    )
    assert index["manifestVersion"] == 1
    assert index["activatedGeneration"] == mgr._load_todo().generation


def test_regenerate_merged_writes_generations_json(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    mgr.add_resources(
        server_catalogs=[{"id": "s1", "name": {}}],
        checkout_catalogs=[],
        description="Test generation",
    )

    merged_root = mgr.regenerate_merged(Channel.TESTING)

    gens = json.loads(
        (merged_root / "efa" / "v2" / "testing" / "manifest" / "generations.json").read_text(
            encoding="utf-8"
        )
    )
    gen_id = mgr._load_todo().generation
    assert gen_id in gens
    assert gens[gen_id]["id"] == gen_id
    assert gens[gen_id]["description"] == "Test generation"


def test_regenerate_merged_with_announcements(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")
    source_dir = _make_announcement_source(tmp_path / "source")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    mgr.add_announcements(source_dir=source_dir)

    merged_root = mgr.regenerate_merged(Channel.TESTING)
    gen_id = mgr._load_todo().generation
    ann_catalog_path = (
        merged_root
        / "efa"
        / "v2"
        / "testing"
        / "manifest"
        / ".generations"
        / gen_id
        / "announcements"
        / "catalog.json"
    )
    assert ann_catalog_path.is_file()
    catalog = json.loads(ann_catalog_path.read_text(encoding="utf-8"))
    assert "entries" in catalog
    entry_ids = [e["id"] for e in catalog["entries"]]
    assert "ann-001" in entry_ids
    assert "ann-002" in entry_ids


def test_regenerate_merged_with_release(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Test session",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    apk_path = tmp_path / "app.apk"
    _make_dummy_apk(apk_path)
    mgr.add_release(version="3.0.0", apk_path=apk_path)

    merged_root = mgr.regenerate_merged(Channel.TESTING)
    gen_id = mgr._load_todo().generation

    release_catalog_path = (
        merged_root
        / "efa"
        / "v2"
        / "testing"
        / "manifest"
        / ".generations"
        / gen_id
        / "releases"
        / "catalog.json"
    )
    assert release_catalog_path.is_file()
    catalog = json.loads(release_catalog_path.read_text(encoding="utf-8"))
    assert len(catalog["entries"]) == 1
    assert catalog["entries"][0]["version"] == "3.0.0"


def test_regenerate_merged_full_workflow(tmp_path: Path) -> None:
    """End-to-end: prepare → add resources + announcements + release → merge."""
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")
    source_dir = _make_announcement_source(tmp_path / "source")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Release v2.0.0",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    mgr.add_resources(
        server_catalogs=[
            {"id": "srv-alpha", "name": {"en": "Alpha"}, "checkouts": []},
            {"id": "srv-beta", "name": {"en": "Beta"}, "checkouts": []},
        ],
        checkout_catalogs=[],
        description="Release v2.0.0",
    )

    mgr.add_announcements(source_dir=source_dir)

    apk_path = tmp_path / "release.apk"
    _make_dummy_apk(apk_path, "release v2.0.0 apk")
    mgr.add_release(version="2.0.0", apk_path=apk_path, announcement_id="ann-001")

    merged_root = mgr.regenerate_merged(Channel.TESTING)

    # Verify top-level structure
    ch = merged_root / "efa" / "v2" / "testing"
    assert ch.is_dir()
    assert (ch / "manifest" / "index.json").is_file()
    assert (ch / "manifest" / "generations.json").is_file()

    gen_id = mgr._load_todo().generation
    gen = ch / "manifest" / ".generations" / gen_id
    assert (gen / "catalog.json").is_file()
    assert (gen / "resources" / "catalog.json").is_file()
    assert (gen / "resources" / "servers" / "srv-alpha.json").is_file()
    assert (gen / "resources" / "servers" / "srv-beta.json").is_file()
    assert (gen / "announcements" / "catalog.json").is_file()
    assert (gen / "releases" / "catalog.json").is_file()

    # Verify announcements content is in merged tree
    assert (ch / "announcements" / "files" / "en" / "ann-001").is_file()
    assert (ch / "announcements" / "registry" / "ann-001.json").is_file()


def test_add_resources_stages_assets(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Asset staging test",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    content = b"test asset content"
    content_hash = "c" * 64
    path_hash = "p" * 64
    normalized = "data/test.bin"

    schema_dir = tmp_path / "schema"
    asset_path = schema_dir / "assets" / path_hash[:2] / path_hash / content_hash
    asset_path.parent.mkdir(parents=True)
    asset_path.write_bytes(content)

    checkout_catalog = {
        "id": "aa00000000000000000000000000000000",
        "serverId": "test-srv",
        "files": {
            normalized: {
                "pathHash": path_hash,
                "hash": content_hash,
                "size": len(content),
            }
        },
    }
    server_catalog = {
        "id": "test-srv",
        "checkouts": [{"id": checkout_catalog["id"]}],
    }

    mock_dp = type("MockPaths", (), {"schema_dir": schema_dir})()
    mock_dev = type("MockDev", (), {"paths": mock_dp})()

    with patch("data.lib.config.DEV_CONFIGURATION", mock_dev):
        mgr.add_resources(
            server_catalogs=[server_catalog],
            checkout_catalogs=[checkout_catalog],
        )

    staged_asset = (
        mgr.staged_dir / "resources" / "assets" / path_hash[:2] / path_hash / content_hash
    )
    assert staged_asset.is_file()
    assert staged_asset.read_bytes() == content


def test_add_resources_missing_asset_raises(tmp_path: Path) -> None:
    sessions_root = tmp_path / "sessions"
    origin_dir = _make_local_origin(tmp_path / "origin", "testing")

    mgr = SessionManager.prepare(
        sessions_root,
        backend="local",
        description="Missing asset test",
        channel=Channel.TESTING,
        origin_dir=origin_dir,
    )

    schema_dir = tmp_path / "schema"

    checkout_catalog = {
        "id": "bb00000000000000000000000000000000",
        "serverId": "test-srv",
        "files": {
            "missing.bin": {
                "pathHash": "q" * 64,
                "hash": "d" * 64,
                "size": 999,
            }
        },
    }
    server_catalog = {
        "id": "test-srv",
        "checkouts": [{"id": checkout_catalog["id"]}],
    }

    mock_dp = type("MockPaths", (), {"schema_dir": schema_dir})()
    mock_dev = type("MockDev", (), {"paths": mock_dp})()

    with (
        patch("data.lib.config.DEV_CONFIGURATION", mock_dev),
        pytest.raises(FileNotFoundError, match="Asset not found"),
    ):
        mgr.add_resources(
            server_catalogs=[server_catalog],
            checkout_catalogs=[checkout_catalog],
        )
