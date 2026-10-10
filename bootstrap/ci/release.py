from __future__ import annotations

import json
import re
import subprocess
import sys
import tomllib

from dataclasses import dataclass
from pathlib import Path

import click

from bootstrap.cli import runtime
from bootstrap.config import ProjectVersion
from bootstrap.config import ReleaseVersion
from bootstrap.config import semver_precedence_key
from bootstrap.constant import EFA_APP_ROOT
from bootstrap.constant import PROJECT_ROOT
from bootstrap.remote.channel import Channel
from bootstrap.utils import get_command


_VERSION_RE = re.compile(r"^version\s*:\s*(.+?)\s*$", re.MULTILINE)
_APKSIGNER_DIGEST_RE = re.compile(r"certificate SHA-256 digest:\s*([0-9a-fA-F:]+)")


@dataclass(frozen=True)
class ReleaseIntent:
    """Parsed release intent of a ``[version]`` configuration diff (spec §5.1)."""

    action: str
    track: Channel | None
    version: ReleaseVersion | None
    reason: str


def _triplet_of(group) -> tuple[int, int, int]:
    return (group.major, group.minor, group.patch)


def classify_release_intent(
    base: ProjectVersion,
    head: ProjectVersion,
    *,
    backport_branch: bool = False,
) -> ReleaseIntent:
    """Classify the release intent of a parsed ``[version]`` diff (spec §5.1, R1-R6).

    ``base`` is the version configuration at the merge base (or the backport
    branch's base tag), ``head`` the configuration being merged. At most one
    release intent is permitted per merge; non-compliant diffs raise
    ``click.ClickException``.
    """
    testing_changed = base.testing != head.testing
    stable_changed = base.stable != head.stable

    if not testing_changed and not stable_changed:
        return ReleaseIntent("none", None, None, "R6: version groups unchanged")

    if backport_branch and testing_changed:
        raise click.ClickException(
            "R4 (backport, §6.4): a backport branch diff must not touch "
            "[version.testing]; only a [version.stable] patch increment is permitted."
        )

    if testing_changed and stable_changed:
        if head.testing.num > 0:
            raise click.ClickException(
                "R5: both [version.testing] and [version.stable] changed with testing "
                f"num = {head.testing.num} > 0; one release intent per merge."
            )
        if _triplet_of(head.stable) != _triplet_of(base.testing):
            raise click.ClickException(
                "R4 (I5): [version.stable] changed to "
                f"{head.stable.render_semver()}, which does not match the replaced "
                f"[version.testing] triplet {base.testing.major}.{base.testing.minor}."
                f"{base.testing.patch}; a ship commit must promote the tested line exactly."
            )
        return ReleaseIntent(
            "stable",
            Channel.STABLE,
            head.release(Channel.STABLE),
            "R3: ship commit (stable := testing triplet, testing rebased with num = 0)",
        )

    if testing_changed:
        if head.testing.num == 0:
            return ReleaseIntent(
                "none",
                None,
                None,
                "R2: testing group rebased with num = 0 (bare rebase, no release)",
            )
        head_semver = head.render_semver(Channel.TESTING)
        base_semver = base.render_semver(Channel.TESTING)
        if semver_precedence_key(head_semver) <= semver_precedence_key(base_semver):
            raise click.ClickException(
                f"Testing version did not increase: {head_semver} is not semver-greater "
                f"than base {base_semver}."
            )
        return ReleaseIntent(
            "testing",
            Channel.TESTING,
            head.release(Channel.TESTING),
            "R1: testing group changed, num > 0",
        )

    if not backport_branch:
        raise click.ClickException(
            "R4: [version.stable] changed on the mainline without a compliant ship "
            "rebase ([version.testing] must be rebased with num = 0 in the same commit); "
            "stable major.minor changes only via ship commits, stable patch changes "
            "only via backport branches."
        )
    if (head.stable.major, head.stable.minor) != (base.stable.major, base.stable.minor):
        raise click.ClickException(
            "R4 (backport, §6.4): stable major/minor must not change on a backport "
            "branch; only a patch increment of the current stable line is permitted."
        )
    if head.stable.patch <= base.stable.patch:
        raise click.ClickException(
            f"R4 (backport): stable patch must increase (base {base.stable.render_semver()}, "
            f"head {head.stable.render_semver()})."
        )
    return ReleaseIntent(
        "stable",
        Channel.STABLE,
        head.release(Channel.STABLE),
        "R4 (backport): stable patch increment with testing untouched",
    )


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


def _normalize_version_for_notes(version: ProjectVersion, track: Channel) -> str:
    return version.render_semver(track).replace(".", "-")


def _check_notes(version: ProjectVersion, track: Channel) -> None:
    normalized = _normalize_version_for_notes(version, track)
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


def _check_tag_does_not_exist(version: ProjectVersion, track: Channel) -> None:
    """Fail if the expected release tag already exists in the repository."""
    tag = version.render_tag(track)
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


def _check_note_content(version: ProjectVersion, track: Channel) -> None:
    """Validate the full content of the release note directory."""
    from bootstrap.docs.bundled_docs import _load_release_note
    from bootstrap.utils import normalize_version_dir

    dir_name = normalize_version_dir(version.render_semver(track))
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
    submodules = ["packages/eve-fit-os", "tools/eve-fsd-dumper"]
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
        PROJECT_ROOT / "packages" / "efa_constant" / "lib" / "eve_dogma_unit_generated.dart",
        EFA_APP_ROOT / "lib" / "storage" / "repo" / "repo_version.dart",
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

    runtime.run_melos("app:test", "FLUTTER TESTS")


def _check_build() -> None:
    """Run static buildability checks that do not require engine data."""
    runtime.run_melos("app:analyze", "FLUTTER ANALYZE")


def _normalize_sha256(value: str) -> str:
    """Normalize a SHA-256 fingerprint for comparison (strip colons/spaces, lowercase)."""
    return value.replace(":", "").replace(" ", "").strip().lower()


def _parse_apksigner_digest(output: str) -> str:
    """Extract the first signer certificate SHA-256 digest from apksigner output."""
    match = _APKSIGNER_DIGEST_RE.search(output)
    if not match:
        raise click.ClickException("apksigner output has no certificate SHA-256 digest")
    return _normalize_sha256(match.group(1))


def _find_apksigner() -> str:
    """Locate the apksigner executable on PATH."""
    try:
        return get_command("apksigner")
    except FileNotFoundError as exc:
        raise click.ClickException(
            "apksigner not found on PATH: run inside the Nix dev shell "
            "or install the Android SDK build-tools"
        ) from exc


def _verify_apk_signature(apksigner: str, apk: Path, expected: str) -> None:
    """Verify one APK's signature and certificate digest against the expected value."""
    output = runtime.execute(
        [apksigner, "verify", "--print-certs", str(apk)],
        "APKSIGNER VERIFY",
        capture_stdout=True,
    )
    digest = _parse_apksigner_digest(output)
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

    @release_group.command("intent")
    @click.option(
        "--base-ref",
        required=True,
        help="Git ref of the merge base to diff the [version] configuration against.",
    )
    @click.option(
        "--backport-branch",
        is_flag=True,
        default=False,
        help="Classify under backport-branch rules (§6.4) instead of mainline rules.",
    )
    def release_intent(base_ref: str, backport_branch: bool):
        """Classify the release intent of the merged [version] diff (spec §5.1)."""
        head = _load_version_from_config(PROJECT_ROOT / "efa.config.toml")
        base = _load_version_from_git_ref(base_ref)
        intent = classify_release_intent(base, head, backport_branch=backport_branch)

        if intent.action == "none":
            click.echo(f"Release intent: none ({intent.reason})")
            click.echo(json.dumps({"action": "none", "reason": intent.reason}))
            return

        assert intent.track is not None and intent.version is not None
        version = intent.version
        click.echo(f"Release intent: {intent.action} ({intent.reason})")
        click.echo(f"Canonical version: {version.full}")
        click.echo(f"Expected tag: {version.tag}")
        click.echo(
            json.dumps(
                {
                    "action": intent.action,
                    "track": intent.track.value,
                    "semver": version.semver,
                    "full": version.full,
                    "tag": version.tag,
                    "build": version.build,
                }
            )
        )

    @release_group.command("verify")
    @click.option(
        "--base-ref",
        default=None,
        help="Git ref to compare the current version against.",
    )
    @click.option(
        "--track",
        type=click.Choice(["testing", "stable"]),
        default="testing",
        show_default=True,
        help="Release track this run targets.",
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
    @click.option(
        "--allow-unpublishable",
        is_flag=True,
        default=False,
        help="Waive the publish-only gates (I3, changelog notes) for an unpublishable "
        "testing version (num = 0); for test-mode pipeline runs that never publish.",
    )
    def release_verify(
        base_ref: str | None,
        track: str,
        check_notes: bool,
        check_tag: bool,
        check_note_content: bool,
        check_submodules: bool,
        check_generated: bool,
        check_build: bool,
        check_tests: bool,
        check_all: bool,
        allow_unpublishable: bool,
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
        channel = Channel(track)
        config_path = PROJECT_ROOT / "efa.config.toml"
        version = _load_version_from_config(config_path)

        if not version.track_order_holds():
            raise click.ClickException(
                "I1 violated: testing version "
                f"{version.render_semver(Channel.TESTING)} must render strictly above "
                f"stable version {version.render_semver(Channel.STABLE)}."
            )

        unpublishable = channel == Channel.TESTING and version.testing.num == 0
        if unpublishable and not allow_unpublishable:
            raise click.ClickException(
                f"I3 violated: testing version {version.render_semver(Channel.TESTING)} "
                "has num = 0; a version rendered with num = 0 must not be published."
            )
        if unpublishable:
            click.echo(
                "  I3 waived (--allow-unpublishable): testing version "
                f"{version.render_semver(Channel.TESTING)} has num = 0 and must not be "
                "published; continuing because this run never publishes."
            )

        full = version.render_full(channel)
        semver = version.render_semver(channel)
        triplet = version.render_triplet(channel)
        tag = version.render_tag(channel)

        click.echo(f"Canonical version: {full}")
        click.echo(f"Semver version:    {semver}")
        click.echo(f"Publishable:       {str(not unpublishable).lower()}")

        derived = [
            (EFA_APP_ROOT / "pubspec.yaml", full, "full"),
            (EFA_APP_ROOT / "rust" / "Cargo.toml", triplet, "triplet"),
            (PROJECT_ROOT / "pyproject.toml", triplet, "triplet"),
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
            intent = classify_release_intent(base_version, version)
            click.echo(f"  Release intent: {intent.action} ({intent.reason})")
            if intent.action != "none":
                if version.build <= base_version.build:
                    raise click.ClickException(
                        "I2 violated: build must strictly increase between "
                        "release-triggering merges "
                        f"(base {base_version.build}, head {version.build})."
                    )
                if intent.track != channel:
                    raise click.ClickException(
                        f"Track mismatch: the [version] diff against {base_ref} implies "
                        f"a {intent.action} release, but this run targets the "
                        f"{channel.value} track (--track)."
                    )
                click.echo(
                    f"  Version check OK: {semver} "
                    f"(base {base_version.render_semver(channel)} from {base_ref})"
                )

        if check_tag:
            _check_tag_does_not_exist(version, channel)
            click.echo(f"  Tag check OK: {tag} does not exist")

        if check_notes:
            if unpublishable:
                click.echo("  Changelog notes skipped (unpublishable version)")
            else:
                _check_notes(version, channel)
                click.echo("  Changelog notes OK")

        if check_note_content:
            if unpublishable:
                click.echo("  Release note content skipped (unpublishable version)")
            else:
                _check_note_content(version, channel)
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
