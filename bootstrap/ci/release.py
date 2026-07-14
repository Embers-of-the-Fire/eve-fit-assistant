from __future__ import annotations

import re
import subprocess
import tomllib

from typing import TYPE_CHECKING

import click

from bootstrap.config import ProjectVersion
from bootstrap.constant import PROJECT_ROOT


if TYPE_CHECKING:
    from pathlib import Path


_VERSION_RE = re.compile(r"^version\s*:\s*(.+?)\s*$", re.MULTILINE)


def _version_key(version: ProjectVersion) -> tuple[object, ...]:
    core = (version.major, version.minor, version.patch)
    pre = (0, version.pre_label, version.pre_num) if version.is_prerelease() else (1, "", 0)
    return (*core, *pre)


def _version_greater_than(a: ProjectVersion, b: ProjectVersion) -> bool:
    return _version_key(a) > _version_key(b)


def _load_version_from_config(path: Path) -> ProjectVersion:
    try:
        with open(path, "rb") as f:
            cfg = tomllib.load(f)
    except FileNotFoundError as exc:
        raise click.ClickException(f"Config file not found: {path}") from exc
    except tomllib.TOMLDecodeError as exc:
        raise click.ClickException(f"Invalid TOML in {path}: {exc}") from exc

    try:
        return ProjectVersion.model_validate(cfg["version"])
    except KeyError as exc:
        raise click.ClickException(f"Missing [version] section in {path}") from exc
    except Exception as exc:
        raise click.ClickException(f"Invalid version in {path}: {exc}") from exc


def _load_version_from_git_ref(base_ref: str) -> ProjectVersion:
    try:
        result = subprocess.run(
            ["git", "show", f"{base_ref}:efa.config.toml"],
            capture_output=True,
            text=True,
            check=True,
            cwd=PROJECT_ROOT,
        )
    except subprocess.CalledProcessError as exc:
        raise click.ClickException(
            f"Failed to read efa.config.toml from ref {base_ref!r}: {exc.stderr.strip()}"
        ) from exc
    except FileNotFoundError as exc:
        raise click.ClickException("git is required for --base-ref") from exc

    try:
        cfg = tomllib.loads(result.stdout)
    except tomllib.TOMLDecodeError as exc:
        raise click.ClickException(f"Invalid TOML in {base_ref}:efa.config.toml: {exc}") from exc

    try:
        return ProjectVersion.model_validate(cfg["version"])
    except KeyError as exc:
        raise click.ClickException(
            f"Missing [version] section in {base_ref}:efa.config.toml"
        ) from exc
    except Exception as exc:
        raise click.ClickException(f"Invalid version in {base_ref}:efa.config.toml: {exc}") from exc


def _read_pubspec_version(path: Path) -> str:
    if not path.is_file():
        raise click.ClickException(f"File not found: {path}")
    text = path.read_text(encoding="utf-8")
    match = _VERSION_RE.search(text)
    if not match:
        raise click.ClickException(f"Missing 'version:' line in {path}")
    value = match.group(1).strip()
    if value.startswith(("'", '"')) and value.endswith(("'", '"')):
        value = value[1:-1]
    return value


def _read_toml_version(path: Path) -> str:
    if not path.is_file():
        raise click.ClickException(f"File not found: {path}")
    try:
        with open(path, "rb") as f:
            data = tomllib.load(f)
    except tomllib.TOMLDecodeError as exc:
        raise click.ClickException(f"Invalid TOML in {path}: {exc}") from exc

    for key_path in (("project", "version"), ("package", "version"), ("version",)):
        value = data
        for key in key_path:
            if not isinstance(value, dict) or key not in value:
                break
            value = value[key]
        else:
            return value

    raise click.ClickException(f"Missing 'version' key in {path}")


def _normalize_version_for_notes(version: ProjectVersion) -> str:
    return version.render_semver().replace(".", "-")


def _check_notes(version: ProjectVersion) -> None:
    normalized = _normalize_version_for_notes(version)
    notes_dir = PROJECT_ROOT / "docs" / "changelog" / normalized
    if not notes_dir.is_dir():
        raise click.ClickException(
            f"Changelog directory not found: {notes_dir}\nExpected docs/changelog/{normalized}/"
        )
    missing: list[str] = []
    for name in ("spec.yaml", "changelog.md"):
        if not (notes_dir / name).is_file():
            missing.append(name)
    if missing:
        raise click.ClickException(
            f"Missing changelog files in {notes_dir}:\n  " + "\n  ".join(missing)
        )


def register_ci_release_commands(ci_group: click.Group) -> None:
    @ci_group.group("release")
    def release_group():
        """Release CI/CD helper commands."""

    @release_group.command("verify")
    @click.option(
        "--base-ref",
        default=None,
        help="Git ref to compare the current version against.",
    )
    @click.option(
        "--check-notes",
        is_flag=True,
        default=False,
        help="Verify that changelog notes exist for the current version.",
    )
    def release_verify(base_ref: str | None, check_notes: bool):
        """Verify that the current version is consistent and valid."""
        config_path = PROJECT_ROOT / "efa.config.toml"
        version = _load_version_from_config(config_path)
        full = version.render_full()
        semver = version.render_semver()
        tag = version.render_tag()

        click.echo(f"Canonical version: {full}")
        click.echo(f"Semver version:    {semver}")

        derived = [
            (PROJECT_ROOT / "pubspec.yaml", full, "full"),
            (PROJECT_ROOT / "rust" / "Cargo.toml", semver, "semver"),
            (PROJECT_ROOT / "pyproject.toml", semver, "semver"),
        ]

        for path, expected, kind in derived:
            if path.name == "pubspec.yaml":
                actual = _read_pubspec_version(path)
            else:
                actual = _read_toml_version(path)
            if actual != expected:
                raise click.ClickException(
                    f"Version mismatch in {path.relative_to(PROJECT_ROOT)}:\n"
                    f"  expected ({kind}): {expected}\n"
                    f"  actual:             {actual}\n"
                    f"  Update the file to match efa.config.toml."
                )
            click.echo(f"  {path.relative_to(PROJECT_ROOT)} OK ({kind}: {actual})")

        if base_ref is not None:
            base_version = _load_version_from_git_ref(base_ref)
            if not _version_greater_than(version, base_version):
                raise click.ClickException(
                    f"Current version {semver} is not greater than base version "
                    f"{base_version.render_semver()} from {base_ref}."
                )
            click.echo(f"  Version check OK: {semver} > {base_version.render_semver()}")

        if check_notes:
            _check_notes(version)
            click.echo("  Changelog notes OK")

        click.echo(f"Expected tag: {tag}")
