from __future__ import annotations

import json
import shutil

from typing import TYPE_CHECKING

from data.lib.log import debug
from data.lib.log import error
from data.lib.log import info
from data.lib.log import warning
from data.lib.utils import get_bin_size
from data.lib.workspace.generate import Descriptor
from data.lib.workspace.generate import GeneratorDatasource
from data.lib.workspace.generate.manifest import build_snapshot_manifest
from data.lib.workspace.generate.manifest import load_snapshot_manifest
from data.lib.workspace.generate.manifest import manifest_hash
from data.lib.workspace.generate.manifest import write_snapshot_manifest


if TYPE_CHECKING:
    from pathlib import Path


def _copy_into_patch(source_path: Path, patch_root: Path, relative_path: str) -> None:
    target_path = patch_root / relative_path
    target_path.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source_path, target_path)


def build_increment_bundle(config, baseline_manifest_path: Path):
    warning("Make sure you've already generated the full bundle.")
    warning("Incremental patch bundle depends on the full bundle generation cache.")

    if not baseline_manifest_path.exists() or not baseline_manifest_path.is_file():
        error("Baseline manifest file does not exist.")
        return

    baseline_manifest = load_snapshot_manifest(baseline_manifest_path)
    if baseline_manifest.bundleId != config.metadata.identifier:
        error(
            "Baseline manifest does not match the current workspace bundle id: "
            f"{baseline_manifest.bundleId} != {config.metadata.identifier}"
        )
        return

    datasource = GeneratorDatasource(config, is_incremental=True)
    increment_generated = datasource.paths.increment_generate_out_path
    if increment_generated.exists():
        shutil.rmtree(increment_generated)
    increment_generated.mkdir(parents=True, exist_ok=True)

    current_manifest = build_snapshot_manifest(
        baseline_manifest.bundleId,
        baseline_manifest.generateTimestamp,
        datasource.paths.full_generate_out_path,
        skipped_paths={"descriptor.json", "manifest.json", "deleted_files.json"},
    )
    current_manifest.generateTimestamp = Descriptor.create(datasource).generateTimestamp

    baseline_files = baseline_manifest.file_map
    current_files = current_manifest.file_map

    included = 0
    deleted_files = sorted(set(baseline_files).difference(current_files))
    for relative_path, current_file in current_files.items():
        baseline_file = baseline_files.get(relative_path)
        if baseline_file == current_file:
            continue

        source_path = datasource.paths.full_generate_out_path / relative_path
        _copy_into_patch(source_path, increment_generated, relative_path)
        reason = "new file" if baseline_file is None else "changed file"
        debug(f"Including {relative_path} ({reason})")
        included += 1

    datasource.paths.increment_deleted_files_path.write_text(
        json.dumps(deleted_files, indent=4),
        encoding="utf-8",
    )
    info(f"Generated deleted files manifest at {datasource.paths.increment_deleted_files_path}.")

    descriptor = Descriptor.create(
        datasource,
        base_bundle_id=baseline_manifest.bundleId,
        base_manifest_hash=manifest_hash(baseline_manifest),
    )
    current_manifest.generateTimestamp = descriptor.generateTimestamp
    descriptor.manifestHash = write_snapshot_manifest(
        datasource.paths.increment_manifest_path,
        current_manifest,
    )
    output_manifest_path = datasource.config.paths.output / "bundle_manifest.json"
    output_manifest_path.write_text(
        datasource.paths.increment_manifest_path.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    info(f"Copied snapshot manifest to {output_manifest_path}.")

    with open(datasource.paths.increment_descriptor_path, "w", encoding="utf-8") as f:
        f.write(descriptor.model_dump_json(indent=4))

    info(f"Generated descriptor at {datasource.paths.increment_descriptor_path}.")

    shutil.make_archive(
        str(datasource.config.paths.output / f"{datasource.config.metadata.identifier}_increment"),
        format="zip",
        root_dir=increment_generated,
    )

    out_path = (
        datasource.config.paths.output / f"{datasource.config.metadata.identifier}_increment.zip"
    )

    info(
        "Generated incremental patch archive of "
        f"{get_bin_size(out_path.stat().st_size)} at {out_path}, "
        f"including {included} files and {len(deleted_files)} deletions."
    )
