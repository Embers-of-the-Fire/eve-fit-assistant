from __future__ import annotations

import datetime as dt
import json
import sys

from pathlib import Path

import click

from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.cli.remote.helpers import get_announce_workspace
from bootstrap.cli.remote.helpers import resolve_announce_remote_target
from bootstrap.color import styled
from bootstrap.config import ProjectVersion
from bootstrap.docs.announcements_remote import ACTIVE_KEY
from bootstrap.docs.announcements_remote import DOCUMENT_ID_PATTERN
from bootstrap.docs.announcements_remote import AnnouncementEntry
from bootstrap.docs.announcements_remote import AnnouncementLocalization
from bootstrap.docs.announcements_remote import AnnouncementRemoteSync
from bootstrap.docs.announcements_remote import AnnouncementWorkspace
from bootstrap.docs.announcements_remote import run_preflight_validation
from bootstrap.docs.document_parser import parse_locale_document
from bootstrap.release.relnote import CHANGELOG_ROOT
from bootstrap.release.relnote import normalize_version_dir
from bootstrap.release.relnote import parse_version_override
from bootstrap.release.relnote import split_csv
from bootstrap.release.relnote import version_dir_to_entry_id


def _load_spec_or_defaults(directory: Path) -> dict[str, object]:
    spec_path = directory / "spec.yaml"
    if not spec_path.exists():
        return {}
    import yaml

    raw = yaml.safe_load(spec_path.read_text(encoding="utf-8"))
    if raw is None:
        return {}
    if not isinstance(raw, dict):
        raise click.ClickException(f"Spec file must be a YAML mapping: {spec_path}")
    return raw


def _compose_release_body(human_body: str, changelog: str) -> str:
    human_body = human_body.strip()
    changelog = changelog.strip()
    parts = [human_body, "---", "", changelog]
    return "\n".join(parts).strip() + "\n"


def register_remote_announce(remote: click.Group) -> None:
    @remote.group("announce")
    def remote_announce():
        """Remote announcement management — sync, author, publish."""

    @remote_announce.command("sync")
    @click.option(
        "--target",
        type=click.Choice(["minio", "s3"]),
        default=None,
        help="Remote target (default: minio).",
    )
    @click.option("--endpoint", default=None, help="Override endpoint URL.")
    @click.option("--bucket", default=None, help="Override bucket name.")
    @click.option("--access-key", default=None, help="Override access key.")
    @click.option("--secret-key", default=None, help="Override secret key.")
    @click.option("--alias", default=None, help="Override MinIO/S3 alias name.")
    @click.option("--full", is_flag=True, default=False, help="Download all document bodies.")
    def remote_announce_sync(
        target: str | None,
        endpoint: str | None,
        bucket: str | None,
        access_key: str | None,
        secret_key: str | None,
        alias: str | None,
        full: bool,
    ):
        """Download current server state to remote/ workspace."""
        from bootstrap.docs.announcements_remote import AnnouncementWorkspace

        endpoint, bucket, access_key, secret_key, alias = resolve_announce_remote_target(
            target, endpoint, bucket, access_key, secret_key, alias
        )

        workspace_root = get_announce_workspace()
        workspace = AnnouncementWorkspace(workspace_root)
        sync = AnnouncementRemoteSync(
            workspace=workspace,
            target=target or "minio",
            endpoint=endpoint,
            bucket=bucket,
            access_key=access_key,
            secret_key=secret_key,
            alias_name=alias,
            resource_root=bootstrap.config.CONFIGURATION.data_schema.resource_root,
        )

        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Syncing announcements from remote..."))
        try:
            sync.sync(full=full)
        except RuntimeError as e:
            click.echo(styled([Fore.RED], f"Error: {e}"))
            sys.exit(2)
        click.echo(styled([Fore.GREEN], "  Downloaded catalog and pages"))
        if full:
            click.echo(styled([Fore.GREEN], "  Downloaded all document bodies"))
        click.echo(styled([Fore.GREEN], f"  Remote state saved to: {workspace.remote_dir}"))

    @remote_announce.command("init")
    @click.option(
        "--target",
        type=click.Choice(["minio", "s3"]),
        default=None,
        help="Remote target (default: minio).",
    )
    @click.option("--endpoint", default=None, help="Override endpoint URL.")
    @click.option("--bucket", default=None, help="Override bucket name.")
    @click.option("--access-key", default=None, help="Override access key.")
    @click.option("--secret-key", default=None, help="Override secret key.")
    @click.option("--alias", default=None, help="Override MinIO/S3 alias name.")
    @click.option(
        "--force", is_flag=True, default=False, help="Overwrite if remote already has a catalog."
    )
    def remote_announce_init(
        target: str | None,
        endpoint: str | None,
        bucket: str | None,
        access_key: str | None,
        secret_key: str | None,
        alias: str | None,
        force: bool,
    ):
        """Initialize a new empty announcement workspace on the remote.

        Creates catalog.json and active.json with one empty active page,
        then uploads them.  Fails if the remote already has content unless
        --force is given.
        """
        from bootstrap.docs.announcements_remote import AnnouncementWorkspace

        endpoint, bucket, access_key, secret_key, alias = resolve_announce_remote_target(
            target, endpoint, bucket, access_key, secret_key, alias
        )

        workspace_root = get_announce_workspace()
        workspace = AnnouncementWorkspace(workspace_root)
        sync = AnnouncementRemoteSync(
            workspace=workspace,
            target=target or "minio",
            endpoint=endpoint,
            bucket=bucket,
            access_key=access_key,
            secret_key=secret_key,
            alias_name=alias,
            resource_root=bootstrap.config.CONFIGURATION.data_schema.resource_root,
        )

        action = "Initializing" if not force else "Force-initializing"
        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"{action} remote announcements..."))
        try:
            sync.init_remote(force=force)
        except RuntimeError as e:
            click.echo(styled([Fore.RED], f"Error: {e}"))
            sys.exit(2)
        click.echo(styled([Fore.GREEN], "  Created catalog.json and active.json"))
        click.echo(styled([Fore.GREEN], "  Uploaded to remote"))
        click.echo(styled([Fore.GREEN], f"  Local mirror at: {workspace.remote_dir}"))

    @remote_announce.command("add")
    @click.option(
        "--id", "entry_id", required=True, help="Entry ID (matches [a-z0-9][a-z0-9._-]*)."
    )
    @click.option("--zh-title", required=True, help="Chinese title.")
    @click.option("--zh-summary", required=True, help="Chinese summary.")
    @click.option("--zh-body", default=None, help="Chinese body text.")
    @click.option(
        "--zh-body-file",
        type=click.Path(exists=True, file_okay=True, dir_okay=False, readable=True, path_type=Path),
        default=None,
        help="Chinese body file.",
    )
    @click.option("--en-title", required=True, help="English title.")
    @click.option("--en-summary", required=True, help="English summary.")
    @click.option("--en-body", default=None, help="English body text.")
    @click.option(
        "--en-body-file",
        type=click.Path(exists=True, file_okay=True, dir_okay=False, readable=True, path_type=Path),
        default=None,
        help="English body file.",
    )
    @click.option("--published-at", default=None, help="ISO-8601 timestamp (default: now).")
    @click.option("--tags", default="", help="Comma-separated tags.")
    @click.option("--startup", is_flag=True, default=False, help="Show on startup.")
    @click.option("--channels", default="", help="Comma-separated channels.")
    @click.option("--platforms", default="", help="Comma-separated platforms.")
    @click.option("--min-app-version", default=None, help="Minimum app version (semver).")
    @click.option("--max-app-version", default=None, help="Maximum app version (semver).")
    @click.option("--app-version", default=None, help="App version for version announcement.")
    def remote_announce_add(
        entry_id: str,
        zh_title: str,
        zh_summary: str,
        zh_body: str | None,
        zh_body_file: Path | None,
        en_title: str,
        en_summary: str,
        en_body: str | None,
        en_body_file: Path | None,
        published_at: str | None,
        tags: str,
        startup: bool,
        channels: str,
        platforms: str,
        min_app_version: str | None,
        max_app_version: str | None,
        app_version: str | None,
    ):
        """Add a new announcement entry to the staging overlay (active page)."""
        import re as _re

        from bootstrap.docs.announcements_remote import ACTIVE_KEY
        from bootstrap.docs.announcements_remote import AnnouncementEntry
        from bootstrap.docs.announcements_remote import AnnouncementLocalization
        from bootstrap.docs.announcements_remote import AnnouncementWorkspace

        if not _re.match(DOCUMENT_ID_PATTERN, entry_id):
            raise click.ClickException(
                f"Invalid entry ID: {entry_id!r} (must match {DOCUMENT_ID_PATTERN})"
            )

        if zh_body and zh_body_file:
            raise click.ClickException("Cannot specify both --zh-body and --zh-body-file")
        if en_body and en_body_file:
            raise click.ClickException("Cannot specify both --en-body and --en-body-file")

        workspace_root = get_announce_workspace()
        workspace = AnnouncementWorkspace(workspace_root)
        workspace.ensure_remote_directories()

        effective_ids = workspace.get_effective_entry_ids(ACTIVE_KEY)
        if entry_id in effective_ids:
            raise click.ClickException(f"Entry {entry_id!r} already exists. Use 'edit' instead.")

        zh_body_text = (
            zh_body
            if zh_body
            else (zh_body_file.read_text(encoding="utf-8") if zh_body_file else "")
        )
        en_body_text = (
            en_body
            if en_body
            else (en_body_file.read_text(encoding="utf-8") if en_body_file else "")
        )

        if not zh_body_text:
            raise click.ClickException(
                "Chinese body is required (provide --zh-body or --zh-body-file)"
            )
        if not en_body_text:
            raise click.ClickException(
                "English body is required (provide --en-body or --en-body-file)"
            )

        zh_hash = workspace.store_document(zh_body_text)
        en_hash = workspace.store_document(en_body_text)

        if published_at is None:
            from datetime import UTC
            from datetime import datetime as _datetime

            published_at = _datetime.now(UTC).isoformat().replace("+00:00", "Z")

        tags_list = [t.strip() for t in tags.split(",") if t.strip()]
        channels_list = [c.strip() for c in channels.split(",") if c.strip()]
        platforms_list = [p.strip() for p in platforms.split(",") if p.strip()]

        if not channels_list:
            bootstrap.config.DeveloperConfiguration.ensure_loaded()
            channels_list = [bootstrap.config.DEV_CONFIGURATION.remote.channel.value]

        new_entry = AnnouncementEntry(
            id=entry_id,
            published_at=published_at,
            tags=tags_list,
            startup=startup,
            min_app_version=min_app_version,
            max_app_version=max_app_version,
            channels=channels_list,
            platforms=platforms_list,
            app_version=app_version,
            localizations={
                "zh": AnnouncementLocalization(
                    title=zh_title, summary=zh_summary, body_hash=zh_hash
                ),
                "en": AnnouncementLocalization(
                    title=en_title, summary=en_summary, body_hash=en_hash
                ),
            },
        )

        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, new_entry)
        workspace.write_overlay(overlay)

        remote_active_uuid = workspace.get_remote_active_uuid() or "(no remote)"
        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Added announcement entry: {entry_id}"))
        click.echo(styled([Fore.GREEN], f"  page:  {remote_active_uuid}"))
        click.echo(styled([Fore.GREEN], f"  zh title: {zh_title}"))
        click.echo(styled([Fore.GREEN], f"  en title: {en_title}"))

    @remote_announce.command("edit")
    @click.option("--id", "entry_id", required=True, help="Entry ID to edit.")
    @click.option(
        "--page",
        "page_uuid",
        default=None,
        help="Target page UUID (default: active page). Use to edit archived entries.",
    )
    @click.option("--zh-title", default=None, help="Chinese title.")
    @click.option("--zh-summary", default=None, help="Chinese summary.")
    @click.option("--zh-body", default=None, help="Chinese body text.")
    @click.option(
        "--zh-body-file",
        type=click.Path(exists=True, file_okay=True, dir_okay=False, readable=True, path_type=Path),
        default=None,
        help="Chinese body file.",
    )
    @click.option("--en-title", default=None, help="English title.")
    @click.option("--en-summary", default=None, help="English summary.")
    @click.option("--en-body", default=None, help="English body text.")
    @click.option(
        "--en-body-file",
        type=click.Path(exists=True, file_okay=True, dir_okay=False, readable=True, path_type=Path),
        default=None,
        help="English body file.",
    )
    @click.option("--published-at", default=None, help="ISO-8601 timestamp.")
    @click.option("--tags", default=None, help="Comma-separated tags.")
    @click.option("--startup/--no-startup", default=None, help="Show on startup.")
    @click.option("--channels", default=None, help="Comma-separated channels.")
    @click.option("--platforms", default=None, help="Comma-separated platforms.")
    @click.option("--min-app-version", default=None, help="Minimum app version (semver).")
    @click.option("--max-app-version", default=None, help="Maximum app version (semver).")
    @click.option("--app-version", default=None, help="App version for version announcement.")
    def remote_announce_edit(
        entry_id: str,
        page_uuid: str | None,
        zh_title: str | None,
        zh_summary: str | None,
        zh_body: str | None,
        zh_body_file: Path | None,
        en_title: str | None,
        en_summary: str | None,
        en_body: str | None,
        en_body_file: Path | None,
        published_at: str | None,
        tags: str | None,
        startup: bool | None,
        channels: str | None,
        platforms: str | None,
        min_app_version: str | None,
        max_app_version: str | None,
        app_version: str | None,
    ):
        """Edit an existing announcement entry in the staging overlay.

        Targets the active page by default.  Use --page UUID to edit an
        archived entry.
        """
        from bootstrap.docs.announcements_remote import ACTIVE_KEY
        from bootstrap.docs.announcements_remote import AnnouncementPlatform
        from bootstrap.docs.announcements_remote import AnnouncementWorkspace

        if all(
            v is None
            for v in [
                zh_title,
                zh_summary,
                zh_body,
                zh_body_file,
                en_title,
                en_summary,
                en_body,
                en_body_file,
                published_at,
                tags,
                startup,
                channels,
                platforms,
                min_app_version,
                max_app_version,
                app_version,
            ]
        ):
            raise click.ClickException("No changes specified (provide at least one flag)")

        workspace_root = get_announce_workspace()
        workspace = AnnouncementWorkspace(workspace_root)
        workspace.ensure_remote_directories()

        if zh_body and zh_body_file:
            raise click.ClickException("Cannot specify both --zh-body and --zh-body-file")
        if en_body and en_body_file:
            raise click.ClickException("Cannot specify both --en-body and --en-body-file")

        page_key = page_uuid if page_uuid else ACTIVE_KEY

        overlay = workspace.read_overlay()
        page_overlay = overlay.pages.get(page_key, {})
        if entry_id in page_overlay and page_overlay[entry_id] is not None:
            entry_to_edit = page_overlay[entry_id]
        elif page_key == ACTIVE_KEY:
            try:
                remote_page = workspace.get_remote_page()
            except FileNotFoundError:
                raise click.ClickException(
                    "No remote state. Run 'sync' first or use 'add' to create entries."
                ) from None
            entry_to_edit = next((e for e in remote_page.entries if e.id == entry_id), None)
        else:
            try:
                remote_page = workspace._read_page(workspace.remote_dir, page_key)
            except FileNotFoundError:
                raise click.ClickException(f"Page {page_key!r} not found on remote.") from None
            entry_to_edit = next((e for e in remote_page.entries if e.id == entry_id), None)

        if entry_to_edit is None:
            raise click.ClickException(f"Entry {entry_id!r} not found. Use 'add' first.")

        if zh_body:
            zh_hash = workspace.store_document(zh_body)
            entry_to_edit.localizations["zh"].body_hash = zh_hash
        elif zh_body_file:
            zh_body_text = zh_body_file.read_text(encoding="utf-8")
            zh_hash = workspace.store_document(zh_body_text)
            entry_to_edit.localizations["zh"].body_hash = zh_hash

        if en_body:
            en_hash = workspace.store_document(en_body)
            entry_to_edit.localizations["en"].body_hash = en_hash
        elif en_body_file:
            en_body_text = en_body_file.read_text(encoding="utf-8")
            en_hash = workspace.store_document(en_body_text)
            entry_to_edit.localizations["en"].body_hash = en_hash

        if zh_title:
            entry_to_edit.localizations["zh"].title = zh_title
        if zh_summary:
            entry_to_edit.localizations["zh"].summary = zh_summary
        if en_title:
            entry_to_edit.localizations["en"].title = en_title
        if en_summary:
            entry_to_edit.localizations["en"].summary = en_summary
        if published_at:
            entry_to_edit.published_at = published_at
        if tags is not None:
            entry_to_edit.tags = [t.strip() for t in tags.split(",") if t.strip()]
        if startup is not None:
            entry_to_edit.startup = startup
        if channels is not None:
            entry_to_edit.channels = [c.strip() for c in channels.split(",") if c.strip()]
        if platforms is not None:
            entry_to_edit.platforms = [
                AnnouncementPlatform(p.strip()) for p in platforms.split(",") if p.strip()
            ]
        if min_app_version is not None:
            entry_to_edit.min_app_version = min_app_version
        if max_app_version is not None:
            entry_to_edit.max_app_version = max_app_version
        if app_version is not None:
            entry_to_edit.app_version = app_version

        overlay = workspace.overlay_upsert_entry(page_key, entry_to_edit)
        workspace.write_overlay(overlay)

        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Edited announcement entry: {entry_id}"))

    @remote_announce.command("remove")
    @click.option("--id", "entry_id", required=True, help="Entry ID to remove.")
    def remote_announce_remove(entry_id: str):
        """Remove an announcement entry from the staging overlay (active page only)."""
        from bootstrap.docs.announcements_remote import ACTIVE_KEY
        from bootstrap.docs.announcements_remote import AnnouncementWorkspace

        workspace_root = get_announce_workspace()
        workspace = AnnouncementWorkspace(workspace_root)

        effective_ids = workspace.get_effective_entry_ids(ACTIVE_KEY)
        if entry_id not in effective_ids:
            raise click.ClickException(f"Entry {entry_id!r} not found in active page.")

        overlay = workspace.overlay_remove_entry(entry_id)
        workspace.write_overlay(overlay)

        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Removed announcement entry: {entry_id}"))

    @remote_announce.command("status")
    @click.option(
        "--json", "as_json", is_flag=True, default=False, help="Output as machine-readable JSON."
    )
    def remote_announce_status(as_json: bool):
        """Show effective diff between remote and pending overlay changes.

        Constructs the effective workspace in a temp directory by applying the
        staging overlay to remote, then diffs against remote.
        """
        import tempfile

        from bootstrap.docs.announcements_remote import AnnouncementWorkspace
        from bootstrap.docs.announcements_remote import compute_status_diff

        workspace_root = get_announce_workspace()
        workspace = AnnouncementWorkspace(workspace_root)

        if not (workspace.remote_dir / "catalog.json").exists():
            click.echo(styled([Fore.YELLOW], "No remote state — run 'sync' first."))
            sys.exit(1)

        overlay = workspace.read_overlay()
        has_changes = any(v for v in overlay.pages.values())
        if not has_changes:
            click.echo(styled([Fore.GREEN], "No pending changes — overlay is empty."))
            sys.exit(0)

        temp_dir = Path(tempfile.mkdtemp(prefix="efa-anno-status-"))
        try:
            workspace.build_publish_workspace(temp_dir)
            diff = compute_status_diff(workspace.remote_dir, temp_dir)

            if as_json:
                click.echo(json.dumps(diff, indent=2))
                return

            summary = diff["summary"]
            if summary["added"] == 0 and summary["removed"] == 0 and summary["modified"] == 0:
                click.echo(styled([Fore.GREEN], "No differences — staging is clean."))
                sys.exit(0)

            pages = diff.get("pages", {})
            for page_uuid, page_diff in pages.items():
                if (
                    page_diff["summary"]["added"] == 0
                    and page_diff["summary"]["removed"] == 0
                    and page_diff["summary"]["modified"] == 0
                ):
                    continue

                click.echo(styled([Style.BRIGHT], f"Page {page_uuid[:8]}… REMOTE → EFFECTIVE"))
                click.echo()

                for item in page_diff["added"]:
                    click.echo(
                        styled([Fore.GREEN], "  +  added     ")
                        + styled([Style.BRIGHT], f"{item['id']:20}")
                        + styled(Fore.CYAN, f'zh:"{item["zhTitle"]}"  ')
                        + styled(Fore.CYAN, f'en:"{item["enTitle"]}"')
                    )

                for item in page_diff["modified"]:
                    change_desc = ", ".join(
                        f"{k}: {v['from']} → {v['to']}" for k, v in item["changes"].items()
                    )
                    click.echo(
                        styled([Fore.YELLOW], "  ~  modified  ")
                        + styled([Style.BRIGHT], f"{item['id']:20}")
                        + styled(Fore.CYAN, f'zh:"{item["zhTitle"]}"  ')
                        + styled(Fore.CYAN, f'en:"{item["enTitle"]}"')
                        + styled(Style.DIM, f"  ({change_desc})")
                    )

                for item in page_diff["removed"]:
                    click.echo(
                        styled([Fore.RED], "  -  removed   ")
                        + styled([Style.BRIGHT], f"{item['id']:20}")
                        + styled(Fore.CYAN, f'zh:"{item["zhTitle"]}"  ')
                        + styled(Fore.CYAN, f'en:"{item["enTitle"]}"')
                    )

                click.echo()

            click.echo(
                styled([Style.BRIGHT], "Summary: ")
                + styled([Fore.GREEN], f"{summary['added']} added, ")
                + styled([Fore.RED], f"{summary['removed']} removed, ")
                + styled([Fore.YELLOW], f"{summary['modified']} modified")
            )
            click.echo(
                styled(
                    Style.DIM,
                    f"  Remote: {summary['totalRemote']} entries, "
                    f"Effective: {summary['totalStaging']} entries",
                )
            )
            sys.exit(1)
        finally:
            import shutil as _shutil

            _shutil.rmtree(temp_dir, ignore_errors=True)

    @remote_announce.command("publish")
    @click.option(
        "--target",
        type=click.Choice(["minio", "s3"]),
        default=None,
        help="Remote target (default: minio).",
    )
    @click.option("--endpoint", default=None, help="Override endpoint URL.")
    @click.option("--bucket", default=None, help="Override bucket name.")
    @click.option("--access-key", default=None, help="Override access key.")
    @click.option("--secret-key", default=None, help="Override secret key.")
    @click.option("--alias", default=None, help="Override MinIO/S3 alias name.")
    @click.option(
        "--dry-run",
        is_flag=True,
        default=False,
        help="Print files to upload without uploading.",
    )
    @click.option(
        "--force",
        is_flag=True,
        default=False,
        help="Skip sync and preflight, publish overlay directly.",
    )
    @click.option(
        "--no-check-remote",
        is_flag=True,
        default=False,
        help="Skip remote compatibility check during preflight.",
    )
    def remote_announce_publish(
        target: str | None,
        endpoint: str | None,
        bucket: str | None,
        access_key: str | None,
        secret_key: str | None,
        alias: str | None,
        dry_run: bool,
        force: bool,
        no_check_remote: bool,
    ):
        """Publish staging overlay to remote storage.

        Syncs latest remote, constructs the full workspace in a temp directory
        (applying the overlay + handling rotation), validates, then uploads.
        On success, the overlay is cleared and the local remote mirror is updated.

        Use --force to skip sync and preflight (publish overlay directly).
        """
        import tempfile

        from bootstrap.docs.announcements_remote import AnnouncementWorkspace

        endpoint, bucket, access_key, secret_key, alias = resolve_announce_remote_target(
            target, endpoint, bucket, access_key, secret_key, alias
        )

        workspace_root = get_announce_workspace()
        workspace = AnnouncementWorkspace(workspace_root)

        overlay = workspace.read_overlay()
        has_changes = any(v for v in overlay.pages.values())
        if not has_changes:
            raise click.ClickException("No pending changes — overlay is empty. Run 'add' first.")

        sync = AnnouncementRemoteSync(
            workspace=workspace,
            target=target or "minio",
            endpoint=endpoint,
            bucket=bucket,
            access_key=access_key,
            secret_key=secret_key,
            alias_name=alias,
            resource_root=bootstrap.config.CONFIGURATION.data_schema.resource_root,
        )

        if not force:
            try:
                click.echo(styled([Style.BRIGHT, Fore.CYAN], "Syncing latest remote state..."))
                sync.sync(full=False)
                click.echo(styled([Fore.GREEN], "  Remote state synced"))
            except Exception as e:  # noqa: BLE001
                click.echo(styled([Fore.RED], f"  Sync failed: {e}"))
                sys.exit(1)

            old_active = None
            for page_key in overlay.pages:
                if (
                    page_key != "active"
                    and not (workspace.remote_dir / "pages" / f"{page_key}.json").exists()
                ):
                    old_active = page_key
                    break
            if old_active:
                click.echo(
                    styled(
                        [Fore.YELLOW],
                        "  Remote active page changed (rotation by others). "
                        "Re-applying overlay on new base.",
                    )
                )

        temp_dir = Path(tempfile.mkdtemp(prefix="efa-anno-publish-"))
        try:
            click.echo(styled([Style.BRIGHT, Fore.CYAN], "Building publish workspace..."))
            workspace.build_publish_workspace(temp_dir)

            temp_catalog = workspace._read_catalog(temp_dir)
            total_entries = sum(p.count for p in temp_catalog.pages)
            body_hashes: set[str] = set()
            for page_meta in temp_catalog.pages:
                p = workspace._read_any_page(temp_dir, page_meta.uuid)
                for entry in p.entries:
                    for loc in entry.localizations.values():
                        body_hashes.add(loc.body_hash)

            if not force:
                click.echo(styled([Style.BRIGHT, Fore.GREEN], "Running preflight validation..."))
                errors = run_preflight_validation(
                    workspace_dir=temp_dir,
                    documents_dir=workspace.documents_dir,
                    remote_dir=workspace.remote_dir if not no_check_remote else None,
                    check_remote=not no_check_remote,
                )
                if errors:
                    click.echo(styled([Fore.RED], "Preflight validation failed:"))
                    for error in errors:
                        click.echo(styled([Fore.RED], f"  - {error}"))
                    sys.exit(1)
                click.echo(styled([Fore.GREEN], "  Preflight validation passed"))

            if dry_run:
                click.echo(styled([Style.BRIGHT, Fore.CYAN], "[DRY-RUN] Would publish:"))
                click.echo(f"  Pages: {len(temp_catalog.pages)}")
                click.echo(f"  Entries: {total_entries}")
                click.echo(f"  Documents: {len(body_hashes)}")
                click.echo(f"  Target: {target or 'minio'}")
                sync.publish_dir(temp_dir, dry_run=True)
                return

            click.echo(styled([Style.BRIGHT, Fore.GREEN], "Publishing announcements..."))
            sync.publish_dir(temp_dir, dry_run=False)

            workspace.clear_overlay()
            import shutil as _shutil2

            if workspace.remote_dir.exists():
                _shutil2.rmtree(workspace.remote_dir)
            _shutil2.copytree(temp_dir, workspace.remote_dir)

            click.echo(
                styled(
                    [Fore.GREEN],
                    f"  Published {total_entries} entries in {len(temp_catalog.pages)} "
                    f"page(s) with {len(body_hashes)} document bodies.",
                )
            )
            click.echo(styled([Fore.GREEN], "  Overlay cleared."))
        finally:
            import shutil as _shutil3

            _shutil3.rmtree(temp_dir, ignore_errors=True)

    @remote_announce.command("add-release-note")
    @click.option(
        "--version",
        "version_override",
        default=None,
        help="Override the app version (semver, e.g. 0.1.0-beta.7).",
    )
    @click.option(
        "--directory",
        type=click.Path(exists=True, file_okay=False, dir_okay=True, readable=True, path_type=Path),
        default=None,
        help="Release note source directory (default: docs/changelog/<version-dashed>).",
    )
    @click.option(
        "--channels",
        default=None,
        help="Comma-separated channel list (default: from spec.yaml or testing).",
    )
    @click.option(
        "--platforms",
        default=None,
        help="Comma-separated platform list (default: from spec.yaml, or all platforms if unset).",
    )
    @click.option(
        "--published-at",
        default=None,
        help="Override publishedAt timestamp (ISO-8601, default: from spec.yaml or now).",
    )
    @click.option(
        "--tags",
        default=None,
        help="Comma-separated tags (default: release-note).",
    )
    def remote_announce_add_release_note(
        version_override: str | None,
        directory: Path | None,
        channels: str | None,
        platforms: str | None,
        published_at: str | None,
        tags: str | None,
    ):
        """Stage a docs/changelog release note as a remote announcement entry.

        Reads spec.yaml, changelog.md, content.zh.md, and content.en.md from the
        release note directory, composes localized bodies, and adds an entry to
        the active page overlay.  The entry is published with
        ``remote announce publish``.
        """
        if version_override is not None:
            version = ProjectVersion.model_validate(parse_version_override(version_override))
        else:
            bootstrap.config.ProjectConfiguration.ensure_loaded()
            version = bootstrap.config.CONFIGURATION.version

        app_version = version.render_semver()
        dir_name = normalize_version_dir(app_version)
        entry_id = version_dir_to_entry_id(app_version)

        if directory is None:
            directory = CHANGELOG_ROOT / dir_name

        if not directory.exists():
            raise click.ClickException(
                f"Release note directory does not exist: {directory}. "
                "Run './x release relnote' first or use --directory."
            )

        spec = _load_spec_or_defaults(directory)

        spec_id = spec.get("id")
        if spec_id is not None and spec_id != entry_id:
            raise click.ClickException(
                f"Spec id {spec_id!r} does not match expected id {entry_id!r}"
            )

        spec_app_version = spec.get("appVersion")
        if spec_app_version is not None and spec_app_version != app_version:
            raise click.ClickException(
                f"Spec appVersion {spec_app_version!r} does not match {app_version!r}"
            )

        changelog_path = directory / "changelog.md"
        if not changelog_path.exists():
            raise click.ClickException(
                f"Missing changelog.md in {directory}. Run './x release relnote' to generate it."
            )
        changelog_body = changelog_path.read_text(encoding="utf-8")

        from datetime import UTC
        from datetime import datetime as _datetime

        spec_published_at = spec.get("publishedAt")
        if isinstance(spec_published_at, dt.datetime):
            spec_published_at = (
                spec_published_at.astimezone(dt.UTC).isoformat().replace("+00:00", "Z")
            )

        effective_published_at = (
            published_at
            or spec_published_at
            or _datetime.now(UTC).isoformat().replace("+00:00", "Z")
        )
        effective_channels = split_csv(channels) or spec.get("channels") or ["testing"]
        effective_platforms = split_csv(platforms) or spec.get("platforms") or []
        effective_tags = split_csv(tags) or spec.get("tags") or ["release-note"]

        workspace_root = get_announce_workspace()
        workspace = AnnouncementWorkspace(workspace_root)
        workspace.ensure_remote_directories()

        effective_ids = workspace.get_effective_entry_ids(ACTIVE_KEY)
        if entry_id in effective_ids:
            raise click.ClickException(
                f"Entry {entry_id!r} already exists. Use 'edit' to modify it."
            )

        localizations: dict[str, AnnouncementLocalization] = {}
        for locale in ("zh", "en"):
            content_path = directory / f"content.{locale}.md"
            if not content_path.exists():
                raise click.ClickException(f"Missing required locale file: {content_path}")
            parsed = parse_locale_document(content_path, locale)
            composed_body = _compose_release_body(parsed.body_markdown, changelog_body)
            body_hash = workspace.store_document(composed_body)
            localizations[locale] = AnnouncementLocalization(
                title=parsed.title,
                summary=parsed.summary,
                body_hash=body_hash,
            )

        new_entry = AnnouncementEntry(
            id=entry_id,
            published_at=effective_published_at,
            tags=effective_tags,
            startup=False,
            min_app_version=None,
            max_app_version=None,
            channels=effective_channels,
            platforms=effective_platforms,
            app_version=app_version,
            localizations=localizations,
        )

        overlay = workspace.overlay_upsert_entry(ACTIVE_KEY, new_entry)
        workspace.write_overlay(overlay)

        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Staged release note entry: {entry_id}"))
        click.echo(styled([Fore.GREEN], f"  appVersion: {app_version}"))
        click.echo(styled([Fore.GREEN], f"  zh title: {localizations['zh'].title}"))
        click.echo(styled([Fore.GREEN], f"  en title: {localizations['en'].title}"))
        click.echo(
            styled(
                [Fore.CYAN],
                "  Run './x remote announce publish' to publish the overlay.",
            )
        )
