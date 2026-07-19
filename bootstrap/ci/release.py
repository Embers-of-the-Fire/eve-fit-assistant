from __future__ import annotations

import os
import re
import subprocess
import sys
import tomllib

from pathlib import Path

import click

from bootstrap.cli import runtime
from bootstrap.config import ProjectVersion
from bootstrap.constant import PROJECT_ROOT


_VERSION_RE = re.compile(r"^version\s*:\s*(.+?)\s*$", re.MULTILINE)
_APKSIGNER_DIGEST_RE = re.compile(r"certificate SHA-256 digest:\s*([0-9a-fA-F:]+)")


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


def _check_tag_does_not_exist(version: ProjectVersion) -> None:
    """Fail if the expected release tag already exists in the repository."""
    tag = version.render_tag()
    try:
        result = subprocess.run(
            ["git", "rev-parse", "-q", "--verify", f"refs/tags/{tag}"],
            capture_output=True,
            text=True,
            check=False,
            cwd=PROJECT_ROOT,
        )
    except FileNotFoundError as exc:
        raise click.ClickException("git is required for --check-tag") from exc
    if result.returncode == 0:
        raise click.ClickException(f"Tag {tag} already exists")


def _check_note_content(version: ProjectVersion) -> None:
    """Validate the full content of the release note directory."""
    from bootstrap.docs.bundled_docs import _load_release_note
    from bootstrap.utils import normalize_version_dir

    dir_name = normalize_version_dir(version.render_semver())
    notes_dir = PROJECT_ROOT / "docs" / "changelog" / dir_name
    if not notes_dir.is_dir():
        raise click.ClickException(
            f"Changelog directory not found: {notes_dir}\nExpected docs/changelog/{dir_name}/"
        )

    try:
        _load_release_note(dir_name, notes_dir)
    except ValueError as exc:
        raise click.ClickException(f"Release note content is invalid: {exc}") from exc


def _get_submodule_expected_commit(path: str) -> str:
    try:
        result = subprocess.run(
            ["git", "ls-tree", "HEAD", path],
            capture_output=True,
            text=True,
            check=True,
            cwd=PROJECT_ROOT,
        )
    except subprocess.CalledProcessError as exc:
        raise click.ClickException(
            f"Failed to read expected commit for submodule {path}: {exc.stderr.strip()}"
        ) from exc
    except FileNotFoundError as exc:
        raise click.ClickException("git is required for submodule checks") from exc
    parts = result.stdout.strip().split()
    if len(parts) < 3:
        raise click.ClickException(f"Failed to parse git ls-tree output for {path}")
    return parts[2]


def _get_submodule_actual_commit(path: str) -> str:
    try:
        result = subprocess.run(
            ["git", "-C", str(PROJECT_ROOT / path), "rev-parse", "HEAD"],
            capture_output=True,
            text=True,
            check=True,
        )
    except subprocess.CalledProcessError as exc:
        raise click.ClickException(
            f"Failed to read current commit for submodule {path}: {exc.stderr.strip()}"
        ) from exc
    except FileNotFoundError as exc:
        raise click.ClickException("git is required for submodule checks") from exc
    return result.stdout.strip()


def _ensure_submodule_clean(path: str) -> None:
    """Fail if the submodule has unstaged or staged changes."""
    for flag in ("", "--cached"):
        cmd = ["git", "-C", str(PROJECT_ROOT / path), "diff", "--quiet"]
        if flag:
            cmd.append(flag)
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=False)
        except FileNotFoundError as exc:
            raise click.ClickException("git is required for submodule checks") from exc
        if result.returncode != 0:
            raise click.ClickException(f"Submodule {path} has uncommitted changes")


def _check_submodules() -> None:
    """Verify engine and FSD dumper submodules are initialized and clean."""
    submodules = ["rust/lib/eve-fit-os", "tools/eve-fsd-dumper"]
    for path in submodules:
        submodule_path = PROJECT_ROOT / path
        if not (submodule_path / ".git").exists():
            raise click.ClickException(f"Submodule {path} is not initialized")

        expected = _get_submodule_expected_commit(path)
        actual = _get_submodule_actual_commit(path)
        if expected != actual:
            raise click.ClickException(
                f"Submodule {path} is at {actual[:12]}, expected {expected[:12]}"
            )

        _ensure_submodule_clean(path)


def _check_generated() -> None:
    """Regenerate code and verify tracked generated files are up to date."""
    runtime.execute([sys.executable, "x.py", "generate", "all"], "GENERATE ALL")

    tracked = [
        PROJECT_ROOT / "lib" / "constant" / "eve_dogma_unit_generated.dart",
        PROJECT_ROOT / "lib" / "storage" / "repo" / "repo_version.dart",
    ]
    for path in tracked:
        if not path.exists():
            raise click.ClickException(f"Tracked generated file missing: {path}")

    result = subprocess.run(
        ["git", "diff", "--exit-code", "--", *(str(path) for path in tracked)],
        capture_output=True,
        text=True,
        check=False,
        cwd=PROJECT_ROOT,
    )
    if result.returncode != 0:
        raise click.ClickException(
            "Tracked generated files are out of date; run `./x generate all` and commit the changes"
        )


def _check_tests() -> None:
    """Run Python and Flutter test suites."""
    from bootstrap.utils import get_command

    uv = get_command("uv")
    runtime.execute([uv, "run", "pytest", "bootstrap/tests/"], "PYTHON TESTS")

    flutter = get_command("flutter")
    runtime.execute([flutter, "test"], "FLUTTER TESTS")


def _check_build() -> None:
    """Run static buildability checks that do not require engine data."""
    from bootstrap.utils import get_command

    flutter = get_command("flutter")
    runtime.execute([flutter, "analyze"], "FLUTTER ANALYZE")


def _normalize_sha256(value: str) -> str:
    """Normalize a SHA-256 fingerprint for comparison (strip colons/spaces, lowercase)."""
    return value.replace(":", "").replace(" ", "").strip().lower()


def _parse_apksigner_digest(output: str) -> str:
    """Extract the first signer certificate SHA-256 digest from apksigner output."""
    match = _APKSIGNER_DIGEST_RE.search(output)
    if not match:
        raise click.ClickException("apksigner output has no certificate SHA-256 digest")
    return _normalize_sha256(match.group(1))


def _find_apksigner() -> Path:
    """Locate the newest apksigner under the Android SDK build-tools directories."""
    candidates: list[Path] = []
    for env_name in ("ANDROID_HOME", "ANDROID_SDK_ROOT"):
        root = os.environ.get(env_name)
        if root:
            candidates.extend(Path(root).glob("build-tools/*/apksigner"))
    if not candidates:
        raise click.ClickException(
            "apksigner not found: set ANDROID_HOME or ANDROID_SDK_ROOT to the Android SDK"
        )

    def sort_key(path: Path) -> tuple[int, ...]:
        return tuple(int(part) if part.isdigit() else 0 for part in path.parent.name.split("."))

    return sorted(candidates, key=sort_key)[-1]


def _verify_apk_signature(apksigner: Path, apk: Path, expected: str) -> None:
    """Verify one APK's signature and certificate digest against the expected value."""
    try:
        result = subprocess.run(
            [str(apksigner), "verify", "--print-certs", str(apk)],
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError as exc:
        raise click.ClickException(f"apksigner is not executable: {apksigner}") from exc
    if result.returncode != 0:
        raise click.ClickException(
            f"apksigner verification failed for {apk}:\n{result.stderr.strip()}"
        )
    digest = _parse_apksigner_digest(result.stdout)
    if digest != expected:
        raise click.ClickException(
            f"{apk}: certificate SHA-256 mismatch\n  expected: {expected}\n  actual:   {digest}"
        )
    click.echo(f"  {apk} OK (SHA-256: {digest})")


def _verify_signing(apk_dir: Path, expected_sha256: str | None) -> None:
    """Verify every APK under apk_dir is signed with the expected release key."""
    if not expected_sha256:
        raise click.ClickException(
            "Expected fingerprint missing: pass --expected-sha256 or set APP_KEY_SHA256"
        )
    expected = _normalize_sha256(expected_sha256)
    apks = sorted(apk_dir.rglob("*.apk"))
    if not apks:
        raise click.ClickException(f"No APKs found under {apk_dir}")
    apksigner = _find_apksigner()
    for apk in apks:
        _verify_apk_signature(apksigner, apk, expected)
    click.echo(f"Signature check OK: {len(apks)} APK(s) verified")


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
    @click.option(
        "--check-tag",
        is_flag=True,
        default=False,
        help="Verify that the expected release tag does not already exist.",
    )
    @click.option(
        "--check-note-content",
        is_flag=True,
        default=False,
        help="Validate the full content of the release note directory.",
    )
    @click.option(
        "--check-submodules",
        is_flag=True,
        default=False,
        help="Verify submodules are initialized at the expected commit and clean.",
    )
    @click.option(
        "--check-generated",
        is_flag=True,
        default=False,
        help="Regenerate code and verify tracked generated files are up to date.",
    )
    @click.option(
        "--check-build",
        is_flag=True,
        default=False,
        help="Run static buildability checks that do not require engine data.",
    )
    @click.option(
        "--check-tests",
        is_flag=True,
        default=False,
        help="Run Python and Flutter test suites.",
    )
    @click.option(
        "--check-all",
        is_flag=True,
        default=False,
        help="Enable all optional preflight checks.",
    )
    def release_verify(
        base_ref: str | None,
        check_notes: bool,
        check_tag: bool,
        check_note_content: bool,
        check_submodules: bool,
        check_generated: bool,
        check_build: bool,
        check_tests: bool,
        check_all: bool,
    ):
        """Verify that the current version is consistent and valid."""
        if check_all:
            check_notes = True
            check_tag = True
            check_note_content = True
            check_submodules = True
            check_generated = True
            check_build = True
            check_tests = True

        if check_generated or check_build:
            from bootstrap.utils import get_command

            flutter = get_command("flutter")
            runtime.execute([flutter, "pub", "get"], "FLUTTER PUB GET")
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

        if check_tag:
            _check_tag_does_not_exist(version)
            click.echo(f"  Tag check OK: {tag} does not exist")

        if check_notes:
            _check_notes(version)
            click.echo("  Changelog notes OK")

        if check_note_content:
            _check_note_content(version)
            click.echo("  Release note content OK")

        if check_submodules:
            _check_submodules()
            click.echo("  Submodule check OK")

        if check_generated:
            _check_generated()
            click.echo("  Generated code OK")

        if check_build:
            _check_build()
            click.echo("  Build check OK")

        if check_tests:
            _check_tests()
            click.echo("  Tests OK")

        click.echo(f"Expected tag: {tag}")

    @release_group.command("verify-signing")
    @click.option(
        "--apk-dir",
        type=click.Path(file_okay=False, path_type=Path),
        default=str(PROJECT_ROOT / "cache" / "releases" / "apk"),
        show_default=True,
        help="Directory containing built APKs (searched recursively).",
    )
    @click.option(
        "--expected-sha256",
        envvar="APP_KEY_SHA256",
        default=None,
        help="Expected release-key certificate SHA-256 fingerprint.",
    )
    def release_verify_signing(apk_dir: Path, expected_sha256: str | None):
        """Verify all built APKs are signed with the expected release key."""
        _verify_signing(apk_dir, expected_sha256)
