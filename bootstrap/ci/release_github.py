from __future__ import annotations

import tempfile

from pathlib import Path

import click

from bootstrap.cli.runtime import execute
from bootstrap.constant import PROJECT_ROOT
from bootstrap.docs.document_parser import parse_locale_document


_GITHUB_REPO = "Embers-of-the-Fire/eve-fit-assistant"


def register_github_release_command(ci_group: click.Group) -> None:
    release_group = ci_group.commands.get("release")
    if release_group is None:
        raise click.ClickException(
            "ci release group not found; register_ci_release_commands must be called first"
        )

    @release_group.command("github-release")
    @click.option(
        "--version",
        "version_str",
        required=True,
        help="Full version (render_full()).",
    )
    @click.option(
        "--tag",
        required=True,
        help="Git tag (render_tag()).",
    )
    @click.option(
        "--apk-dir",
        type=click.Path(file_okay=False, path_type=Path),
        default=PROJECT_ROOT / "cache" / "releases" / "apk",
        show_default=True,
        help="Base directory containing versioned APK output directories.",
    )
    @click.option(
        "--linux-dir",
        type=click.Path(file_okay=False, path_type=Path),
        default=PROJECT_ROOT / "cache" / "releases" / "linux",
        show_default=True,
        help="Base directory containing versioned Linux (AppImage/zip) output "
        "directories (optional; attached only when present).",
    )
    @click.option(
        "--dry-run",
        is_flag=True,
        default=False,
        help="Show what would be done without creating the release.",
    )
    def github_release(
        version_str: str,
        tag: str,
        apk_dir: Path,
        linux_dir: Path,
        dry_run: bool,
    ) -> None:
        """Create a GitHub Release with APK assets and changelog body.

        Reads the human release body from content.en.md and the
        auto-generated changelog from changelog.md, composes them,
        then uploads the APK and SHA1 artifacts as release assets
        via gh release create. Linux artifacts (AppImage, zsync, and
        raw zip) are attached additionally when a matching versioned
        directory exists. The committed version banner image
        (docs/changelog/<version-dir>/image.png) is embedded at the
        top of the release body when present.
        """
        semver = version_str.split("+")[0]
        notes_dir_name = semver.replace(".", "-")
        notes_dir = PROJECT_ROOT / "docs" / "changelog" / notes_dir_name

        if not notes_dir.is_dir():
            raise click.ClickException(
                f"Changelog directory not found: {notes_dir}\n"
                f"Expected docs/changelog/{notes_dir_name}/"
            )

        content_path = notes_dir / "content.en.md"
        if not content_path.is_file():
            raise click.ClickException(f"Missing {content_path} — content.en.md is required")
        parsed = parse_locale_document(content_path, "en")
        human_body = parsed.body_markdown

        changelog_path = notes_dir / "changelog.md"
        if not changelog_path.is_file():
            raise click.ClickException(f"Missing {changelog_path} — changelog.md is required")
        changelog_body = changelog_path.read_text(encoding="utf-8")

        image_path = notes_dir / "image.png"
        if image_path.is_file():
            click.echo(f"Including version banner image: {image_path}")
        else:
            click.echo("No version banner image found; releasing without it")

        body_parts = []
        if image_path.is_file():
            image_url = (
                f"https://raw.githubusercontent.com/{_GITHUB_REPO}/{tag}"
                f"/docs/changelog/{notes_dir_name}/image.png"
            )
            body_parts.extend([f"![v{semver}]({image_url})", ""])
        body_parts.extend(
            [
                human_body.strip(),
                "",
                "## Full Changelog",
                "",
                changelog_body.strip(),
            ]
        )
        release_body = "\n".join(body_parts) + "\n"

        version_apk_dir = apk_dir / version_str
        if not version_apk_dir.is_dir():
            raise click.ClickException(f"APK directory not found: {version_apk_dir}")

        apk_files = sorted(version_apk_dir.glob("*.apk"))
        sha1_files = sorted(version_apk_dir.glob("*.sha1"))

        if not apk_files:
            raise click.ClickException(f"No APK files found in {version_apk_dir}")

        linux_files: list[Path] = []
        version_linux_dir = linux_dir / version_str
        if version_linux_dir.is_dir():
            linux_files = (
                sorted(version_linux_dir.glob("*.AppImage"))
                + sorted(version_linux_dir.glob("*.AppImage.zsync"))
                + sorted(version_linux_dir.glob("*.zip"))
            )
        if linux_files:
            click.echo(f"Including {len(linux_files)} Linux asset(s)")
        else:
            click.echo("No Linux artifacts found; releasing Android assets only")

        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            suffix=".md",
            prefix=f"github_release_{tag.replace('/', '_')}_",
            delete=False,
        ) as f:
            body_path = Path(f.name)
            f.write(release_body)

        is_prerelease = "-" in semver

        cmd = ["gh", "release", "create", tag]
        cmd.extend(["--title", f"v{semver}"])
        if is_prerelease:
            cmd.append("--prerelease")
        cmd.extend(["--notes-file", str(body_path)])
        cmd.extend(str(f) for f in apk_files)
        cmd.extend(str(f) for f in sha1_files)
        cmd.extend(str(f) for f in linux_files)

        if dry_run:
            click.echo(f"[DRY-RUN] Would run: {' '.join(cmd)}")
            body_path.unlink()
            return

        try:
            execute(cmd, "GITHUB RELEASE CREATE")
        finally:
            body_path.unlink(missing_ok=True)

        click.echo(f"GitHub Release created: {tag}")
