from __future__ import annotations

import asyncio
import json
import shutil

from pathlib import Path

import click

from click_aliases import ClickAliasedGroup
from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.config import ProjectConfiguration
from bootstrap.constant import PROJECT_ROOT
from bootstrap.utils import get_bin_size
from bootstrap.utils import get_file_sha1


_GENERATOR_TYPES = {"static", "native", "localization", "images"}

_ABI_FLUTTER_TO_APK = {
    "armeabi-v7a": "armv7",
    "arm64-v8a": "arm64",
    "x86_64": "x64",
}

_PLATFORM_DIR = {
    "android": "apk",
}

_PLATFORM_SUFFIX = {
    "android": ".apk",
}


def _build_apk_copy_and_verify(src_apk: Path, src_sha1: Path, dst_apk: Path, dst_sha1: Path):
    shutil.copy2(src_apk, dst_apk)
    shutil.copy2(src_sha1, dst_sha1)
    expected = src_sha1.read_text(encoding="utf-8").strip()
    actual = get_file_sha1(dst_apk)
    if expected != actual:
        raise click.ClickException(
            f"SHA1 mismatch for {dst_apk.name}: expected {expected}, got {actual}"
        )


def _utcnow_iso() -> str:
    from datetime import UTC
    from datetime import datetime

    return datetime.now(UTC).isoformat(timespec="seconds")


def _emit_release_json(data: dict[str, object], output: Path | None, default: Path) -> None:
    text = json.dumps(data, indent=2, ensure_ascii=False, sort_keys=False) + "\n"
    if output is None:
        default.parent.mkdir(parents=True, exist_ok=True)
        default.write_text(text, encoding="utf-8")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Written: {default}"))
    elif output == Path("-"):
        click.echo(text, nl=False)
    else:
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(text, encoding="utf-8")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Written: {output}"))


def _build_release_platform(
    platform: str,
    ver: str,
    ver_semver: str,
    output: Path | None,
    release_id: str | None,
    version_min: str | None,
    version_max: str | None,
) -> None:
    dir_name = _PLATFORM_DIR[platform]
    suffix = _PLATFORM_SUFFIX[platform]
    src_dir = PROJECT_ROOT / "cache" / "releases" / dir_name / ver
    if not src_dir.is_dir():
        raise click.ClickException(f"Build directory not found: {src_dir}")

    artifacts: dict[str, str] = {}
    for f in sorted(src_dir.iterdir()):
        if f.is_file() and f.suffix == suffix:
            name = f.name
            prefix = f"{ver}-{platform}-"
            if name.startswith(prefix):
                variant = name[len(prefix) : -len(suffix)]
                artifacts[variant] = str(f.resolve())
            elif name == f"{ver}-{platform}{suffix}":
                artifacts["general"] = str(f.resolve())

    if not artifacts:
        raise click.ClickException(f"No {suffix} files found in {src_dir}")

    rel_id = release_id or f"rel-{ver}"
    vmin = version_min or ver_semver
    vmax = version_max or ver_semver

    data: dict[str, object] = {
        "metadata": {
            "versionMin": vmin,
            "versionMax": vmax,
            "offerings": [platform],
            "releaseCount": 1,
            "createdAt": _utcnow_iso(),
        },
        "release": {
            "id": rel_id,
            "version": ver,
            platform: artifacts,
        },
    }

    _emit_release_json(data, output, src_dir / f"{ver}-{platform}.json")


def _build_release_merge(fragments: list[Path], ver: str, output: Path | None) -> None:
    merged_metadata: dict = {}
    merged_release: dict = {}
    all_paths: list[Path] = []

    for fp in fragments:
        raw = fp.read_text(encoding="utf-8")
        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            raise click.ClickException(f"Cannot parse {fp}: {e}") from None

        meta = data.get("metadata", {})
        rel = data.get("release", {})

        for offering in meta.get("offerings", []):
            if offering not in merged_metadata.setdefault("offerings", []):
                merged_metadata["offerings"].append(offering)

        merged_metadata.setdefault("versionMin", meta.get("versionMin"))
        merged_metadata.setdefault("versionMax", meta.get("versionMax"))
        merged_metadata.setdefault("createdAt", meta.get("createdAt"))

        for pkey, pdict in rel.items():
            if pkey in ("id", "version"):
                merged_release.setdefault(pkey, pdict)
            elif isinstance(pdict, dict):
                for _variant, path_str in pdict.items():
                    if isinstance(path_str, str):
                        pp = Path(path_str)
                        all_paths.append(pp)

        for pkey, pdict in rel.items():
            if pkey not in ("id", "version") and isinstance(pdict, dict):
                if pkey in merged_release:
                    raise click.ClickException(
                        f"Duplicate platform fragment for {pkey!r} while merging {fp}"
                    )
                merged_release[pkey] = pdict

    missing = [str(p) for p in all_paths if not p.exists()]
    if missing:
        raise click.ClickException(
            "Missing files referenced in fragments:\n  " + "\n  ".join(missing)
        )

    merged_metadata["releaseCount"] = 1
    data: dict[str, object] = {
        "metadata": merged_metadata,
        "release": merged_release,
    }

    default_output = PROJECT_ROOT / "cache" / "releases" / "merge" / f"{ver}.json"
    _emit_release_json(data, output, default_output)


def register_build_commands(cli_group: click.Group) -> None:
    @cli_group.group(cls=ClickAliasedGroup)
    def build():
        """Build related commands."""

    @build.command("data")
    @click.option(
        "--skip",
        "-s",
        multiple=True,
        help=f"Skip specified data generators. Values: {', '.join(_GENERATOR_TYPES)}",
    )
    @click.option("--author", default=None, help="Author identifier for the snapshot.")
    @click.option("--description", default=None, help="Description for the snapshot.")
    def data_cmd(skip: list[str], author: str | None, description: str | None):
        """Build data files."""
        from bootstrap.data.workspace.generate import run_generator

        to_skip = set()
        for it in skip:
            for i in it.split(","):
                to_skip.add(i.strip().lower())

        if len(x := to_skip.difference(_GENERATOR_TYPES)) > 0:
            click.echo(
                styled([Style.BRIGHT, Fore.RED], "Invalid generator type to skip: ") + ", ".join(x)
            )
            click.echo("Valid types are: " + ", ".join(_GENERATOR_TYPES))
            exit(1)

        asyncio.run(
            run_generator(
                runtime.current_workspace_descriptor(),
                to_skip,
                author=author,
                description=description,
            )
        )

    @build.command("announcements", aliases=["anno"])
    def build_announcements_cmd():
        """Build bundled announcement catalog assets."""
        from bootstrap.docs import build_bundled_announcements

        try:
            build_bundled_announcements()
        except ValueError as exception:
            raise click.ClickException(str(exception)) from exception

    @build.command("apk")
    @click.option(
        "--clean", is_flag=True, default=False, help="Run `flutter clean` before building."
    )
    @click.option("--flavor", default=None, help="Flutter flavor to build (e.g. dev, prod).")
    @click.option(
        "--debug", is_flag=True, default=False, help="Build debug APK (single ABI only, no split)."
    )
    def build_apk_cmd(clean: bool, flavor: str | None, debug: bool):
        """Build Android APKs with versioned filenames."""
        ProjectConfiguration.ensure_loaded()
        version = bootstrap.config.CONFIGURATION.version
        ver = version.render_full()
        output_dir = PROJECT_ROOT / "cache" / "releases" / "apk" / ver
        output_dir.mkdir(parents=True, exist_ok=True)
        apk_source = PROJECT_ROOT / "build" / "app" / "outputs" / "flutter-apk"

        from bootstrap.utils import get_command

        flutter = get_command("flutter")
        flavor_args = [f"--flavor={flavor}"] if flavor else []

        if clean:
            runtime.execute([flutter, "clean"], "CLEANING BUILD ARTIFACTS")

        if debug:
            runtime.execute(
                [flutter, "build", "apk", "--debug", *flavor_args], "BUILDING DEBUG APK"
            )
            src_prefix = f"app-{flavor}-" if flavor else "app-"
            src_apk = apk_source / f"{src_prefix}debug.apk"
            src_sha1 = apk_source / f"{src_prefix}debug.apk.sha1"
            if not src_apk.exists():
                raise click.ClickException(f"Expected debug APK not found: {src_apk}")
            dst_apk = output_dir / f"{ver}-android-debug.apk"
            dst_sha1 = output_dir / f"{ver}-android-debug.apk.sha1"
            _build_apk_copy_and_verify(src_apk, src_sha1, dst_apk, dst_sha1)
        else:
            runtime.execute([flutter, "build", "apk", *flavor_args], "BUILDING GENERAL APK")
            src_apk = apk_source / (f"app-{flavor}-release.apk" if flavor else "app-release.apk")
            src_sha1 = apk_source / (
                f"app-{flavor}-release.apk.sha1" if flavor else "app-release.apk.sha1"
            )
            if not src_apk.exists():
                raise click.ClickException(f"Expected general APK not found: {src_apk}")
            dst_apk = output_dir / f"{ver}-android.apk"
            dst_sha1 = output_dir / f"{ver}-android.apk.sha1"
            _build_apk_copy_and_verify(src_apk, src_sha1, dst_apk, dst_sha1)

            runtime.execute(
                [flutter, "build", "apk", "--split-per-abi", *flavor_args],
                "BUILDING SPLIT ABI APKS",
            )
            for flutter_abi, apk_suffix in _ABI_FLUTTER_TO_APK.items():
                src_apk = apk_source / (
                    f"app-{flavor}-{flutter_abi}-release.apk"
                    if flavor
                    else f"app-{flutter_abi}-release.apk"
                )
                src_sha1 = apk_source / (
                    f"app-{flavor}-{flutter_abi}-release.apk.sha1"
                    if flavor
                    else f"app-{flutter_abi}-release.apk.sha1"
                )
                if not src_apk.exists():
                    raise click.ClickException(f"Expected ABI APK not found: {src_apk}")
                dst_apk = output_dir / f"{ver}-android-{apk_suffix}.apk"
                dst_sha1 = output_dir / f"{ver}-android-{apk_suffix}.apk.sha1"
                _build_apk_copy_and_verify(src_apk, src_sha1, dst_apk, dst_sha1)

        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Build complete. Output: {output_dir}"))
        for f in sorted(output_dir.iterdir()):
            if f.is_file():
                size = get_bin_size(f.stat().st_size)
                click.echo(f"  {f.name} ({size})")

    @build.command("release")
    @click.option(
        "--platform",
        default=None,
        type=click.Choice(["android"]),
        help="Platform to produce a fragment for.",
    )
    @click.option(
        "--merge",
        "merge_files",
        multiple=True,
        type=click.Path(exists=True, path_type=Path),
        help="Fragment JSON files to merge (repeatable).",
    )
    @click.option(
        "--output",
        type=click.Path(path_type=Path),
        default=None,
        help="Output file path (default: auto-determined within cache, or stdout for '-').",
    )
    @click.option(
        "--release-id", default=None, help="Override release.id (default: rel-{version})."
    )
    @click.option("--version-min", default=None, help="Override minimum version string.")
    @click.option("--version-max", default=None, help="Override maximum version string.")
    def build_release_cmd(
        platform: str | None,
        merge_files: list[Path],
        output: Path | None,
        release_id: str | None,
        version_min: str | None,
        version_max: str | None,
    ):
        """Build or merge release registry fragments."""
        if platform and merge_files:
            raise click.ClickException("Cannot use --platform and --merge together.")
        if not platform and not merge_files:
            raise click.ClickException("Must specify --platform or --merge.")

        ProjectConfiguration.ensure_loaded()
        version = bootstrap.config.CONFIGURATION.version
        ver = version.render_full()
        ver_semver = version.render_semver()

        if platform:
            _build_release_platform(
                platform, ver, ver_semver, output, release_id, version_min, version_max
            )
        else:
            _build_release_merge(list(merge_files), ver, output)

    @build.command("list", aliases=["ls"])
    @click.option("--apps", is_flag=True, default=False, help="Show APK builds.")
    @click.option("--resources", is_flag=True, default=False, help="Show resource snapshots.")
    @click.option("--releases", is_flag=True, default=False, help="Show release snapshots.")
    @click.option("--generations", is_flag=True, default=False, help="Show generations.")
    def build_list_cmd(apps: bool, resources: bool, releases: bool, generations: bool):
        """List local build / cache items."""
        from bootstrap.remote.generation import GenerationStore
        from bootstrap.remote.head import ChannelHeadStore
        from bootstrap.remote.snapshot import SnapshotStore

        def _dir_size(dir_path: Path) -> int:
            if not dir_path.is_dir():
                return 0
            total = 0
            try:
                for f in dir_path.rglob("*"):
                    if f.is_file():
                        total += f.stat().st_size
            except PermissionError:
                pass
            return total

        def _scan_apk_versions(apk_root: Path) -> tuple[list[Path], list[Path]]:
            versions: list[Path] = []
            files: list[Path] = []
            if apk_root.is_dir():
                for vd in sorted(apk_root.iterdir()):
                    if vd.is_dir():
                        versions.append(vd)
                        for f in vd.iterdir():
                            if f.is_file():
                                files.append(f)
            return versions, files

        any_opt = apps or resources or releases or generations
        schema_root = runtime.resolve_schema_root(None)

        if not any_opt:
            click.echo()
            click.echo(styled([Style.BRIGHT], "Local Build Cache Summary"))
            click.echo(styled([Style.BRIGHT], "=" * 27))

            apk_root = PROJECT_ROOT / "cache" / "releases" / "apk"
            apk_versions, apk_files = _scan_apk_versions(apk_root)
            apk_total = sum(f.stat().st_size for f in apk_files)
            if apk_versions:
                click.echo(
                    f"  {styled(Fore.GREEN, 'APK builds:')}            "
                    f"{styled([Style.BRIGHT], str(len(apk_versions)))} version(s)"
                    f"  ({get_bin_size(apk_total)})"
                )
            else:
                click.echo(f"  {styled(Fore.GREEN, 'APK builds:')}            (none)")

            if schema_root.is_dir():
                snap_store = SnapshotStore(schema_root)
                gen_store = GenerationStore(schema_root)
                head_store = ChannelHeadStore(schema_root)

                res_hashes = snap_store.list_resource_snapshots()
                rel_hashes = snap_store.list_release_snapshots()
                all_gens = gen_store.list_all()
                registry = head_store.get_registry()

                for label, hashes, asset_dir in [
                    ("Resource snapshots:", res_hashes, "resources"),
                    ("Release snapshots:", rel_hashes, "releases"),
                ]:
                    if hashes:
                        total = sum(
                            _dir_size(schema_root / "assets" / asset_dir / h) for h in hashes
                        )
                        click.echo(
                            f"  {styled(Fore.GREEN, label):30s}"
                            f"{styled([Style.BRIGHT], str(len(hashes)))} item(s)"
                            f"  ({get_bin_size(total)})"
                        )
                    else:
                        click.echo(f"  {styled(Fore.GREEN, label):30s}(none)")

                if all_gens:
                    gen_total = sum(
                        _dir_size(schema_root / "channels" / "refs" / h) for h in all_gens
                    )
                    click.echo(
                        f"  {styled(Fore.GREEN, 'Generations:'):30s}"
                        f"{styled([Style.BRIGHT], str(len(all_gens)))} item(s)"
                        f"  ({get_bin_size(gen_total)})"
                    )
                else:
                    click.echo(f"  {styled(Fore.GREEN, 'Generations:'):30s}(none)")

                channels = list(registry.channels.keys())
                if channels:
                    click.echo(
                        f"  {styled(Fore.GREEN, 'Channels:'):30s}"
                        f"{styled([Style.BRIGHT], str(len(channels)))} ({', '.join(channels)})"
                    )
                else:
                    click.echo(f"  {styled(Fore.GREEN, 'Channels:'):30s}(none)")

                blobs_dir = schema_root / "assets" / "blobs"
                if blobs_dir.is_dir():
                    blobs_count = 0
                    blobs_total = 0
                    for f in blobs_dir.rglob("*"):
                        if f.is_file():
                            blobs_count += 1
                            blobs_total += f.stat().st_size
                    click.echo(
                        f"  {styled(Fore.GREEN, 'Content blobs:'):30s}"
                        f"{styled([Style.BRIGHT], str(blobs_count))} file(s)"
                        f"  ({get_bin_size(blobs_total)})"
                    )
                else:
                    click.echo(f"  {styled(Fore.GREEN, 'Content blobs:'):30s}(none)")
            else:
                click.echo(
                    styled([Style.BRIGHT, Fore.YELLOW], "  Schema cache: ")
                    + styled(Fore.YELLOW, f"not found ({schema_root})")
                )

            click.echo()
        else:
            first = True

            if apps:
                if not first:
                    click.echo()
                first = False
                apk_root = PROJECT_ROOT / "cache" / "releases" / "apk"
                apk_versions, apk_files = _scan_apk_versions(apk_root)

                click.echo(
                    styled([Style.BRIGHT, Fore.GREEN], f"\nAPK Builds ({len(apk_versions)})")
                )
                click.echo(styled([Style.BRIGHT], "=" * 50))
                if not apk_versions:
                    click.echo("  (none)")
                else:
                    for vd in apk_versions:
                        v_total = sum(f.stat().st_size for f in vd.iterdir() if f.is_file())
                        click.echo(
                            f"  {styled([Style.BRIGHT], vd.name)}  ({get_bin_size(v_total)})"
                        )
                        for f in sorted(vd.iterdir()):
                            if f.is_file():
                                click.echo(f"    {f.name}  ({get_bin_size(f.stat().st_size)})")

            if resources:
                if not first:
                    click.echo()
                first = False
                if not schema_root.is_dir():
                    click.echo(
                        styled([Style.BRIGHT, Fore.YELLOW], "Schema cache not found: ")
                        + str(schema_root)
                    )
                else:
                    snap_store = SnapshotStore(schema_root)
                    res_hashes = snap_store.list_resource_snapshots()
                    click.echo(
                        styled(
                            [Style.BRIGHT, Fore.GREEN], f"\nResource Snapshots ({len(res_hashes)})"
                        )
                    )
                    click.echo(styled([Style.BRIGHT], "=" * 80))
                    if not res_hashes:
                        click.echo("  (none)")
                    else:
                        click.echo(
                            f"  {'Hash':9s}  {'Server':13s}  {'Build':13s}"
                            f"  {'Version':11s}  {'Resources':>10s}  Created"
                        )
                        click.echo(
                            f"  {'-' * 9}  {'-' * 13}  {'-' * 13}  {'-' * 11}  {'-' * 10}  {'-' * 25}"
                        )
                        for h in res_hashes:
                            try:
                                meta, _ = snap_store.load_resource_snapshot(h)
                                click.echo(
                                    f"  {h[:9]:9s}  {meta.server_id:13s}  {meta.game_build:13s}"
                                    f"  {meta.game_version:11s}  {meta.resource_count!s:>10s}"
                                    f"  {meta.created_at}"
                                )
                            except Exception:
                                click.echo(f"  {h[:9]:9s}  {styled(Fore.RED, '[ERR]')}")

            if releases:
                if not first:
                    click.echo()
                first = False
                if not schema_root.is_dir():
                    click.echo(
                        styled([Style.BRIGHT, Fore.YELLOW], "Schema cache not found: ")
                        + str(schema_root)
                    )
                else:
                    snap_store = SnapshotStore(schema_root)
                    rel_hashes = snap_store.list_release_snapshots()
                    click.echo(
                        styled(
                            [Style.BRIGHT, Fore.GREEN], f"\nRelease Snapshots ({len(rel_hashes)})"
                        )
                    )
                    click.echo(styled([Style.BRIGHT], "=" * 70))
                    if not rel_hashes:
                        click.echo("  (none)")
                    else:
                        click.echo(
                            f"  {'Hash':9s}  {'Version Range':21s}  {'Releases':>10s}  Created"
                        )
                        click.echo(f"  {'-' * 9}  {'-' * 21}  {'-' * 10}  {'-' * 25}")
                        for h in rel_hashes:
                            try:
                                meta, _ = snap_store.load_release_snapshot(h)
                                v_range = f"{meta.version_min or '—'} ~ {meta.version_max or '—'}"
                                click.echo(
                                    f"  {h[:9]:9s}  {v_range:21s}"
                                    f"  {meta.release_count!s:>10s}  {meta.created_at}"
                                )
                            except Exception:
                                click.echo(f"  {h[:9]:9s}  {styled(Fore.RED, '[ERR]')}")

            if generations:
                if not first:
                    click.echo()
                first = False
                if not schema_root.is_dir():
                    click.echo(
                        styled([Style.BRIGHT, Fore.YELLOW], "Schema cache not found: ")
                        + str(schema_root)
                    )
                else:
                    gen_store = GenerationStore(schema_root)
                    all_gens = gen_store.list_all()
                    click.echo(
                        styled([Style.BRIGHT, Fore.GREEN], f"\nGenerations ({len(all_gens)})")
                    )
                    click.echo(styled([Style.BRIGHT], "=" * 80))
                    if not all_gens:
                        click.echo("  (none)")
                    else:
                        click.echo(
                            f"  {'Hash':9s}  {'Channel':10s}  {'Parent':9s}  {'Subject':20s}  Timestamp"
                        )
                        click.echo(f"  {'-' * 9}  {'-' * 10}  {'-' * 9}  {'-' * 20}  {'-' * 25}")
                        for h, gen in all_gens.items():
                            parent_short = (
                                (gen.metadata.parent or "")[:9] if gen.metadata.parent else "—"
                            )
                            subject = gen.metadata.subject or ""
                            click.echo(
                                f"  {h[:9]:9s}  {gen.metadata.channel:10s}"
                                f"  {parent_short:9s}  {subject[:19]:20s}"
                                f"  {gen.metadata.timestamp}"
                            )
