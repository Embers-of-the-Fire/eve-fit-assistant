"""Generation-level diff and remote-state reading for the efa/v2/ layout.

Pure functions — no filesystem or network I/O side-effects beyond reading JSON.
"""

from __future__ import annotations

import json

from dataclasses import dataclass
from typing import TYPE_CHECKING


if TYPE_CHECKING:
    from pathlib import Path


@dataclass
class GenerationSnapshot:
    gen_id: str
    servers: dict[str, list[str]]
    checkouts: dict[str, dict]
    releases: dict[str, dict]
    announcements: dict[str, str]


@dataclass
class EntityChange:
    added: list[str]
    removed: list[str]
    unchanged: list[str]
    changed: list[str]


@dataclass
class ServerDiff:
    server_id: str
    status: str
    checkout_changes: EntityChange | None = None


@dataclass
class GenerationDiff:
    gen_id: str
    baseline_gen_id: str
    servers: list[ServerDiff]
    releases: EntityChange
    announcements: EntityChange


def read_generation_from_staged(staged_dir: Path, gen_id: str) -> GenerationSnapshot:
    resources = staged_dir / "manifest" / ".generations" / gen_id / "resources"
    return _read_generation_resources(resources, gen_id)


def read_generation_from_remote(
    remote_state_dir: Path, channel: str, gen_id: str | None = None
) -> GenerationSnapshot:
    ch_dir = remote_state_dir / channel

    if gen_id is None:
        index_path = ch_dir / "manifest" / "index.json"
        if not index_path.exists():
            raise FileNotFoundError(
                f"Remote index not found: {index_path}\n"
                f"  Run './x remote prepare init' to re-fetch."
            )
        with index_path.open("r", encoding="utf-8") as f:
            index = json.load(f)
        gen_id = index.get("activatedGeneration", "")
        if not gen_id:
            raise ValueError("No activated generation in remote index.")

    resources = ch_dir / "manifest" / ".generations" / gen_id / "resources"
    return _read_generation_resources(resources, gen_id)


def _read_generation_resources(resources_dir: Path, gen_id: str) -> GenerationSnapshot:
    servers: dict[str, list[str]] = {}
    checkouts: dict[str, dict] = {}

    servers_dir = resources_dir / "servers"
    if servers_dir.exists():
        for sf in sorted(servers_dir.glob("*.json")):
            with sf.open("r", encoding="utf-8") as f:
                server = json.load(f)
            sid = server.get("id", sf.stem)
            ck_list = [c.get("id", "") for c in server.get("checkouts", [])]
            servers[str(sid)] = [cid for cid in ck_list if cid]

    checkouts_dir = resources_dir / "checkouts"
    if checkouts_dir.exists():
        for cf in sorted(checkouts_dir.glob("*.json")):
            with cf.open("r", encoding="utf-8") as f:
                checkout = json.load(f)
            file_count = len(checkout.get("files", {}))
            total_size = sum(f.get("size", 0) for f in checkout.get("files", {}).values())
            checkouts[checkout["id"]] = {
                "id": checkout["id"],
                "serverId": checkout.get("serverId", ""),
                "fileCount": file_count,
                "totalSize": total_size,
            }

    return GenerationSnapshot(
        gen_id=gen_id,
        servers=servers,
        checkouts=checkouts,
        releases={},
        announcements={},
    )


def diff_generations(pending: GenerationSnapshot, baseline: GenerationSnapshot) -> GenerationDiff:
    server_diffs: list[ServerDiff] = []
    all_pending = set(pending.servers.keys())
    all_baseline = set(baseline.servers.keys())

    for sid in sorted(all_pending | all_baseline):
        in_pending = sid in all_pending
        in_baseline = sid in all_baseline

        if in_pending and not in_baseline:
            server_diffs.append(ServerDiff(server_id=sid, status="added"))
            continue
        if not in_pending and in_baseline:
            server_diffs.append(ServerDiff(server_id=sid, status="removed"))
            continue

        pending_ck = set(pending.servers.get(sid, []))
        baseline_ck = set(baseline.servers.get(sid, []))

        if pending_ck == baseline_ck:
            server_diffs.append(ServerDiff(server_id=sid, status="unchanged"))
        else:
            added = sorted(pending_ck - baseline_ck)
            removed = sorted(baseline_ck - pending_ck)
            unchanged = sorted(pending_ck & baseline_ck)
            server_diffs.append(
                ServerDiff(
                    server_id=sid,
                    status="changed",
                    checkout_changes=EntityChange(
                        added=added,
                        removed=removed,
                        unchanged=unchanged,
                        changed=[],
                    ),
                )
            )

    all_releases = set(pending.releases.keys()) | set(baseline.releases.keys())
    rel_added = sorted(
        r for r in all_releases if r in pending.releases and r not in baseline.releases
    )
    rel_removed = sorted(
        r for r in all_releases if r not in pending.releases and r in baseline.releases
    )
    rel_unchanged = sorted(
        r
        for r in all_releases
        if r in pending.releases
        and r in baseline.releases
        and pending.releases[r] == baseline.releases[r]
    )
    rel_changed = sorted(
        r
        for r in all_releases
        if r in pending.releases
        and r in baseline.releases
        and pending.releases[r] != baseline.releases[r]
    )
    releases_diff = EntityChange(
        added=rel_added, removed=rel_removed, unchanged=rel_unchanged, changed=rel_changed
    )

    all_anns = set(pending.announcements.keys()) | set(baseline.announcements.keys())
    ann_added = sorted(
        a for a in all_anns if a in pending.announcements and a not in baseline.announcements
    )
    ann_removed = sorted(
        a for a in all_anns if a not in pending.announcements and a in baseline.announcements
    )
    ann_unchanged = sorted(
        a
        for a in all_anns
        if a in pending.announcements
        and a in baseline.announcements
        and pending.announcements[a] == baseline.announcements[a]
    )
    ann_changed = sorted(
        a
        for a in all_anns
        if a in pending.announcements
        and a in baseline.announcements
        and pending.announcements[a] != baseline.announcements[a]
    )
    announcements_diff = EntityChange(
        added=ann_added, removed=ann_removed, unchanged=ann_unchanged, changed=ann_changed
    )

    return GenerationDiff(
        gen_id=pending.gen_id,
        baseline_gen_id=baseline.gen_id,
        servers=server_diffs,
        releases=releases_diff,
        announcements=announcements_diff,
    )
