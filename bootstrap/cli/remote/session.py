from __future__ import annotations

import json

from pathlib import Path

import click

from colorama import Fore
from colorama import Style

from bootstrap.cli import runtime
from bootstrap.cli.remote.helpers import validate_remote_channel
from bootstrap.color import styled
from bootstrap.log import warning
from bootstrap.remote import SessionManager
from bootstrap.remote import SessionManagerCommittedError
from bootstrap.remote import SessionManagerInvalidError
from bootstrap.remote.session_model import Session
from bootstrap.remote.session_model import SessionExistsError
from bootstrap.remote.session_model import SessionStore
from bootstrap.remote.verify import Verifier


def _require_session(store: SessionStore, operation: str) -> Session:
    """Load the session, raise ClickException if not present."""
    try:
        return store.load()
    except FileNotFoundError:
        raise click.ClickException(
            "No active session. Run './x remote session init' first."
        ) from None


def _validate_add_args(
    resource_flag: bool,
    release_flag: bool,
    source_hash: str | None,
    source_file: Path | None,
) -> str:
    """Validate mutually exclusive add flags. Returns the snap type."""
    if resource_flag == release_flag:
        raise click.ClickException("Must specify exactly one of --resource, --release.")
    if source_hash is None and source_file is None:
        raise click.ClickException("Must specify exactly one of --hash or --file.")
    if source_hash is not None and source_file is not None:
        raise click.ClickException("Cannot specify both --hash and --file.")
    return "resource" if resource_flag else "release"


def _check_snapshot_metadata(snap_type: str, snap_dir: Path) -> None:
    """Verify that metadata.json matches the expected snapshot type."""
    from bootstrap.remote.models import ReleaseSnapshotMetadata
    from bootstrap.remote.models import ResourceSnapshotMetadata
    from bootstrap.remote.models import read_json

    metadata_path = snap_dir / "metadata.json"
    if not metadata_path.is_file():
        raise click.ClickException(f"Snapshot directory missing metadata.json: {snap_dir}")

    meta_raw = read_json(metadata_path)

    model_for_type = {
        "resource": ResourceSnapshotMetadata,
        "release": ReleaseSnapshotMetadata,
    }

    try:
        model_for_type[snap_type].model_validate(meta_raw)
        return
    except Exception:
        pass

    for other_type, other_model in model_for_type.items():
        if other_type == snap_type:
            continue
        try:
            other_model.model_validate(meta_raw)
            raise click.ClickException(
                f"Snapshot metadata at {snap_dir} declares type '{other_type}', not '{snap_type}'."
            ) from None
        except Exception:
            continue

    raise click.ClickException(
        f"Snapshot metadata at {snap_dir} is not a valid '{snap_type}' metadata JSON."
    )


def _resolve_snapshot_hash_from_prefix(root: Path, snap_type: str, prefix: str) -> str:
    """Resolve a hash prefix to a full snapshot hash."""
    from bootstrap.remote.snapshot import SnapshotStore

    if not prefix:
        raise click.ClickException("Snapshot hash prefix must not be empty")

    snap_store = SnapshotStore(root)
    list_for_type: dict[str, object] = {
        "resource": snap_store.list_resource_snapshots,
        "release": snap_store.list_release_snapshots,
    }
    candidates = [h for h in list_for_type[snap_type]() if h.startswith(prefix)]

    if len(candidates) == 0:
        raise click.ClickException(f"No {snap_type} snapshot found with prefix '{prefix}'")
    if len(candidates) == 1:
        return candidates[0]

    raise click.ClickException(
        f"Multiple {snap_type} snapshots found with prefix '{prefix}':\n"
        + "\n".join(f"  {c}" for c in candidates)
    )


def _add_snapshot_by_hash(
    store: SessionStore,
    root: Path,
    snap_type: str,
    hash_value: str,
    *,
    replace_hash: str | None = None,
) -> None:
    """Verify snapshot existence + metadata type, then stage.

    When *snap_type* is ``"resource"``:
      - If *replace_hash* is given, validates the replace target exists, its
        server_id matches the new snapshot, and calls ``replace_snapshot``.
      - Otherwise rejects the add if the server_id is already staged.
    """
    from bootstrap.remote.paths import release_snapshot_dir
    from bootstrap.remote.paths import resource_snapshot_dir
    from bootstrap.remote.snapshot import SnapshotStore

    dir_for_type = {
        "resource": resource_snapshot_dir,
        "release": release_snapshot_dir,
    }
    snap_dir = dir_for_type[snap_type](root, hash_value)
    if not snap_dir.is_dir():
        raise click.ClickException(f"Snapshot {hash_value[:16]}... not found at {snap_dir}")
    _check_snapshot_metadata(snap_type, snap_dir)

    if snap_type == "resource":
        snap_store = SnapshotStore(root)
        meta, _ = snap_store.load_resource_snapshot(hash_value)
        candidate_server_id = meta.server_id

        session = store.load()
        staged_ids = _staged_server_ids(root, session)

        if replace_hash is not None:
            if replace_hash not in session.staged.resources:
                raise click.ClickException(
                    f"Replace target {replace_hash[:16]}... is not currently staged."
                )
            replace_meta, _ = snap_store.load_resource_snapshot(replace_hash)
            if replace_meta.server_id != candidate_server_id:
                raise click.ClickException(
                    f"Server mismatch: --replace targets server "
                    f"'{replace_meta.server_id}' but new snapshot is for "
                    f"server '{candidate_server_id}'."
                )
            store.replace_snapshot(replace_hash, hash_value)
        else:
            if candidate_server_id in staged_ids:
                conflict = staged_ids[candidate_server_id]
                raise click.ClickException(
                    f"Server '{candidate_server_id}' already has a staged snapshot "
                    f"({conflict[:16]}...) in this session. "
                    "A session may stage at most one snapshot per server. "
                    "Commit and release this session, then run "
                    "`./x remote session init <channel>` to start a new "
                    "session for the additional "
                    f"'{candidate_server_id}' snapshot."
                )
            store.add_snapshot(
                "resource",
                hash_value,
                server_id=candidate_server_id,
                staged_server_ids=staged_ids,
            )
    else:
        if replace_hash is not None:
            raise click.ClickException(
                "--replace is only supported for resource snapshots, not release snapshots."
            )
        store.add_snapshot(snap_type, hash_value)  # type: ignore[arg-type]


def _add_snapshot_by_file(
    store: SessionStore, root: Path, snap_type: str, source_file: Path
) -> None:
    """Read a catalog/registry file, compute snapshot, and stage."""
    import json as _json

    from bootstrap.remote.models import ReleaseSnapshotMetadata
    from bootstrap.remote.models import ResourceSnapshotMetadata
    from bootstrap.remote.snapshot import SnapshotStore

    raw = source_file.read_text(encoding="utf-8")
    try:
        data = _json.loads(raw)
    except _json.JSONDecodeError as e:
        raise click.ClickException(f"Cannot parse {source_file}: {e}") from None

    snap_store = SnapshotStore(root)

    if snap_type == "resource":
        from bootstrap.remote.models import make_resource_index

        try:
            metadata = ResourceSnapshotMetadata.model_validate(data["metadata"])
            entries = data["entries"]
        except KeyError as e:
            raise click.ClickException(
                f"Invalid resource catalog in {source_file}: "
                f"missing key {e} (expected 'metadata' and 'entries')"
            ) from None
        except Exception as e:
            raise click.ClickException(
                f"Cannot parse resource metadata in {source_file}: {e}"
            ) from None

        index_entries: list[tuple[str, str, int]] = []
        try:
            for entry in entries:
                index_entries.append(
                    (entry["resource_id"], entry["content_hash"], int(entry["size"]))
                )
        except KeyError as e:
            raise click.ClickException(
                f"Invalid resource catalog entry in {source_file}: missing key {e}"
            ) from None
        except (TypeError, ValueError) as e:
            raise click.ClickException(
                f"Invalid resource catalog entry in {source_file}: invalid value: {e}"
            ) from None
        index = make_resource_index(index_entries)
        hash_value = snap_store.create_resource_snapshot(metadata, index)

    elif snap_type == "release":
        from bootstrap.remote.blob import BlobStore
        from bootstrap.remote.hash import ident_hash
        from bootstrap.remote.models import make_release_index

        try:
            metadata = ReleaseSnapshotMetadata.model_validate(data["metadata"])
            release = data["release"]
        except KeyError as e:
            raise click.ClickException(
                f"Invalid release registry in {source_file}: "
                f"missing key {e} (expected 'metadata' and 'release')"
            ) from None
        except Exception as e:
            raise click.ClickException(
                f"Cannot parse release metadata in {source_file}: {e}"
            ) from None

        try:
            version = release["version"]
            blob_store = BlobStore(root)

            for platform_key, platform_data in list(release.items()):
                if platform_key in ("id", "version"):
                    continue
                if not isinstance(platform_data, dict):
                    continue
                for variant, value in list(platform_data.items()):
                    if isinstance(value, str):
                        candidate = Path(value)
                        if candidate.is_absolute():
                            file_path = candidate
                        else:
                            file_path = (source_file.parent / candidate).resolve()
                        uri = f"release://{version}/{platform_key}/{variant}"
                        ihash = ident_hash(uri)
                        chash = blob_store.store_from_path(file_path, ihash)
                        platform_data[variant] = {
                            "identifier": uri,
                            "content_hash": chash,
                            "size": file_path.stat().st_size,
                        }

            android = release.get("android")
            android_dict = None
            if android is not None:
                android_dict = {
                    key: android.get(key)
                    for key in ("general", "armv7", "arm64", "x64")
                    if android.get(key) is not None
                }
            index = make_release_index(
                release_id=release["id"],
                version=version,
                android=android_dict,
            )
        except KeyError as e:
            raise click.ClickException(
                f"Invalid release registry entry in {source_file}: missing key {e}"
            ) from None
        hash_value = snap_store.create_release_snapshot(metadata, index)

    else:
        raise click.ClickException(f"Unknown snapshot type: {snap_type}")

    if snap_type == "resource":
        session = store.load()
        staged_ids = _staged_server_ids(root, session)
        candidate_server_id = metadata.server_id
        if candidate_server_id in staged_ids:
            conflict = staged_ids[candidate_server_id]
            raise click.ClickException(
                f"Server '{candidate_server_id}' already has a staged snapshot "
                f"({conflict[:16]}...) in this session. "
                "A session may stage at most one snapshot per server. "
                "Commit and release this session, then run "
                "`./x remote session init <channel>` to start a new "
                "session for the additional "
                f"'{candidate_server_id}' snapshot."
            )
        store.add_snapshot(
            snap_type,
            hash_value,
            server_id=candidate_server_id,
            staged_server_ids=staged_ids,
        )
    else:
        store.add_snapshot(snap_type, hash_value)  # type: ignore[arg-type]


def _staged_server_ids(root: Path, session: Session) -> dict[str, str]:
    """Build a map of server_id → hash for all staged resource snapshots.

    Skips unloadable hashes (same tolerance as _compute_diff).
    """
    from bootstrap.remote.snapshot import SnapshotStore

    snap_store = SnapshotStore(root)
    result: dict[str, str] = {}
    for h in session.staged.resources:
        try:
            meta, _ = snap_store.load_resource_snapshot(h)
            result[meta.server_id] = h
        except Exception:
            warning("Failed to load staged resource snapshot %s; omitted from server-id map", h)
    return result


def _get_snapshot_summary(root: Path, snap_type: str, hash_value: str) -> str:
    """Return a human-readable metadata summary for a staged snapshot."""
    from bootstrap.remote.snapshot import SnapshotStore

    snap_store = SnapshotStore(root)
    try:
        if snap_type == "resource":
            meta, _ = snap_store.load_resource_snapshot(hash_value)
            return f"server_id={meta.server_id}  game_build={meta.game_build}"
        elif snap_type == "release":
            meta, _ = snap_store.load_release_snapshot(hash_value)
            vmin = meta.version_min or "?"
            vmax = meta.version_max or "?"
            return f"version_min={vmin}  version_max={vmax}"
    except Exception:
        return "(metadata unavailable)"
    return ""


def _compute_diff(root: Path, session: Session) -> dict:
    """Compare session staged hashes against the current channel head.

    Categories (with accumulation in mind):
      - added:     staged snapshot, server not in head
      - updated:   staged snapshot, server in head with DIFFERENT snapshot hash
      - unchanged: staged snapshot, server in head with SAME snapshot hash
      - inherited: server in head, NOT staged (carried forward by accumulation)
    """
    from bootstrap.remote.generation import GenerationStore
    from bootstrap.remote.head import ChannelHeadStore
    from bootstrap.remote.snapshot import SnapshotStore

    head_store = ChannelHeadStore(root)
    gen_store = GenerationStore(root)
    snap_store = SnapshotStore(root)

    head_hash: str | None = None
    head_resources: dict[str, str] = {}
    head_release: str | None = None

    try:
        head = head_store._safe_get_head(session.channel)
        if head and head.generation_hash:
            head_hash = head.generation_hash
            generation = gen_store.load(head.generation_hash)
            for entry in generation.resources.entries:
                head_resources[entry.server_id] = entry.snapshot_hash
            if generation.release_pointer.snapshot_hash:
                head_release = generation.release_pointer.snapshot_hash
    except Exception:
        pass

    staged_resources: dict[str, str] = {}
    duplicate_servers: dict[str, list[str]] = {}
    for h in session.staged.resources:
        try:
            meta, _ = snap_store.load_resource_snapshot(h)
            if meta.server_id in staged_resources:
                dupes = duplicate_servers.setdefault(meta.server_id, [])
                if not dupes:
                    dupes.append(staged_resources[meta.server_id])
                dupes.append(h)
            else:
                staged_resources[meta.server_id] = h
        except Exception:
            warning("Failed to load staged resource snapshot %s; omitted from diff", h)

    added: list[str] = []
    updated: list[str] = []
    unchanged: list[str] = []
    inherited: list[str] = []

    staged_ids = set(staged_resources.keys())
    head_ids = set(head_resources.keys())

    for sid in staged_ids - head_ids:
        added.append(staged_resources[sid])
    for sid in staged_ids & head_ids:
        if staged_resources[sid] != head_resources[sid]:
            updated.append(staged_resources[sid])
        else:
            unchanged.append(staged_resources[sid])
    for sid in head_ids - staged_ids:
        inherited.append(head_resources[sid])

    head_releases = {head_release} if head_release else set()
    staged_releases = set(session.staged.releases)

    result: dict = {
        "channel": session.channel,
        "head": head_hash,
        "resources": {
            "added": sorted(added),
            "updated": sorted(updated),
            "unchanged": sorted(unchanged),
            "inherited": sorted(inherited),
        },
        "releases": {
            "added": sorted(staged_releases - head_releases),
            "updated": [],
            "unchanged": sorted(staged_releases & head_releases),
            "inherited": sorted(head_releases - staged_releases),
        },
    }

    if duplicate_servers:
        result["duplicate_servers"] = duplicate_servers

    return result


def _check_staged_resource_blobs(root: Path, hash_value: str, issues: list) -> None:
    """Verify all blobs referenced by a staged resource snapshot exist."""
    from bootstrap.remote.hash import content_hash as _content_hash
    from bootstrap.remote.hash import ident_hash as _ident_hash
    from bootstrap.remote.models import ResourceIndex
    from bootstrap.remote.models import read_pb2
    from bootstrap.remote.paths import blob_path
    from bootstrap.remote.paths import resource_snapshot_dir
    from bootstrap.remote.verify import Issue

    proto_path = resource_snapshot_dir(root, hash_value) / "resources.pb2"
    try:
        index = read_pb2(proto_path, ResourceIndex)
    except Exception:
        issues.append(
            Issue(
                entity=hash_value[:12] + "...",
                entity_type="resource_snapshot",
                severity="error",
                message=f"Cannot read ResourceIndex from {proto_path}",
            )
        )
        return

    for entry in index.entries:
        ihash = _ident_hash(entry.resource_id)
        bpath = blob_path(root, ihash, entry.content_hash)
        if not bpath.is_file():
            issues.append(
                Issue(
                    entity=entry.resource_id,
                    entity_type="blob",
                    severity="error",
                    message=f"Missing blob: {bpath}",
                )
            )
            continue

        try:
            actual_hash = _content_hash(bpath.read_bytes())
            if actual_hash != entry.content_hash:
                issues.append(
                    Issue(
                        entity=entry.resource_id,
                        entity_type="blob",
                        severity="error",
                        message=(
                            f"Content hash mismatch: expected"
                            f" {entry.content_hash[:12]}..."
                            f", got {actual_hash[:12]}..."
                        ),
                    )
                )
        except Exception as exc:
            issues.append(
                Issue(
                    entity=entry.resource_id,
                    entity_type="blob",
                    severity="error",
                    message=str(exc),
                )
            )


def _check_duplicate_server_ids(root: Path, session: Session, issues: list) -> None:
    """Check for multiple staged resource snapshots with the same server_id.

    Appends ``Issue`` (severity ``"error"``) for each duplicated server.
    This is a hard gate — even ``--force`` must not bypass it.
    """
    from bootstrap.remote.snapshot import SnapshotStore
    from bootstrap.remote.verify import Issue

    snap_store = SnapshotStore(root)
    seen: dict[str, str] = {}
    for h in session.staged.resources:
        try:
            meta, _ = snap_store.load_resource_snapshot(h)
        except Exception:
            warning("Failed to load staged resource snapshot %s; omitted from duplicate check", h)
            continue
        if meta.server_id in seen:
            issues.append(
                Issue(
                    entity=f"{meta.server_id}",
                    entity_type="server_id",
                    severity="error",
                    message=(
                        f"Duplicate server '{meta.server_id}' in staged resources: "
                        f"{seen[meta.server_id][:12]}... and {h[:12]}... "
                        "A session may stage at most one snapshot per server."
                    ),
                )
            )
        else:
            seen[meta.server_id] = h


def _verify_staged(root: Path, session: Session) -> list:
    """Validate staged snapshots across all four verification phases."""
    from bootstrap.remote.hash import verify_snapshot_hash as _verify_snapshot_hash
    from bootstrap.remote.paths import release_snapshot_dir
    from bootstrap.remote.paths import resource_snapshot_dir
    from bootstrap.remote.verify import Issue

    issues: list = []

    dir_for_type: dict[str, callable] = {
        "resource": resource_snapshot_dir,
        "release": release_snapshot_dir,
    }
    proto_names: dict[str, str] = {
        "resource": "resources.pb2",
        "release": "releases.pb2",
    }
    staged_map: dict[str, list[str]] = {
        "resource": session.staged.resources,
        "release": session.staged.releases,
    }

    for snap_type in ("resource", "release"):
        proto_name = proto_names[snap_type]
        staged_hashes = staged_map[snap_type]
        for h in staged_hashes:
            snap_dir = dir_for_type[snap_type](root, h)
            if not snap_dir.is_dir():
                issues.append(
                    Issue(
                        entity=h[:12] + "...",
                        entity_type=f"{snap_type}_snapshot",
                        severity="error",
                        message=f"Directory not found: {snap_dir}",
                    )
                )
                continue

            meta_path = snap_dir / "metadata.json"
            proto_path = snap_dir / proto_name

            if not meta_path.is_file():
                issues.append(
                    Issue(
                        entity=h[:12] + "...",
                        entity_type=f"{snap_type}_snapshot",
                        severity="error",
                        message="Missing metadata.json",
                    )
                )
                continue

            if not proto_path.is_file():
                issues.append(
                    Issue(
                        entity=h[:12] + "...",
                        entity_type=f"{snap_type}_snapshot",
                        severity="error",
                        message=f"Missing {proto_name}",
                    )
                )
                continue

            try:
                files = {
                    "metadata.json": meta_path.read_bytes(),
                    proto_name: proto_path.read_bytes(),
                }
                # Dual-read: accept either v4 (binds the .pb2 index) or legacy v3.
                if not _verify_snapshot_hash(snap_type, files, h):
                    issues.append(
                        Issue(
                            entity=h[:12] + "...",
                            entity_type=f"{snap_type}_snapshot",
                            severity="error",
                            message=f"Hash mismatch: {h[:12]}... does not verify (v4/v3)",
                        )
                    )
            except Exception as exc:
                issues.append(
                    Issue(
                        entity=h[:12] + "...",
                        entity_type=f"{snap_type}_snapshot",
                        severity="error",
                        message=f"Hash computation failed: {exc}",
                    )
                )

        if snap_type == "resource":
            for h in staged_hashes:
                snap_dir = dir_for_type[snap_type](root, h)
                if snap_dir.is_dir() and (snap_dir / proto_name).is_file():
                    _check_staged_resource_blobs(root, h, issues)

            _check_duplicate_server_ids(root, session, issues)

    try:
        from bootstrap.remote.head import ChannelHeadStore

        head_store = ChannelHeadStore(root)
        registry = head_store.get_registry()
        if session.channel not in registry.channels:
            issues.append(
                Issue(
                    entity=session.channel,
                    entity_type="channel",
                    severity="warning",
                    message=(
                        f"Channel {session.channel!r} not in registry "
                        "(will be auto-created on commit)"
                    ),
                )
            )
    except Exception as exc:
        issues.append(
            Issue(
                entity=session.channel,
                entity_type="channel",
                severity="warning",
                message=f"Channel check failed: {exc}",
            )
        )

    return issues


def _print_issues(issues: list) -> None:
    for issue in issues:
        color = Fore.RED if issue.severity == "error" else Fore.YELLOW
        click.echo(
            f"  {issue.entity[:16] if len(issue.entity) > 16 else issue.entity}"
            + styled(Style.DIM, f"  [{issue.entity_type}]")
            + styled([Style.BRIGHT, color], f"  {issue.severity}")
            + styled(Style.DIM, f"  {issue.message}")
        )


def _build_generation_data(snap_store, staged_resources, staged_releases, parent_gen=None):
    """Build generation data structures from staged resources & releases.

    Seeds from *parent_gen* if provided (accumulation model), then overlays
    staged resource snapshots (updating existing server entries or adding new
    ones) and sets the release pointer from staged releases (falling back to
    the parent's pointer if none staged).

    Returns (server_index, gen_resources, release_ptr).
    """
    from bootstrap.remote.models import GenerationPointer
    from bootstrap.remote.models import GenerationResources
    from bootstrap.remote.models import ServerIndex

    server_index = ServerIndex()
    server_index.schema_version = 1
    gen_resources = GenerationResources()
    gen_resources.schema_version = 1

    if parent_gen is not None:
        for srv in parent_gen.server_index.servers:
            srv_entry = server_index.servers.add()
            srv_entry.CopyFrom(srv)
        for res in parent_gen.resources.entries:
            res_entry = gen_resources.entries.add()
            res_entry.CopyFrom(res)

    for hash_val in staged_resources:
        meta, _ = snap_store.load_resource_snapshot(hash_val)

        srv_existing = None
        for srv in server_index.servers:
            if srv.server_id == meta.server_id:
                srv_existing = srv
                break

        if srv_existing is not None:
            srv_existing.game_build = meta.game_build
            srv_existing.game_version = meta.game_version
            srv_existing.ClearField("region")
            srv_existing.ClearField("sync")
            srv_existing.ClearField("branch")
            if meta.game_region:
                srv_existing.region = meta.game_region
            if meta.game_sync:
                srv_existing.sync = meta.game_sync
            if meta.game_branch:
                srv_existing.branch = meta.game_branch
            srv_existing.name.clear()
            if meta.name:
                for locale, display_name in meta.name.items():
                    srv_existing.name[locale] = display_name
            else:
                srv_existing.name["en"] = meta.server_id
        else:
            srv_entry = server_index.servers.add()
            srv_entry.server_id = meta.server_id
            if meta.name:
                for locale, display_name in meta.name.items():
                    srv_entry.name[locale] = display_name
            else:
                srv_entry.name["en"] = meta.server_id
            srv_entry.game_build = meta.game_build
            srv_entry.game_version = meta.game_version
            if meta.game_region:
                srv_entry.region = meta.game_region
            if meta.game_sync:
                srv_entry.sync = meta.game_sync
            if meta.game_branch:
                srv_entry.branch = meta.game_branch

        res_existing = None
        for res in gen_resources.entries:
            if res.server_id == meta.server_id:
                res_existing = res
                break

        if res_existing is not None:
            res_existing.snapshot_hash = hash_val
        else:
            gentry = gen_resources.entries.add()
            gentry.server_id = meta.server_id
            gentry.snapshot_hash = hash_val

    release_ptr = GenerationPointer()
    release_ptr.schema_version = 1
    if parent_gen is not None:
        release_ptr.snapshot_hash = parent_gen.release_pointer.snapshot_hash
    else:
        release_ptr.snapshot_hash = ""
    if staged_releases:
        release_ptr.snapshot_hash = staged_releases[-1]

    return server_index, gen_resources, release_ptr


_SCHEMA_ROOT_OPTION = click.option(
    "--schema-root",
    type=click.Path(path_type=Path),
    default=None,
    help="Schema V2 storage root (default from dev config).",
)


def register_remote_session(remote: click.Group) -> None:
    @remote.group("session")
    def remote_session():
        """Staged generation assembly — build, stage, review, commit."""

    @remote_session.command("init")
    @click.argument("channel")
    @click.option(
        "--force-overwrite",
        is_flag=True,
        default=False,
        help="Overwrite an existing session.",
    )
    @_SCHEMA_ROOT_OPTION
    def remote_session_init(channel: str, force_overwrite: bool, schema_root: Path | None):
        """Create a new staging session for generation assembly."""
        root = runtime.resolve_schema_root(schema_root)
        resolved_channel = validate_remote_channel(channel)
        mgr = SessionManager(root)
        mgr.ensure_channel(resolved_channel.value)
        store = SessionStore(root)
        try:
            store.init(resolved_channel.value, force_overwrite=force_overwrite)
        except SessionExistsError as e:
            raise click.ClickException(str(e)) from None
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Session initialized on channel ")
            + resolved_channel.value
        )
        click.echo(styled(Style.DIM, f"  Session file: {store.session_path}"))

    @remote_session.command("status")
    @click.option("--json", "as_json", is_flag=True, default=False, help="Machine-readable output.")
    @_SCHEMA_ROOT_OPTION
    def remote_session_status(as_json: bool, schema_root: Path | None):
        """Show current session summary."""
        root = runtime.resolve_schema_root(schema_root)
        store = SessionStore(root)
        if not store.exists():
            if as_json:
                click.echo(json.dumps({"active": False}))
            else:
                click.echo(styled(Style.DIM, "No active session."))
            return
        session = store.load()
        staged = session.staged
        if as_json:
            click.echo(
                json.dumps(
                    {
                        "active": True,
                        "channel": session.channel,
                        "committed": session.committed,
                        "staged_counts": {
                            "resources": len(staged.resources),
                            "releases": len(staged.releases),
                        },
                        "file": str(store.session_path),
                    }
                )
            )
        else:
            if session.committed:
                committed_label = styled([Style.BRIGHT, Fore.GREEN], " (committed)")
            else:
                committed_label = styled([Style.BRIGHT, Fore.YELLOW], " (uncommitted)")
            click.echo(f"Session on channel {session.channel}{committed_label}")
            click.echo(f"  Staged:      R:{len(staged.resources)} L:{len(staged.releases)}")
            click.echo(styled(Style.DIM, f"  File:        {store.session_path}"))
            if session.committed:
                mgr = SessionManager(root)
                try:
                    head = mgr.get_head(session.channel)
                    gen_hash = head.generation_hash if head.generation_hash else None
                except Exception:
                    gen_hash = None
                if gen_hash:
                    click.echo(styled(Style.DIM, f"  Head:        {gen_hash[:16]}..."))

    @remote_session.command("discard")
    @click.option(
        "--force",
        is_flag=True,
        default=False,
        help="Discard even if session is committed.",
    )
    @_SCHEMA_ROOT_OPTION
    def remote_session_discard(force: bool, schema_root: Path | None):
        """Delete the current session."""
        root = runtime.resolve_schema_root(schema_root)
        store = SessionStore(root)
        try:
            store.discard(force=force)
        except SessionManagerInvalidError:
            raise click.ClickException(
                "No active session. Run './x remote session init' first."
            ) from None
        except SessionManagerCommittedError:
            raise click.ClickException("Session is committed. Use --force to discard.") from None
        click.echo(f"Session discarded: {store.session_path}")

    @remote_session.command("add")
    @click.option(
        "--resource",
        "resource_flag",
        is_flag=True,
        default=False,
        help="Stage a resource snapshot.",
    )
    @click.option(
        "--release", "release_flag", is_flag=True, default=False, help="Stage a release snapshot."
    )
    @click.option("--hash", "source_hash", default=None, help="Snapshot hash to stage.")
    @click.option(
        "--file",
        "source_file",
        type=click.Path(exists=True, path_type=Path),
        default=None,
        help="File to compute snapshot hash from (checkout catalog, registry).",
    )
    @click.option("--force", is_flag=True, default=False, help="Add to a committed session.")
    @click.option(
        "--replace",
        "replace_hash",
        default=None,
        help="Replace an existing staged snapshot hash (only for resources).",
    )
    @_SCHEMA_ROOT_OPTION
    def remote_session_add(
        resource_flag: bool,
        release_flag: bool,
        source_hash: str | None,
        source_file: Path | None,
        force: bool,
        replace_hash: str | None,
        schema_root: Path | None,
    ):
        """Stage a snapshot for the next generation commit."""
        snap_type = _validate_add_args(resource_flag, release_flag, source_hash, source_file)
        root = runtime.resolve_schema_root(schema_root)
        store = SessionStore(root)

        _require_session(store, "add")

        if not force:
            store.ensure_editable()

        if source_hash is not None:
            full_hash = _resolve_snapshot_hash_from_prefix(root, snap_type, source_hash)
            _add_snapshot_by_hash(store, root, snap_type, full_hash, replace_hash=replace_hash)
            click.echo(
                styled([Style.BRIGHT, Fore.GREEN], f"Staged {snap_type} snapshot ")
                + f"{full_hash[:16]}..."
            )
        elif source_file is not None:
            if replace_hash is not None:
                raise click.ClickException("--replace is not supported with --file.")
            _add_snapshot_by_file(store, root, snap_type, source_file)
            click.echo(
                styled([Style.BRIGHT, Fore.GREEN], f"Staged {snap_type} snapshot ")
                + f"from {source_file}"
            )

    @remote_session.command("remove")
    @click.option(
        "--resource",
        "resource_flag",
        is_flag=True,
        default=False,
        help="Remove a resource snapshot.",
    )
    @click.option(
        "--release", "release_flag", is_flag=True, default=False, help="Remove a release snapshot."
    )
    @click.option("--hash", "source_hash", required=True, help="Snapshot hash to remove.")
    @click.option("--force", is_flag=True, default=False, help="Remove from a committed session.")
    @_SCHEMA_ROOT_OPTION
    def remote_session_remove(
        resource_flag: bool,
        release_flag: bool,
        source_hash: str,
        force: bool,
        schema_root: Path | None,
    ):
        """Unstage a snapshot."""
        if resource_flag == release_flag:
            raise click.ClickException("Must specify exactly one of --resource, --release.")
        snap_type = "resource" if resource_flag else "release"

        root = runtime.resolve_schema_root(schema_root)
        store = SessionStore(root)

        _require_session(store, "remove")

        if not force:
            store.ensure_editable()

        try:
            store.remove_snapshot(snap_type, source_hash)
        except ValueError as e:
            raise click.ClickException(str(e)) from None

        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], f"Removed {snap_type} snapshot ")
            + f"{source_hash[:16]}..."
        )

    @remote_session.command("diff")
    @click.option(
        "--json", "as_json", is_flag=True, default=False, help="Machine-readable diff output."
    )
    @_SCHEMA_ROOT_OPTION
    def remote_session_diff(as_json: bool, schema_root: Path | None):
        """Show changes between staged snapshots and the current channel head."""
        root = runtime.resolve_schema_root(schema_root)
        store = SessionStore(root)

        session = _require_session(store, "diff")

        diff = _compute_diff(root, session)

        if as_json:
            click.echo(json.dumps(diff, indent=2))
            return

        head_str = diff["head"][:16] + "..." if diff["head"] else "none"
        click.echo(
            styled([Style.BRIGHT], f'Diff: staging → channel "{diff["channel"]}"')
            + styled(Style.DIM, f" (head: {head_str})")
        )

        if diff["head"] is None:
            click.echo(styled(Style.DIM, "  No channel head (uninitialized channel)."))
            click.echo(styled(Style.DIM, "  All staged snapshots are new."))
            click.echo()

        type_labels = {
            "resources": "Resources",
            "releases": "Releases",
        }
        for snap_type in ("resources", "releases"):
            data = diff[snap_type]
            display_type = snap_type.removesuffix("s")

            if not any(data.values()):
                continue

            click.echo(f"\n{type_labels[snap_type]}:")

            for h in data["added"]:
                summary = _get_snapshot_summary(root, display_type, h)
                click.echo(
                    styled([Style.BRIGHT, Fore.GREEN], f"  + {h[:16]}...")
                    + styled(Style.DIM, f"  {summary}")
                )
            for h in data["updated"]:
                summary = _get_snapshot_summary(root, display_type, h)
                click.echo(
                    styled([Style.BRIGHT, Fore.YELLOW], f"  * {h[:16]}...")
                    + styled(Style.DIM, f"  {summary}")
                )
            for h in data["inherited"]:
                summary = _get_snapshot_summary(root, display_type, h)
                click.echo(
                    styled([Style.BRIGHT, Fore.CYAN], f"  ~ {h[:16]}...")
                    + styled(Style.DIM, f"  {summary}")
                )
            for h in data["unchanged"]:
                summary = _get_snapshot_summary(root, display_type, h)
                click.echo(styled(Style.DIM, f"  = {h[:16]}...  {summary}"))

    @remote_session.command("verify")
    @click.option("--repair", is_flag=True, default=False, help="Attempt automatic repairs.")
    @_SCHEMA_ROOT_OPTION
    def remote_session_verify(repair: bool, schema_root: Path | None):
        """Validate the staged generation integrity."""
        root = runtime.resolve_schema_root(schema_root)
        store = SessionStore(root)

        session = _require_session(store, "verify")

        if repair:
            verifier = Verifier(root)
            fixed = verifier.repair()
            if fixed > 0:
                click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Repaired {fixed} entity(ies)."))
            else:
                click.echo("No entities needed repair.")
            return

        issues = _verify_staged(root, session)
        error_count = sum(1 for i in issues if i.severity == "error")

        staged_counts = {
            "Resources": len(session.staged.resources),
            "Releases": len(session.staged.releases),
        }

        if not issues:
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "Session verification passed."))
            for label, count in staged_counts.items():
                click.echo(styled(Style.DIM, f"  {label}: {count} staged, {count} ok"))
            return

        click.echo()
        click.echo(
            styled([Style.BRIGHT, Fore.RED], f"Verification failed ({error_count} error(s)):")
        )
        _print_issues(issues)

        if error_count:
            raise SystemExit(1)

    @remote_session.command("commit")
    @click.option(
        "--no-push",
        is_flag=True,
        default=False,
        help="Create generation but do not advance channel head.",
    )
    @click.option(
        "--force",
        is_flag=True,
        default=False,
        help="Skip verification and override committed session.",
    )
    @click.option(
        "--json",
        "as_json",
        is_flag=True,
        default=False,
        help="Emit machine-readable JSON with the generation hash.",
    )
    @_SCHEMA_ROOT_OPTION
    def remote_session_commit(no_push: bool, force: bool, as_json: bool, schema_root: Path | None):
        """Assemble a generation from staged snapshots and advance the channel head."""
        from bootstrap.remote.generation import utc_timestamp
        from bootstrap.remote.models import GenerationMetadata

        root = runtime.resolve_schema_root(schema_root)
        store = SessionStore(root)
        session = _require_session(store, "commit")

        if session.committed and not force:
            raise click.ClickException("Session is committed. Use --force to override.")

        if not any([session.staged.resources, session.staged.releases]):
            raise click.ClickException(
                "No snapshots staged. Use './x remote session add' to stage snapshots."
            )

        if not force:
            issues = _verify_staged(root, session)
            error_count = sum(1 for i in issues if i.severity == "error")
            if error_count:
                click.echo()
                click.echo(
                    styled(
                        [Style.BRIGHT, Fore.RED], f"Verification failed ({error_count} error(s)):"
                    )
                )
                _print_issues(issues)
                raise click.ClickException(
                    "Verification failed. Use --force to skip or fix issues first."
                )

        dupe_issues: list = []
        _check_duplicate_server_ids(root, session, dupe_issues)
        if dupe_issues:
            click.echo()
            _print_issues(dupe_issues)
            raise click.ClickException(
                "Duplicate server IDs in staged resources. "
                "This error cannot be bypassed with --force. "
                "Use './x remote session remove <hash>' to correct the duplicates, "
                "then run commit again."
            )

        mgr = SessionManager(root)
        snap_store = mgr.snap_store
        head_store = mgr.head_store

        resolved_channel = validate_remote_channel(session.channel)

        current_head = head_store._safe_get_head(resolved_channel)
        parent = (
            current_head.generation_hash if current_head and current_head.generation_hash else None
        )

        parent_gen = mgr.gen_store.load(parent) if parent else None

        server_index, gen_resources, release_ptr = _build_generation_data(
            snap_store=snap_store,
            staged_resources=session.staged.resources,
            staged_releases=session.staged.releases,
            parent_gen=parent_gen,
        )

        server_ids: list[str] = []
        for hash_val in session.staged.resources:
            meta, _ = snap_store.load_resource_snapshot(hash_val)
            server_ids.append(meta.server_id)

        release_hash: str | None = None
        if session.staged.releases:
            release_hash = session.staged.releases[-1]

        ts = utc_timestamp()
        meta = GenerationMetadata(
            channel=resolved_channel,
            timestamp=ts,
            subject="",
            parent=parent,
        )

        mgr.ensure_channel(resolved_channel)

        refs_dir = root / "channels" / "refs"
        existing_hashes: set[str] = set()
        if refs_dir.is_dir():
            for entry in refs_dir.iterdir():
                if entry.is_dir() and not entry.name.startswith("tmp"):
                    existing_hashes.add(entry.name)

        gen_hash = mgr.create_generation(
            metadata=meta,
            server_index=server_index,
            resources=gen_resources,
            release_pointer=release_ptr,
        )

        reused = gen_hash in existing_hashes

        if not no_push:
            mgr.push(resolved_channel, gen_hash)

        store.mark_committed()

        if reused:
            click.echo(
                styled(
                    [Style.BRIGHT, Fore.GREEN],
                    f"Generation {gen_hash[:16]}... already exists (reused).",
                )
            )
        else:
            click.echo(
                styled([Style.BRIGHT, Fore.GREEN], f"Generation created: {gen_hash[:16]}...")
            )

        if not no_push:
            click.echo(
                styled([Style.BRIGHT, Fore.GREEN], f"Head advanced on channel {resolved_channel}")
            )
        click.echo(
            styled(
                Style.DIM, f"  Parent:        {parent[:16] + '...' if parent else 'none (root)'}"
            )
        )
        click.echo(
            styled(
                Style.DIM,
                f"  Resources:     {len(session.staged.resources)} snapshots"
                f" ({', '.join(server_ids) if server_ids else 'none'})",
            )
        )
        release_label = f"{release_hash[:16]}..." if release_hash else "none"
        click.echo(styled(Style.DIM, f"  Releases:      {release_label}"))

        if as_json:
            click.echo(
                json.dumps(
                    {
                        "generation_hash": gen_hash,
                        "reused": reused,
                        "head_advanced": not no_push,
                    }
                )
            )
