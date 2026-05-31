"""Catalog/index merge, diff, and verify logic.

All functions are pure — they do not touch the filesystem or network.
Orchestration (session.py) provides the data.
"""

from __future__ import annotations

import copy

from typing import Any


def _deep_merge(base: dict[str, Any], overlay: dict[str, Any]) -> dict[str, Any]:
    """Recursively merge *overlay* into *base* (overlay wins on conflict)."""
    merged = dict(base)
    for key, value in overlay.items():
        if key in merged and isinstance(merged[key], dict) and isinstance(value, dict):
            merged[key] = _deep_merge(merged[key], value)
        elif key in merged and isinstance(merged[key], list) and isinstance(value, list):
            merged[key] = merged[key] + value  # type: ignore[operator]
        else:
            merged[key] = value
    return merged


# ---------------------------------------------------------------------------
# Apply operations
# ---------------------------------------------------------------------------


def _apply_add_announcement(catalog: dict[str, object], op: dict[str, object]) -> None:
    entries: list[object] = catalog.get("entries", [])  # type: ignore[assignment]
    if not isinstance(entries, list):
        return
    entry = dict(op["fields"])  # type: ignore[index]
    doc_id = entry.get("id")
    if doc_id is None:
        return
    for idx, existing in enumerate(entries):
        if isinstance(existing, dict) and existing.get("id") == doc_id:
            entries[idx] = entry
            return
    entries.append(entry)
    catalog["entries"] = entries


def _apply_add_bundle(catalog: dict[str, object], op: dict[str, object]) -> None:
    artifacts: list[object] = catalog.get("artifacts", [])  # type: ignore[assignment]
    if not isinstance(artifacts, list):
        return
    entry = dict(op["fields"])  # type: ignore[index]
    artifact_id = entry.get("artifactId")
    if artifact_id is None:
        return
    for idx, existing in enumerate(artifacts):
        if isinstance(existing, dict) and existing.get("artifactId") == artifact_id:
            artifacts[idx] = entry
            return
    artifacts.append(entry)
    catalog["artifacts"] = artifacts


def _apply_remove(
    op: dict[str, object], docs: dict[str, object], bundles: dict[str, object]
) -> None:
    target_type: str = op.get("target_type", "")  # type: ignore[assignment]
    target_id: str = op.get("target_id", "")  # type: ignore[assignment]
    if target_type == "document":
        entries: list[object] = docs.get("entries", [])  # type: ignore[assignment]
        if not isinstance(entries, list):
            return
        docs["entries"] = [
            e for e in entries if not (isinstance(e, dict) and e.get("id") == target_id)
        ]
    elif target_type == "artifact":
        artifacts: list[object] = bundles.get("artifacts", [])  # type: ignore[assignment]
        if not isinstance(artifacts, list):
            return
        bundles["artifacts"] = [
            a for a in artifacts if not (isinstance(a, dict) and a.get("artifactId") == target_id)
        ]


def apply_operations_to_catalogs(
    index: dict[str, object],
    documents_catalog: dict[str, object],
    bundles_catalog: dict[str, object],
    channel: str,
    operations: list[dict[str, object]],
) -> tuple[dict[str, object], dict[str, object], dict[str, object]]:
    """Return (index, documents_catalog, bundles_catalog) with ops applied in order."""
    merged_index = copy.deepcopy(index)
    merged_docs = copy.deepcopy(documents_catalog)
    merged_bundles = copy.deepcopy(bundles_catalog)

    for op in operations:
        op_type: str = op.get("type", "")  # type: ignore[assignment]
        if op_type == "add-announcement":
            _apply_add_announcement(merged_docs, op)
        elif op_type == "add-bundle":
            _apply_add_bundle(merged_bundles, op)
        elif op_type == "remove":
            _apply_remove(op, merged_docs, merged_bundles)

    _bump_index_revision(merged_index, merged_docs, merged_bundles, channel)
    return merged_index, merged_docs, merged_bundles


def _bump_index_revision(
    index: dict[str, object],
    documents_catalog: dict[str, object],
    bundles_catalog: dict[str, object],
    channel: str,
) -> None:
    import datetime as _dt

    generated_at = (
        _dt.datetime.now(_dt.UTC).replace(microsecond=0).isoformat().replace("+00:00", "Z")
    )
    stamp = generated_at.replace("-", "").replace(":", "")

    index["generatedAt"] = generated_at
    docs = index.get("documents", {})
    if isinstance(docs, dict):
        n_entries = len(documents_catalog.get("entries", []))  # type: ignore[arg-type]
        docs["catalogPath"] = f"channels/{channel}/documents/catalog.json"
        docs["revision"] = f"docs-{stamp}-n{n_entries}"
        index["documents"] = docs

    bundles = index.get("bundles", {})
    if isinstance(bundles, dict):
        n_artifacts = len(bundles_catalog.get("artifacts", []))  # type: ignore[arg-type]
        bundles["catalogPath"] = f"channels/{channel}/bundles/catalog.json"
        bundles["revision"] = f"bundles-{stamp}-n{n_artifacts}"
        index["bundles"] = bundles


# ---------------------------------------------------------------------------
# Diff
# ---------------------------------------------------------------------------


def _diff_dicts(
    before: dict[str, object],
    after: dict[str, object],
    path: str = "",
) -> dict[str, object]:
    result: dict[str, object] = {}
    all_keys = set(before.keys()) | set(after.keys())
    for key in sorted(all_keys):
        current_path = f"{path}.{key}" if path else key
        b_val = before.get(key)
        a_val = after.get(key)
        if key not in before:
            result[current_path] = {"type": "added", "value": a_val}
        elif key not in after:
            result[current_path] = {"type": "removed", "value": b_val}
        elif b_val != a_val:
            if isinstance(b_val, dict) and isinstance(a_val, dict):
                result[current_path] = _diff_dicts(b_val, a_val, current_path)
            else:
                result[current_path] = {"type": "changed", "before": b_val, "after": a_val}
    return result


def _diff_list(
    before: list[object],
    after: list[object],
    id_key: str,
    path: str = "",
) -> dict[str, object]:
    result: dict[str, object] = {}
    before_by_id: dict[str, dict[str, object]] = {}
    after_by_id: dict[str, dict[str, object]] = {}
    for item in before:
        if isinstance(item, dict) and id_key in item:
            before_by_id[str(item[id_key])] = item
    for item in after:
        if isinstance(item, dict) and id_key in item:
            after_by_id[str(item[id_key])] = item

    all_ids = set(before_by_id.keys()) | set(after_by_id.keys())
    added_ids = set(after_by_id.keys()) - set(before_by_id.keys())
    removed_ids = set(before_by_id.keys()) - set(after_by_id.keys())

    for aid in sorted(added_ids):
        result[f"{path}[{aid}]"] = {"type": "added", "value": after_by_id[aid]}
    for rid in sorted(removed_ids):
        result[f"{path}[{rid}]"] = {"type": "removed", "value": before_by_id[rid]}
    for cid in sorted(all_ids - added_ids - removed_ids):
        if before_by_id[cid] != after_by_id[cid]:
            result[f"{path}[{cid}]"] = {
                "type": "changed",
                "before": before_by_id[cid],
                "after": after_by_id[cid],
            }
    return result


def diff_catalogs(
    remote_state: dict[str, object],
    merged_state: dict[str, object],
) -> dict[str, object]:
    """Return a human-readable diff between two (index, docs, bundles) states.

    *remote_state* and *merged_state* are each dicts with keys
    ``index``, ``documents_catalog``, ``bundles_catalog``.
    """
    result: dict[str, object] = {}

    r_idx = remote_state.get("index")
    m_idx = merged_state.get("index")
    if isinstance(r_idx, dict) and isinstance(m_idx, dict):
        result["index"] = _diff_dicts(r_idx, m_idx)

    r_docs = remote_state.get("documents_catalog")
    m_docs = merged_state.get("documents_catalog")
    if isinstance(r_docs, dict) and isinstance(m_docs, dict):
        r_entries = r_docs.get("entries", [])
        m_entries = m_docs.get("entries", [])
        if isinstance(r_entries, list) and isinstance(m_entries, list):
            result["documents"] = _diff_list(r_entries, m_entries, "id")

    r_bundles = remote_state.get("bundles_catalog")
    m_bundles = merged_state.get("bundles_catalog")
    if isinstance(r_bundles, dict) and isinstance(m_bundles, dict):
        r_artifacts = r_bundles.get("artifacts", [])
        m_artifacts = m_bundles.get("artifacts", [])
        if isinstance(r_artifacts, list) and isinstance(m_artifacts, list):
            result["bundles"] = _diff_list(r_artifacts, m_artifacts, "artifactId")

    return result


# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------


def verify_merged_state(
    merged_state: dict[str, object],
    staged_dir_sha256s: dict[str, str],
) -> list[str]:
    """Run internal-consistency checks on merged output.

    Returns a list of error strings (empty = all good).
    """
    errors: list[str] = []

    docs = merged_state.get("documents_catalog")
    if isinstance(docs, dict):
        entries: object = docs.get("entries", [])
        if isinstance(entries, list):
            seen_ids: set[str] = set()
            for _idx, entry in enumerate(entries):
                if not isinstance(entry, dict):
                    continue
                doc_id = entry.get("id")
                if isinstance(doc_id, str):
                    if doc_id in seen_ids:
                        errors.append(f"Duplicate document id in merged output: {doc_id}")
                    seen_ids.add(doc_id)

    bundles = merged_state.get("bundles_catalog")
    if isinstance(bundles, dict):
        artifacts: object = bundles.get("artifacts", [])
        if isinstance(artifacts, list):
            seen_artifact_ids: set[str] = set()
            for _idx, entry in enumerate(artifacts):
                if not isinstance(entry, dict):
                    continue
                a_id = entry.get("artifactId")
                if isinstance(a_id, str):
                    if a_id in seen_artifact_ids:
                        errors.append(f"Duplicate artifact id in merged output: {a_id}")
                    seen_artifact_ids.add(a_id)

                sha256_field = entry.get("artifactSha256")
                if isinstance(sha256_field, str) and isinstance(a_id, str):
                    staged_key = f"bundles/{a_id}.zip"
                    if staged_key in staged_dir_sha256s:
                        expected = staged_dir_sha256s[staged_key]
                        if sha256_field != expected:
                            errors.append(
                                f"SHA256 mismatch for {a_id}: "
                                f"catalog has {sha256_field}, staged has {expected}"
                            )

    return errors
