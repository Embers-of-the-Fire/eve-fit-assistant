from __future__ import annotations

import asyncio
import json
import os
import re
import shutil
import sys

from pathlib import Path

import click

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
    "linux": "linux",
    "windows": "windows",
}

_PLATFORM_SUFFIX = {
    "android": ".apk",
}


def _linux_variant_files(ver: str) -> dict[str, str]:
    return {
        "appimage": f"{ver}-linux.AppImage",
        "native": f"{ver}-linux-native.zip",
    }


def _windows_variant_files(ver: str) -> dict[str, str]:
    return {
        "native": f"{ver}-windows-native.zip",
        "installer": f"{ver}-windows-setup.msi",
    }


_PLATFORM_VARIANT_FILES = {
    "linux": _linux_variant_files,
    "windows": _windows_variant_files,
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
    root: Path,
) -> None:
    dir_name = _PLATFORM_DIR[platform]
    src_dir = root / dir_name / ver
    if not src_dir.is_dir():
        raise click.ClickException(f"Build directory not found: {src_dir}")

    artifacts: dict[str, str] = {}
    if platform in _PLATFORM_VARIANT_FILES:
        for variant, name in _PLATFORM_VARIANT_FILES[platform](ver).items():
            f = src_dir / name
            if f.is_file():
                # POSIX separators: fragments are merged on Linux CI runners even
                # when produced by the Windows job.
                artifacts[variant] = f.relative_to(root).as_posix()
        if not artifacts:
            raise click.ClickException(f"No {platform} variant files found in {src_dir}")
    else:
        suffix = _PLATFORM_SUFFIX[platform]
        for f in sorted(src_dir.iterdir()):
            if f.is_file() and f.suffix == suffix:
                name = f.name
                prefix = f"{ver}-{platform}-"
                if name.startswith(prefix):
                    variant = name[len(prefix) : -len(suffix)]
                    artifacts[variant] = f.relative_to(root).as_posix()
                elif name == f"{ver}-{platform}{suffix}":
                    artifacts["general"] = f.relative_to(root).as_posix()

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


def _build_release_merge(fragments: list[Path], ver: str, output: Path | None, root: Path) -> None:
    merged_metadata: dict = {}
    merged_release: dict = {}
    all_paths: list[Path] = []

    default_output = root / "merge" / f"{ver}.json"
    effective_output = output if output is not None else default_output
    ref_dir = root if effective_output == Path("-") else effective_output.parent

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

        for key in ("versionMin", "versionMax", "createdAt"):
            value = meta.get(key)
            if value is not None and merged_metadata.get(key) is None:
                merged_metadata[key] = value

        for pkey, pdict in rel.items():
            if pkey in ("id", "version"):
                merged_release.setdefault(pkey, pdict)
            elif isinstance(pdict, dict):
                if pkey in merged_release:
                    raise click.ClickException(
                        f"Duplicate platform fragment for {pkey!r} while merging {fp}"
                    )
                normalized: dict[str, str] = {}
                for variant, path_str in pdict.items():
                    if isinstance(path_str, str):
                        pp = root / Path(path_str)
                        if pp.is_absolute() and not pp.is_relative_to(root):
                            raise click.ClickException(
                                f"Path {path_str!r} escapes root {root} in {fp}"
                            )
                        all_paths.append(pp)
                        normalized[variant] = os.path.relpath(pp, ref_dir).replace(os.sep, "/")
                merged_release[pkey] = normalized

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

    _emit_release_json(data, output, default_output)


# Canvaskit artifacts required per renderer. The Flutter loader only fetches
# the files belonging to the renderers declared in flutter_bootstrap.js;
# everything else (other renderers, *.symbols debug files) can be pruned.
_WEB_RENDERER_ARTIFACTS = {
    "skwasm": {"skwasm.js", "skwasm.wasm", "skwasm_heavy.js", "skwasm_heavy.wasm"},
    "canvaskit": {"canvaskit.js", "canvaskit.wasm", "chromium"},
}


def _read_web_renderers(build_dir: Path) -> set[str]:
    bootstrap_js = build_dir / "flutter_bootstrap.js"
    match = re.search(
        r"_flutter\.buildConfig\s*=\s*(\{.*?\});",
        bootstrap_js.read_text(encoding="utf-8"),
        re.DOTALL,
    )
    if match is None:
        raise click.ClickException(f"Could not locate buildConfig in {bootstrap_js}")
    config = json.loads(match.group(1))
    builds = config.get("builds", [])
    return {b["renderer"] for b in builds if "renderer" in b}


def _prune_canvaskit(build_dir: Path) -> int:
    """Remove canvaskit artifacts unused by the declared renderers.

    Returns the number of bytes removed.
    """
    canvaskit_dir = build_dir / "canvaskit"
    if not canvaskit_dir.is_dir():
        return 0

    renderers = _read_web_renderers(build_dir)
    keep: set[str] = set()
    for renderer in renderers:
        keep |= _WEB_RENDERER_ARTIFACTS.get(renderer, set())

    removed_bytes = 0

    def _measure(path: Path) -> int:
        if path.is_dir():
            return sum(f.stat().st_size for f in path.rglob("*") if f.is_file())
        return path.stat().st_size

    for entry in sorted(canvaskit_dir.iterdir()):
        drop = entry.name.endswith(".symbols") or entry.name not in keep
        if not drop:
            continue
        removed_bytes += _measure(entry)
        if entry.is_dir():
            shutil.rmtree(entry)
        else:
            entry.unlink()

    return removed_bytes


def register_build_commands(cli_group: click.Group) -> None:
    @cli_group.group()
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
    @click.option(
        "--schema-root",
        type=click.Path(file_okay=False, path_type=Path),
        default=None,
        help="Schema V2 storage root for the generated snapshot (default from dev config).",
    )
    @click.option(
        "--output-snapshot-hash",
        type=click.Path(file_okay=True, path_type=Path),
        default=None,
        help="Write the generated snapshot hash to this file.",
    )
    def data_cmd(
        skip: list[str],
        author: str | None,
        description: str | None,
        schema_root: Path | None,
        output_snapshot_hash: Path | None,
    ):
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
            sys.exit(1)

        snapshot_hash = asyncio.run(
            run_generator(
                runtime.current_workspace_descriptor(),
                to_skip,
                author=author,
                description=description,
                schema_root=schema_root,
            )
        )

        if output_snapshot_hash is not None:
            if snapshot_hash is None:
                raise click.ClickException(
                    f"No snapshot was produced; cannot write {output_snapshot_hash}"
                )
            output_snapshot_hash.parent.mkdir(parents=True, exist_ok=True)
            output_snapshot_hash.write_text(snapshot_hash, encoding="utf-8")

        return snapshot_hash

    @build.command("docs")
    def build_docs_cmd():
        """Build bundled announcement and release-note assets."""
        from bootstrap.docs import build_bundled_docs

        try:
            build_bundled_docs()
        except ValueError as exception:
            raise click.ClickException(str(exception)) from exception

    @build.command("manual")
    def build_manual_cmd():
        """Build the bundled user-manual registry and content assets."""
        from bootstrap.docs import build_manual

        try:
            build_manual()
        except (ValueError, FileNotFoundError, TypeError) as exception:
            raise click.ClickException(str(exception)) from exception

    @build.command("site-manual")
    def build_site_manual_cmd():
        """Generate Starlight site content from docs/manual, changelog, and announcements."""
        from bootstrap.docs import build_site_manual

        try:
            build_site_manual()
        except (ValueError, FileNotFoundError, TypeError) as exception:
            raise click.ClickException(str(exception)) from exception

    @build.command("web")
    @click.option(
        "--no-prune",
        is_flag=True,
        default=False,
        help="Skip pruning canvaskit artifacts unused by the declared renderers.",
    )
    def build_web_cmd(no_prune: bool):
        """Build the Flutter web (wasm) bundle for static hosting.

        Builds the FRB engine wasm with atomics so FRB's web worker pool can
        run engine calls (database parsing, emulation) in real Web Workers
        instead of the main thread. The threaded build requires the deployment
        to be cross-origin isolated (COOP/COEP headers, shipped via
        `web/_headers`). The Dart bundle uses locally bundled canvaskit/skwasm
        (no CDN). Run inside a shell providing flutter_rust_bridge_codegen,
        wasm-pack, and binaryen (e.g. `nix develop .#codegen`).

        The link args follow the wasm-bindgen threading recipe: lld does not
        enable shared memory from `+atomics` alone, so `--shared-memory`,
        `--import-memory` (workers must share the *same* memory instance), a
        fixed `--max-memory` (shared memories cannot grow), and the TLS/heap
        symbols are passed explicitly.
        """
        from bootstrap.utils import get_command

        flutter_rust_bridge_codegen = get_command("flutter_rust_bridge_codegen")
        flutter = get_command("flutter")

        runtime.execute(
            [
                flutter_rust_bridge_codegen,
                "build-web",
                "--release",
                "--wasm-pack-rustflags",
                (
                    "-C target-feature=+atomics,+bulk-memory,+mutable-globals"
                    " -Clink-args=--shared-memory"
                    " -Clink-args=--max-memory=1073741824"
                    " -Clink-args=--import-memory"
                    " -Clink-args=--export=__heap_base"
                    " -Clink-args=--export=__wasm_init_tls"
                    " -Clink-args=--export=__tls_size"
                    " -Clink-args=--export=__tls_align"
                    " -Clink-args=--export=__tls_base"
                ),
            ],
            "BUILDING WEB ENGINE (WASM)",
        )
        runtime.execute(
            [flutter, "build", "web", "--wasm", "--no-web-resources-cdn"],
            "BUILDING FLUTTER WEB BUNDLE",
        )

        output_dir = PROJECT_ROOT / "build" / "web"
        if not output_dir.is_dir():
            raise click.ClickException(f"Expected web build output not found: {output_dir}")

        if no_prune:
            click.echo(styled([Style.BRIGHT, Fore.YELLOW], "Skipping canvaskit prune."))
        else:
            removed_bytes = _prune_canvaskit(output_dir)
            click.echo(
                styled(
                    [Style.BRIGHT, Fore.GREEN],
                    f"Pruned unused canvaskit artifacts ({get_bin_size(removed_bytes)}).",
                )
            )

        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Build complete. Output: {output_dir}"))

    @build.command("apk")
    @click.option(
        "--clean", is_flag=True, default=False, help="Run `flutter clean` before building."
    )
    @click.option("--flavor", default=None, help="Flutter flavor to build (e.g. dev, prod).")
    @click.option(
        "--root",
        "-r",
        type=click.Path(path_type=Path),
        default=PROJECT_ROOT / "cache" / "releases",
        help="Release root directory (default: cache/releases).",
    )
    @click.option(
        "--output",
        "-o",
        type=click.Path(path_type=Path),
        default=None,
        help="Release fragment output path (default: <root>/apk/<ver>/<ver>-android.json).",
    )
    @click.option(
        "--release-id", default=None, help="Override release.id (default: rel-{version})."
    )
    @click.option("--version-min", default=None, help="Override minimum version string.")
    @click.option("--version-max", default=None, help="Override maximum version string.")
    def build_apk_cmd(
        clean: bool,
        flavor: str | None,
        root: Path,
        output: Path | None,
        release_id: str | None,
        version_min: str | None,
        version_max: str | None,
    ):
        """Build Android APKs with versioned filenames and emit a release fragment."""
        ProjectConfiguration.ensure_loaded()
        version = bootstrap.config.CONFIGURATION.version
        ver = version.render_full()
        output_dir = root / "apk" / ver
        output_dir.mkdir(parents=True, exist_ok=True)
        apk_source = PROJECT_ROOT / "build" / "app" / "outputs" / "flutter-apk"

        from bootstrap.utils import get_command

        flutter = get_command("flutter")
        flavor_args = [f"--flavor={flavor}"] if flavor else []

        if clean:
            runtime.execute([flutter, "clean"], "CLEANING BUILD ARTIFACTS")

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

        _build_release_platform(
            platform="android",
            ver=ver,
            ver_semver=version.render_semver(),
            output=output,
            release_id=release_id,
            version_min=version_min,
            version_max=version_max,
            root=root,
        )

    @build.command("linux")
    @click.option(
        "--clean", is_flag=True, default=False, help="Run `flutter clean` before building."
    )
    @click.option(
        "--skip-flutter",
        is_flag=True,
        default=False,
        help="Skip the Flutter Linux build and reuse the existing release bundle.",
    )
    @click.option(
        "--variant",
        "variants",
        multiple=True,
        type=click.Choice(["appimage", "native"]),
        help="Linux variant to build (repeatable; default: all variants).",
    )
    @click.option(
        "--root",
        "-r",
        type=click.Path(path_type=Path),
        default=PROJECT_ROOT / "cache" / "releases",
        help="Release root directory (default: cache/releases).",
    )
    @click.option(
        "--output",
        "-o",
        type=click.Path(path_type=Path),
        default=None,
        help="Release fragment output path (default: <root>/linux/<ver>/<ver>-linux.json).",
    )
    @click.option(
        "--release-id", default=None, help="Override release.id (default: rel-{version})."
    )
    @click.option("--version-min", default=None, help="Override minimum version string.")
    @click.option("--version-max", default=None, help="Override maximum version string.")
    def build_linux_cmd(
        clean: bool,
        skip_flutter: bool,
        variants: tuple[str, ...],
        root: Path,
        output: Path | None,
        release_id: str | None,
        version_min: str | None,
        version_max: str | None,
    ):
        """Build the Linux release variants (AppImage and/or native zip)."""
        if clean and skip_flutter:
            raise click.ClickException(
                "--clean and --skip-flutter cannot be combined: "
                "`flutter clean` removes the release bundle that --skip-flutter relies on."
            )
        selected = set(variants) if variants else {"appimage", "native"}
        ProjectConfiguration.ensure_loaded()
        version = bootstrap.config.CONFIGURATION.version
        ver = version.render_full()
        output_dir = root / "linux" / ver
        output_dir.mkdir(parents=True, exist_ok=True)

        from bootstrap.release.linux import assemble_appdir
        from bootstrap.release.linux import pack_appimage
        from bootstrap.release.linux import pack_native_zip
        from bootstrap.utils import get_command

        flutter = get_command("flutter")
        if "appimage" in selected:
            missing = [
                name
                for name in ("linuxdeploy", "appimagetool", "ldd", "readelf")
                if not shutil.which(name)
            ]
            if missing:
                raise click.ClickException(
                    f"Command(s) not found in PATH: {', '.join(missing)}. "
                    "Enter the Nix dev shell (`nix develop .#linux`) to get them."
                )

        if clean:
            runtime.execute([flutter, "clean"], "CLEANING BUILD ARTIFACTS")

        runtime.execute([flutter, "config", "--enable-linux-desktop"], "ENABLE LINUX DESKTOP")

        if not skip_flutter:
            runtime.execute([flutter, "build", "linux", "--release"], "BUILDING LINUX BUNDLE")

        bundle_dir = PROJECT_ROOT / "build" / "linux" / "x64" / "release" / "bundle"
        if "appimage" in selected:
            appdir = assemble_appdir(
                bundle_dir=bundle_dir,
                work_dir=PROJECT_ROOT / "dist",
                linuxdeploy=get_command("linuxdeploy"),
                ldd=get_command("ldd"),
                readelf=get_command("readelf"),
                dry_run=runtime.is_dry_run(),
            )
            pack_appimage(
                appdir=appdir,
                output_dir=output_dir,
                version=version,
                appimagetool=get_command("appimagetool"),
                dry_run=runtime.is_dry_run(),
            )
        if "native" in selected:
            pack_native_zip(
                bundle_dir=bundle_dir,
                output_dir=output_dir,
                version=version,
                dry_run=runtime.is_dry_run(),
            )

        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Build complete. Output: {output_dir}"))
        for f in sorted(output_dir.iterdir()):
            if f.is_file():
                size = get_bin_size(f.stat().st_size)
                click.echo(f"  {f.name} ({size})")

        if not runtime.is_dry_run():
            _build_release_platform(
                platform="linux",
                ver=ver,
                ver_semver=version.render_semver(),
                output=output,
                release_id=release_id,
                version_min=version_min,
                version_max=version_max,
                root=root,
            )

    @build.command("windows")
    @click.option(
        "--clean", is_flag=True, default=False, help="Run `flutter clean` before building."
    )
    @click.option(
        "--skip-flutter",
        is_flag=True,
        default=False,
        help="Skip the Flutter Windows build and reuse the existing release bundle.",
    )
    @click.option(
        "--variant",
        "variants",
        multiple=True,
        type=click.Choice(["native", "installer"]),
        help="Windows variant to build (repeatable; default: all variants).",
    )
    @click.option(
        "--root",
        "-r",
        type=click.Path(path_type=Path),
        default=PROJECT_ROOT / "cache" / "releases",
        help="Release root directory (default: cache/releases).",
    )
    @click.option(
        "--output",
        "-o",
        type=click.Path(path_type=Path),
        default=None,
        help="Release fragment output path (default: <root>/windows/<ver>/<ver>-windows.json).",
    )
    @click.option(
        "--release-id", default=None, help="Override release.id (default: rel-{version})."
    )
    @click.option("--version-min", default=None, help="Override minimum version string.")
    @click.option("--version-max", default=None, help="Override maximum version string.")
    def build_windows_cmd(
        clean: bool,
        skip_flutter: bool,
        variants: tuple[str, ...],
        root: Path,
        output: Path | None,
        release_id: str | None,
        version_min: str | None,
        version_max: str | None,
    ):
        """Build the Windows release variants (native zip and/or MSI installer)."""
        if sys.platform != "win32":
            raise click.ClickException("The Windows build must run on a Windows host.")
        if clean and skip_flutter:
            raise click.ClickException(
                "--clean and --skip-flutter cannot be combined: "
                "`flutter clean` removes the release bundle that --skip-flutter relies on."
            )
        selected = set(variants) if variants else {"native", "installer"}
        ProjectConfiguration.ensure_loaded()
        version = bootstrap.config.CONFIGURATION.version
        ver = version.render_full()
        output_dir = root / "windows" / ver
        output_dir.mkdir(parents=True, exist_ok=True)

        from bootstrap.release.windows import pack_msi
        from bootstrap.release.windows import pack_native_zip
        from bootstrap.release.windows import validate_bundle
        from bootstrap.utils import get_command

        flutter = get_command("flutter")
        if "installer" in selected:
            missing = [name for name in ("dotnet", "wix") if not shutil.which(name)]
            if missing:
                raise click.ClickException(
                    f"Command(s) not found in PATH: {', '.join(missing)}. "
                    "Install the WiX toolset v6 with: dotnet tool install --global wix "
                    "--version 6.0.1 (requires the .NET SDK; WiX v7 requires accepting "
                    "the OSMF EULA and is not supported)."
                )

        if clean:
            runtime.execute([flutter, "clean"], "CLEANING BUILD ARTIFACTS")

        runtime.execute([flutter, "config", "--enable-windows-desktop"], "ENABLE WINDOWS DESKTOP")

        if not skip_flutter:
            runtime.execute([flutter, "build", "windows", "--release"], "BUILDING WINDOWS BUNDLE")

        bundle_dir = PROJECT_ROOT / "build" / "windows" / "x64" / "runner" / "Release"
        if not runtime.is_dry_run():
            validate_bundle(bundle_dir)

        if "native" in selected:
            pack_native_zip(
                bundle_dir=bundle_dir,
                output_dir=output_dir,
                version=version,
                dry_run=runtime.is_dry_run(),
            )
        if "installer" in selected:
            pack_msi(
                bundle_dir=bundle_dir,
                output_dir=output_dir,
                version=version,
                wix=get_command("wix"),
                dry_run=runtime.is_dry_run(),
            )

        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Build complete. Output: {output_dir}"))
        for f in sorted(output_dir.iterdir()):
            if f.is_file():
                size = get_bin_size(f.stat().st_size)
                click.echo(f"  {f.name} ({size})")

        if not runtime.is_dry_run():
            _build_release_platform(
                platform="windows",
                ver=ver,
                ver_semver=version.render_semver(),
                output=output,
                release_id=release_id,
                version_min=version_min,
                version_max=version_max,
                root=root,
            )

    @build.command("release")
    @click.option(
        "--root",
        "-r",
        type=click.Path(path_type=Path),
        default=PROJECT_ROOT / "cache" / "releases",
        help="Release root directory (default: cache/releases).",
    )
    @click.option(
        "--fragments",
        required=True,
        multiple=True,
        type=click.Path(exists=True, path_type=Path),
        help="Fragment JSON files to merge (repeatable).",
    )
    @click.option(
        "--output",
        "-o",
        type=click.Path(path_type=Path),
        default=None,
        help="Output file path (default: <root>/merge/<ver>.json, or stdout for '-').",
    )
    def build_release_cmd(
        root: Path,
        fragments: list[Path],
        output: Path | None,
    ):
        """Merge release registry fragments into a single release JSON."""
        ProjectConfiguration.ensure_loaded()
        version = bootstrap.config.CONFIGURATION.version
        ver = version.render_full()

        _build_release_merge(list(fragments), ver, output, root)

    @build.command("list")
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
                            except Exception:  # noqa: BLE001
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
                            except Exception:  # noqa: BLE001
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
