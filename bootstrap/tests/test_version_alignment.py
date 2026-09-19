"""Invariant tests keeping the storage version axes aligned across the repo.

The repository has several independent version axes, each single-sourced:

- Fit-storage envelope: ``currentFitStorageVersion`` in
  ``apps/eve-fit-assistant/lib/storage/fit/persistence.dart``
- Fit-registry envelope: ``currentFitRegistryVersion`` (same file)
- Native text payload inner envelope: ``currentNativeFitPayloadVersion`` (same file)
- ``EFA<n>:`` outer prefix: ``currentEfaFitFormatVersion`` /
  ``efaFitLinkPayloadPrefix`` in ``packages/efa_fit/lib/src/efa_format.dart``
- Repo data schema: ``[version].data_schema`` in ``efa.config.toml``, generated
  into ``apps/eve-fit-assistant/lib/storage/repo/repo_version.dart``

These tests fail when any copy of these numbers (docs examples, the TypeScript
mirror, generated output) drifts from its source, or when a version number is
baked into a source/test file name.
"""

from __future__ import annotations

import re
import tomllib

from typing import TYPE_CHECKING

from bootstrap.constant import PROJECT_ROOT


if TYPE_CHECKING:
    from pathlib import Path


_PERSISTENCE = PROJECT_ROOT / "apps/eve-fit-assistant/lib/storage/fit/persistence.dart"
_EFA_FORMAT = PROJECT_ROOT / "packages/efa_fit/lib/src/efa_format.dart"
_REPO_VERSION = PROJECT_ROOT / "apps/eve-fit-assistant/lib/storage/repo/repo_version.dart"
_DOC = PROJECT_ROOT / "docs/dev/fit-storage.md"
_TS_PAYLOAD = PROJECT_ROOT / "site/platform/src/lib/fit-payload.ts"
_CONFIG = PROJECT_ROOT / "efa.config.toml"

_FILENAME_SCAN_ROOTS = (
    PROJECT_ROOT / "apps/eve-fit-assistant/lib",
    PROJECT_ROOT / "apps/eve-fit-assistant/test",
)
_FILENAME_MARKER = re.compile(r"_v\d+|v\d+_")


def _dart_int_const(path: Path, name: str) -> int:
    match = re.search(rf"const (?:int )?{name} = (\d+);", path.read_text(encoding="utf-8"))
    assert match, f"{name} not found in {path}"
    return int(match.group(1))


def _dart_string_const(path: Path, name: str) -> str:
    match = re.search(rf'const String {name} = "([^"]+)";', path.read_text(encoding="utf-8"))
    assert match, f"{name} not found in {path}"
    return match.group(1)


def test_efa_prefix_matches_current_format_version():
    prefix = _dart_string_const(_EFA_FORMAT, "efaFitLinkPayloadPrefix")
    current = _dart_int_const(_EFA_FORMAT, "currentEfaFitFormatVersion")
    legacy = _dart_int_const(_EFA_FORMAT, "legacyEfaFitFormatVersion")
    assert prefix == f"EFA{current}:"
    assert legacy < current


def test_data_schema_config_matches_generated_dart():
    config = tomllib.loads(_CONFIG.read_text(encoding="utf-8"))
    configured = config["version"]["data_schema"]
    generated = _dart_int_const(_REPO_VERSION, "currentSchemaVersion")
    assert generated == configured, (
        "repo_version.dart is stale; run ./x generate dart "
        f"(config={configured}, generated={generated})"
    )


def test_typescript_mirror_matches_efa_prefix():
    prefix = _dart_string_const(_EFA_FORMAT, "efaFitLinkPayloadPrefix")
    ts = _TS_PAYLOAD.read_text(encoding="utf-8")
    match = re.search(r'PAYLOAD_PREFIX = "([^"]+)"', ts)
    assert match, f"PAYLOAD_PREFIX not found in {_TS_PAYLOAD}"
    assert match.group(1) == prefix


def test_fit_storage_doc_examples_match_constants():
    doc = _DOC.read_text(encoding="utf-8")
    fit_version = _dart_int_const(_PERSISTENCE, "currentFitStorageVersion")
    registry_version = _dart_int_const(_PERSISTENCE, "currentFitRegistryVersion")
    prefix = _dart_string_const(_EFA_FORMAT, "efaFitLinkPayloadPrefix")

    fit_example = re.search(r'\{\s*"version": (\d+),\s*"fit"', doc)
    assert fit_example, "fit file JSON example not found in fit-storage.md"
    assert int(fit_example.group(1)) == fit_version, (
        f"fit-storage.md fit example shows version {fit_example.group(1)}, current is {fit_version}"
    )

    registry_example = re.search(r'\{\s*"version": (\d+),\s*"registry"', doc)
    assert registry_example, "registry JSON example not found in fit-storage.md"
    assert int(registry_example.group(1)) == registry_version, (
        f"fit-storage.md registry example shows version {registry_example.group(1)}, "
        f"current is {registry_version}"
    )

    assert f"`{prefix}`" in doc, f"fit-storage.md does not mention the current {prefix} prefix"
    assert f"newer than `{prefix}`" in doc, (
        "fit-storage.md does not state the rejection bound for newer EFA prefixes"
    )


def test_no_version_numbers_in_source_filenames():
    roots = [*_FILENAME_SCAN_ROOTS]
    for packages_dir in sorted((PROJECT_ROOT / "packages").iterdir()):
        for sub in ("lib", "test", "dart/lib", "dart/test"):
            candidate = packages_dir / sub
            if candidate.is_dir():
                roots.append(candidate)
    offenders = []
    for root in roots:
        for path in root.rglob("*"):
            if path.is_file() and _FILENAME_MARKER.search(path.name):
                offenders.append(path.relative_to(PROJECT_ROOT).as_posix())
    assert not offenders, "version numbers must not appear in source/test file names: " + ", ".join(
        offenders
    )
