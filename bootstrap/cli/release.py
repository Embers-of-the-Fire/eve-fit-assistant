from __future__ import annotations

import subprocess

import click

from click_aliases import ClickAliasedGroup
from colorama import Fore
from colorama import Style

from bootstrap.color import styled
from bootstrap.constant import PROJECT_ROOT


def register_release_commands(cli_group: click.Group) -> None:
    @cli_group.group(aliases=["rel"], cls=ClickAliasedGroup)
    def release():
        """Pre-release workflow commands."""

    @release.group("version", cls=ClickAliasedGroup)
    def release_version():
        """Version management — show, sync, and bump the canonical version."""

    @release_version.command("show")
    def release_version_show():
        """Display the current version from efa.config.toml."""
        from bootstrap.release.version import load_version

        v = load_version()
        is_pre = v.is_prerelease()

        lines = [
            ("Canonical version", v.render_full()),
            ("  major", str(v.major)),
            ("  minor", str(v.minor)),
            ("  patch", str(v.patch)),
            ("  pre-release", f"{v.pre_label}.{v.pre_num}" if is_pre else "(none)"),
            ("  build", str(v.build)),
            ("", ""),
            ("Full string", v.render_full()),
            ("Semver only", v.render_semver()),
            ("Git tag", v.render_tag()),
        ]
        label_width = max(len(label) for label, _ in lines if label)
        for label, value in lines:
            if not label:
                click.echo("")
            else:
                click.echo(
                    styled([Style.BRIGHT, Fore.CYAN], label.ljust(label_width))
                    + "  "
                    + styled([Style.BRIGHT], value)
                )

    @release_version.command("sync")
    @click.option("--dry-run", is_flag=True, default=False, help="Show what would be written.")
    def release_version_sync(dry_run: bool):
        """Sync version from efa.config.toml to all target files."""
        from bootstrap.release.version import load_version
        from bootstrap.release.version import sync_all

        v = load_version()
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Syncing version ")
            + styled([Style.BRIGHT], v.render_full())
        )

        report = sync_all(v, dry_run=dry_run)
        for t in report.synced:
            click.echo(styled([Fore.GREEN], f"  {t.label:40s} -> {t.expected}"))
        for err in report.errors:
            click.echo(styled([Fore.RED], f"  ERROR: {err}"))

        if dry_run:
            click.echo(styled([Fore.YELLOW], "  (dry-run — no files were modified)"))

    @release_version.command("bump")
    @click.argument("level", type=click.Choice(["major", "minor", "patch"]), required=False)
    @click.option("--pre-label", default=None, help="Set pre-release label (e.g. 'beta', 'rc').")
    @click.option("--pre-num", type=int, default=None, help="Set pre-release number.")
    @click.option("--build", "build_num", type=int, default=None, help="Set build number.")
    @click.option(
        "--clear-pre", is_flag=True, default=False, help="Remove pre-release (promote to release)."
    )
    @click.option("--dry-run", is_flag=True, default=False, help="Show what would be done.")
    def release_version_bump(
        level: str | None,
        pre_label: str | None,
        pre_num: int | None,
        build_num: int | None,
        clear_pre: bool,
        dry_run: bool,
    ):
        """Bump the canonical version and sync all target files.

        LEVEL must be one of: major, minor, patch.

        \b
        Bump patch with pre-release:
            ./x release version bump patch --pre-label beta --pre-num 1

        \b
        Bump minor and clear pre-release (final release):
            ./x release version bump minor --clear-pre

        \b
        Only update pre-release number:
            ./x release version bump --pre-label beta --pre-num 5

        \b
        Only update build number:
            ./x release version bump --build 42
        """
        from bootstrap.release.version import load_version
        from bootstrap.release.version import sync_all
        from bootstrap.release.version import write_config_version

        v = load_version()
        old_ver = v.render_full()

        if level is not None:
            if level == "major":
                v.bump_major()
            elif level == "minor":
                v.bump_minor()
            elif level == "patch":
                v.bump_patch()

        if clear_pre:
            v.clear_prerelease()
        else:
            if pre_label is not None:
                v.pre_label = pre_label
                if v.pre_num == 0 and pre_num is None:
                    v.pre_num = 1
            if pre_num is not None:
                v.pre_num = pre_num
                if v.pre_num > 0 and not v.pre_label:
                    raise click.ClickException("pre_label is required when setting pre_num > 0")

        if build_num is not None:
            v.build = build_num

        new_ver = v.render_full()
        click.echo(
            styled([Style.BRIGHT, Fore.CYAN], "Bumping: ")
            + styled([Style.BRIGHT], f"{old_ver} -> {new_ver}")
        )

        if dry_run:
            click.echo(styled([Fore.YELLOW], "  (dry-run — no files were modified)"))
            return

        write_config_version(v, dry_run=False)
        click.echo(styled([Fore.GREEN], "  Updated efa.config.toml"))

        report = sync_all(v, dry_run=False)
        for t in report.synced:
            click.echo(styled([Fore.GREEN], f"  Synced {t.label} -> {t.expected}"))
        for err in report.errors:
            click.echo(styled([Fore.RED], f"  ERROR: {err}"))

    @release.command("check")
    @click.option(
        "--since",
        "since_tag",
        default=None,
        help="Compare against this tag instead of auto-detecting.",
    )
    @click.option(
        "--force", is_flag=True, default=False, help="Downgrade most fatal checks to warnings."
    )
    def release_check(since_tag: str | None, force: bool):
        """Run all pre-release checks.

        \b
        Runs 11 verification gates: version-sync, git-clean, git-tag,
        schema-diff, schema-bump, schema-version, persistence-check, submodule,
        generate, lint, and changelog.  Fatal failures block the
        release unless --force is used.
        """
        from bootstrap.release.check import CheckSeverity
        from bootstrap.release.check import run_all_checks

        report = run_all_checks(force=force, since_tag=since_tag)

        click.echo("")
        click.echo(styled([Style.BRIGHT], "=" * 60))
        click.echo(styled([Style.BRIGHT], "Pre-Release Check Report"))
        click.echo(styled([Style.BRIGHT], "=" * 60))
        click.echo("")

        width = max(len(r.name) for r in report.results) + 2

        for r in report.results:
            name_padded = r.name.ljust(width)
            if r.passed:
                click.echo(
                    styled([Fore.GREEN], f"  {r.icon} ")
                    + styled([Style.BRIGHT], name_padded)
                    + styled([Fore.GREEN], r.message)
                )
            elif r.severity == CheckSeverity.FATAL:
                click.echo(
                    styled([Fore.RED], f"  {r.icon} ")
                    + styled([Style.BRIGHT], name_padded)
                    + styled([Fore.RED], r.message)
                )
            elif r.severity == CheckSeverity.WARN:
                click.echo(
                    styled([Fore.YELLOW], f"  {r.icon} ")
                    + styled([Style.BRIGHT], name_padded)
                    + styled([Fore.YELLOW], r.message)
                )
            else:
                click.echo(
                    styled([Fore.CYAN], f"  {r.icon} ")
                    + styled([Style.BRIGHT], name_padded)
                    + styled([Fore.CYAN], r.message)
                )

            if r.details:
                for line in r.details.split("\n"):
                    click.echo(" " * (14 + width) + line)

        click.echo("")
        fatal = report.fatal_failures
        warns = report.warnings
        passed = len(report.results) - len(fatal) - len(warns)

        click.echo(
            styled([Style.BRIGHT], f"  {passed} passed, ")
            + styled([Fore.YELLOW, Style.BRIGHT], f"{len(warns)} warnings, ")
            + styled([Fore.RED, Style.BRIGHT], f"{len(fatal)} failures")
        )
        click.echo("")

        if report.has_fatal_failure:
            click.echo(styled([Fore.RED, Style.BRIGHT], "Release blocked by fatal check failures."))
            if not force:
                click.echo(
                    styled([Fore.YELLOW], "Re-run with --force to downgrade to warnings, ")
                    + "or fix the issues above."
                )
            exit(1)

        if warns:
            click.echo(
                styled(
                    [Fore.YELLOW, Style.BRIGHT],
                    f"Release would proceed with {len(warns)} warning(s).",
                )
            )
        else:
            click.echo(styled([Fore.GREEN, Style.BRIGHT], "All checks passed — ready to release!"))

    @release.command("commit")
    @click.option(
        "--no-edit",
        is_flag=True,
        default=False,
        help="Use the default message without opening an editor.",
    )
    @click.option(
        "--dry-run", is_flag=True, default=False, help="Print the commands without executing."
    )
    def release_commit(no_edit: bool, dry_run: bool):
        """Commit staged changes and create a git tag locally.

        \b
        Reads the version from efa.config.toml and:
          1. Commits staged changes with message "chore: release v{version}"
          2. Creates an annotated tag "v{version}"

        By default, both the commit and tag open $EDITOR for message review.
        Use --no-edit to accept the default messages without review.
        Use --dry-run to preview without executing.

        Does NOT push — you must push manually.
        """
        from bootstrap.release.git_util import check_tag_exists
        from bootstrap.release.version import load_version

        v = load_version()
        tag = v.render_tag()
        commit_msg = f"chore: release {tag}"

        if check_tag_exists(tag):
            raise click.ClickException(
                f"Tag {tag} already exists. Delete it first with `git tag -d {tag}` if you want to re-tag."
            )

        commit_cmd = ["git", "commit", "-m", commit_msg]
        if not no_edit:
            commit_cmd.append("--edit")
        commit_cmd.append("-s")

        tag_cmd = ["git", "tag", "-a", tag, "-m", f"Release {tag}"]
        if not no_edit:
            tag_cmd.append("--edit")

        if dry_run:
            click.echo(styled([Style.BRIGHT, Fore.CYAN], "[DRY-RUN] Would execute:"))
            click.echo(f"  {' '.join(commit_cmd)}")
            click.echo(f"  {' '.join(tag_cmd)}")
            return

        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Committing: ") + commit_msg)
        proc = subprocess.run(commit_cmd, cwd=PROJECT_ROOT)
        if proc.returncode != 0:
            raise click.ClickException(f"git commit failed with exit code {proc.returncode}")

        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Tagging: ") + tag)
        proc = subprocess.run(tag_cmd, cwd=PROJECT_ROOT)
        if proc.returncode != 0:
            raise click.ClickException(f"git tag failed with exit code {proc.returncode}")

        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Committed and tagged locally. ")
            + styled([Fore.YELLOW], "Push manually when ready."),
        )
        click.echo(f"  git push origin dev && git push origin {tag}")

    @release.group("changelog", cls=ClickAliasedGroup)
    def release_changelog():
        """Changelog generation — full file and per-version documents."""

    @release_changelog.command("generate")
    def release_changelog_generate():
        """Regenerate CHANGELOG.md using git-cliff.

        Prepends a new version entry for the current version from efa.config.toml.
        """
        from bootstrap.release.changelog_gen import generate_full
        from bootstrap.release.version import load_version

        v = load_version()
        tag = v.render_tag()
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Generating changelog for ")
            + styled([Style.BRIGHT], tag)
        )
        generate_full(v)
        click.echo(styled([Fore.GREEN], "  Prepended entry to CHANGELOG.md"))

    @release_changelog.command("detail")
    @click.option(
        "--no-edit",
        is_flag=True,
        default=False,
        help="Write template as-is without opening editor.",
    )
    def release_changelog_detail(no_edit: bool):
        """Generate bi-lingual version announcements for in-app release notes.

        By default, opens $EDITOR with a template containing en-us/zh-cn summary sections.
        Use --no-edit to write the generated template as-is without manual editing.
        On save (or if --no-edit), writes authored .md files to assets/content/announcements/{en,zh}/.
        """
        from bootstrap.release.changelog_gen import generate_detail
        from bootstrap.release.version import load_version

        v = load_version()
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Preparing version announcements for ")
            + styled([Style.BRIGHT], v.render_semver())
        )
        generate_detail(v, no_edit=no_edit)
        click.echo(styled([Fore.GREEN], "  Written to assets/content/announcements/"))
