"""Promotion — admit testing-channel snapshots into the stable channel.

A promotion creates a new generation on the target channel whose
``GenerationResources``/``ServerIndex`` overlay the admitted (server, checkout)
pairs onto the target parent, inheriting the release pointer unchanged. The
history merge in ``GenerationStore.create`` stamps each admitted pair with the
promotion timestamp; unchanged servers add no history entries.

The suppression list (``channels/heads/{channel}/suppressions.json``) is the
veto hook for the scheduled auto-promote path: listed pairs are never admitted
unless ``respect_suppressions`` is disabled (``--force``).
"""

from __future__ import annotations

import datetime

from dataclasses import dataclass
from dataclasses import field
from typing import TYPE_CHECKING

from bootstrap.remote.channel import Channel
from bootstrap.remote.generation import utc_timestamp
from bootstrap.remote.models import GenerationMetadata
from bootstrap.remote.models import read_pb2
from bootstrap.remote.paths import generation_dir


if TYPE_CHECKING:
    from pathlib import Path

    from bootstrap.remote import SessionManager
    from bootstrap.remote.models import ResourceSnapshotMetadata
    from bootstrap.remote.models import ServerHistory


#: Minimum age of a testing publish before it is eligible for stable.
SOAK_PERIOD = datetime.timedelta(hours=24)


class PromotionError(Exception):
    """Raised for expected promotion failures (unknown checkout, missing head)."""


@dataclass
class PromoteResult:
    """Structured outcome of a promotion attempt."""

    source: str
    target: str
    generation_hash: str = ""
    admitted: dict[str, str] = field(default_factory=dict)
    skipped_idempotent: dict[str, str] = field(default_factory=dict)
    skipped_suppressed: dict[str, str] = field(default_factory=dict)

    @property
    def noop(self) -> bool:
        """True when nothing was admitted (no generation, no head movement)."""
        return not self.admitted


def parse_iso8601(value: str) -> datetime.datetime | None:
    """Parse an ISO 8601 UTC timestamp; None when unparseable."""
    try:
        return datetime.datetime.fromisoformat(value)
    except ValueError:
        return None


def compute_promotion_eligibility(
    history: ServerHistory,
    resources,
    now: datetime.datetime,
    soak: datetime.timedelta = SOAK_PERIOD,
) -> dict[str, str]:
    """Return ``{server_id: checkout}`` for head snapshots past the soak window.

    A server's head snapshot is eligible iff its newest history entry (which
    must be the head snapshot) has timestamp ≤ ``now - soak``.
    """
    head = {entry.server_id: entry.snapshot_hash for entry in resources.entries}
    cutoff = now - soak
    eligible: dict[str, str] = {}
    for server in history.servers:
        snap_hash = head.get(server.server_id)
        if not snap_hash or not server.snapshots:
            continue
        newest = server.snapshots[0]
        if newest.snapshot_hash != snap_hash:
            continue
        ts = parse_iso8601(newest.timestamp)
        if ts is not None and ts <= cutoff:
            eligible[server.server_id] = snap_hash
    return eligible


def promote(
    mgr: SessionManager,
    *,
    source: Channel = Channel.TESTING,
    target: Channel = Channel.STABLE,
    candidates: dict[str, str],
    actor: str,
    respect_suppressions: bool = True,
    allow_missing_head: bool = False,
) -> PromoteResult:
    """Admit ``{server_id: checkout}`` pairs from *source* into *target*.

    Validates every candidate against the source head generation's resources or
    its advertised history, filters idempotent and suppressed pairs, then
    creates and pushes the target generation. Idempotent: admitting an
    already-admitted checkout is a no-op for history and head.
    """
    result = PromoteResult(source=str(source), target=str(target))

    # 1. Source head + generation; candidates must resolve against them.
    try:
        source_head = mgr.head_store.get_head(str(source))
    except FileNotFoundError:
        raise PromotionError(f"Source channel {source} has no head metadata") from None
    if not source_head.generation_hash:
        raise PromotionError(f"Source channel {source} has no head generation")
    source_gen = mgr.gen_store.load(source_head.generation_hash)

    valid = _valid_source_checkouts(mgr.root, source_gen)
    unknown = {
        f"{server}:{checkout}"
        for server, checkout in candidates.items()
        if checkout not in valid.get(server, set())
    }
    if unknown:
        raise PromotionError(
            "Unknown candidate checkout(s) not present in the source channel's "
            f"head resources or history: {', '.join(sorted(unknown))}"
        )

    # 2. Target parent generation (bootstrap promotion may start from nothing).
    parent_hash: str | None = None
    parent_gen = None
    try:
        target_head = mgr.head_store.get_head(str(target))
    except FileNotFoundError:
        target_head = None
    if target_head is not None and target_head.generation_hash:
        parent_hash = target_head.generation_hash
        parent_gen = mgr.gen_store.load(parent_hash)
    elif not allow_missing_head:
        raise PromotionError(
            f"Target channel {target} has no head generation; pass "
            "allow_missing_head for the bootstrap promotion"
        )

    # 3. Filter: idempotent pairs first, then suppressed pairs.
    target_current = (
        {entry.server_id: entry.snapshot_hash for entry in parent_gen.resources.entries}
        if parent_gen is not None
        else {}
    )
    suppressed = {
        (entry.server, entry.checkout)
        for entry in mgr.head_store.get_suppressions(str(target)).suppressions
    }
    admitted: dict[str, str] = {}
    for server, checkout in candidates.items():
        if target_current.get(server) == checkout:
            result.skipped_idempotent[server] = checkout
        elif respect_suppressions and (server, checkout) in suppressed:
            result.skipped_suppressed[server] = checkout
        else:
            admitted[server] = checkout

    # 4. No-op: no generation, no head movement.
    if not admitted:
        return result

    # 5. Build the overlaid generation data.
    server_index = _overlay_server_index(mgr, parent_gen, admitted)
    resources = _overlay_resources(parent_gen, admitted)
    release_pointer = _inherited_release_pointer(parent_gen)

    subject_pairs = ", ".join(f"{server}:{admitted[server]}" for server in sorted(admitted))
    metadata = GenerationMetadata(
        parent=parent_hash,
        channel=str(target),
        timestamp=utc_timestamp(),
        subject=(f"promote {source_head.generation_hash} servers=[{subject_pairs}] actor={actor}"),
    )

    # 6. Create + push; the history merge stamps promoted_at = timestamp.
    gen_hash = mgr.gen_store.create(
        metadata=metadata,
        server_index_msg=server_index,
        resources_msg=resources,
        release_pointer=release_pointer,
    )
    mgr.ensure_channel(str(target))
    mgr.head_store.push(str(target), gen_hash)

    result.generation_hash = gen_hash
    result.admitted = admitted
    return result


def write_promotion_report(mgr: SessionManager, result: PromoteResult, path: Path) -> None:
    """Write a JSON promotion report for workflow handoff (e.g. bot notify jobs).

    The report is written for every outcome, including quiet periods, so the
    consumer can distinguish "nothing promoted" from a missing report. Each
    admitted entry embeds the snapshot's full metadata (aliased field names,
    matching ``metadata.json`` on disk).
    """
    import json

    admitted: list[dict] = []
    for server, checkout in sorted(result.admitted.items()):
        meta: ResourceSnapshotMetadata = mgr.snap_store.load_resource_snapshot(checkout)[0]
        admitted.append(
            {
                "server": server,
                "checkout": checkout,
                "metadata": json.loads(meta.model_dump_json(by_alias=True)),
            }
        )
    report = {
        "schemaVersion": 1,
        "source": result.source,
        "target": result.target,
        "generation": result.generation_hash,
        "quiet": result.noop,
        "admitted": admitted,
        "skippedSuppressed": [
            {"server": server, "checkout": checkout}
            for server, checkout in sorted(result.skipped_suppressed.items())
        ],
    }
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def _valid_source_checkouts(root: Path, source_gen) -> dict[str, set[str]]:
    """Valid (promotable) checkouts per server: head resources plus history."""
    from bootstrap.remote.models import ServerHistory

    valid: dict[str, set[str]] = {}
    for entry in source_gen.resources.entries:
        valid.setdefault(entry.server_id, set()).add(entry.snapshot_hash)

    history_path = generation_dir(root, source_gen.hash) / "history.pb2"
    if history_path.is_file():
        history = read_pb2(history_path, ServerHistory)
        for server in history.servers:
            for snap in server.snapshots:
                valid.setdefault(server.server_id, set()).add(snap.snapshot_hash)
    return valid


def _overlay_server_index(mgr: SessionManager, parent_gen, admitted: dict[str, str]):
    """Parent's ServerIndex with admitted servers' entries rebuilt from snapshots.

    Each admitted entry describes the admitted checkout, not the source head:
    historical checkouts (admitted via the source history) carry their own
    gameBuild/gameVersion, and servers absent from the source head still get
    an entry.
    """
    from bootstrap.remote.models import ServerIndex

    merged = ServerIndex()
    merged.schema_version = 1
    if parent_gen is not None:
        merged.CopyFrom(parent_gen.server_index)

    existing = {entry.server_id: idx for idx, entry in enumerate(merged.servers)}
    for server, checkout in admitted.items():
        meta, _ = mgr.snap_store.load_resource_snapshot(checkout)
        entry = merged.servers[existing[server]] if server in existing else merged.servers.add()
        _apply_snapshot_metadata(entry, meta)
    return merged


def _apply_snapshot_metadata(entry, meta) -> None:
    """Rebuild a ServerIndex entry from a snapshot's ResourceSnapshotMetadata."""
    entry.server_id = meta.server_id
    entry.game_build = meta.game_build
    entry.game_version = meta.game_version
    entry.ClearField("region")
    entry.ClearField("sync")
    entry.ClearField("branch")
    if meta.game_region:
        entry.region = meta.game_region
    if meta.game_sync:
        entry.sync = meta.game_sync
    if meta.game_branch:
        entry.branch = meta.game_branch
    entry.name.clear()
    for locale, display in (meta.name or {"en": meta.server_id}).items():
        entry.name[locale] = display


def _overlay_resources(parent_gen, admitted: dict[str, str]):
    """Parent's GenerationResources overlaid with the admitted pairs."""
    from bootstrap.remote.models import GenerationResources

    merged = GenerationResources()
    merged.schema_version = 1

    seen: set[str] = set()
    if parent_gen is not None:
        for entry in parent_gen.resources.entries:
            new_entry = merged.entries.add()
            new_entry.server_id = entry.server_id
            new_entry.snapshot_hash = admitted.get(entry.server_id, entry.snapshot_hash)
            seen.add(entry.server_id)
    for server, checkout in admitted.items():
        if server in seen:
            continue
        new_entry = merged.entries.add()
        new_entry.server_id = server
        new_entry.snapshot_hash = checkout
    return merged


def _inherited_release_pointer(parent_gen):
    """The release pointer passes through promotions unchanged."""
    from bootstrap.remote.models import GenerationPointer

    pointer = GenerationPointer()
    pointer.schema_version = 1
    pointer.snapshot_hash = parent_gen.release_pointer.snapshot_hash if parent_gen else ""
    return pointer
