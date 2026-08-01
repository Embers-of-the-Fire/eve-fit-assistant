"""Linux release packaging: AppImage and native (raw bundle) variants.

AppImage variant (replaces the old appimage-builder recipe): linuxdeploy
resolves and bundles the shared-library dependencies of the Flutter Linux
bundle; the resulting AppDir is packed into an AppImage with appimagetool.

Native variant: the raw Flutter Linux release bundle zipped as-is.

The bundle binary's PT_INTERP points into the nix store, so the glibc loader
(and its NSS modules) is bundled and the custom AppRun launches the app
through it. This also makes host graphics drivers work: their symbols are
satisfied by the bundled (newer) glibc. Every other library (fontconfig,
harfbuzz, X11 client libs, libstdc++, ...) is intentionally left to the
host per linuxdeploy's excludelist; graphics drivers are always resolved
from the host so the AppImage stays portable.
"""

from __future__ import annotations

import os
import re
import shutil
import stat
import subprocess
import zipfile

from pathlib import Path
from typing import TYPE_CHECKING

import click

from bootstrap.constant import PROJECT_ROOT
from bootstrap.log import debug
from bootstrap.log import info
from bootstrap.utils import execute_command


if TYPE_CHECKING:
    from bootstrap.config import ProjectVersion


APP_NAME = "EFA"
BINARY_NAME = "eve_fit_assistant"

_GITHUB_REPO = "Embers-of-the-Fire/eve-fit-assistant"

_PACKAGING_DIR = PROJECT_ROOT / "distro" / "linux" / "appimage"


def _run_capture(cmd: list[str], *, env: dict[str, str] | None = None) -> str:
    debug("Executing command: " + " ".join(cmd))
    out = subprocess.run(
        cmd,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
        env=env,
    )
    if out.returncode != 0:
        raise click.ClickException(
            f"Command failed [{out.returncode}]: {' '.join(cmd)}\n{out.stderr.strip()}"
        )
    return out.stdout


def _elf_interpreter(path: Path, readelf: str) -> Path:
    match = re.search(r"interpreter: (/[^\]]+)", _run_capture([readelf, "-l", str(path)]))
    if not match:
        raise click.ClickException(f"Could not determine ELF interpreter of {path}")
    return Path(match.group(1))


def _resolved_lib_dirs(ldd: str, files: list[Path]) -> list[str]:
    dirs: set[str] = set()
    for f in files:
        for line in _run_capture([ldd, str(f)]).splitlines():
            parts = line.split()
            if len(parts) >= 3 and parts[2].startswith("/"):
                dirs.add(str(Path(parts[2]).parent))
    return sorted(dirs)


def _bundle_glibc_loader(appdir: Path, readelf: str) -> None:
    """Copy the ELF interpreter (ld-linux) and glibc NSS modules into the AppDir."""
    interp = _elf_interpreter(appdir / "usr" / "bin" / BINARY_NAME, readelf)
    ld_so = appdir / "usr" / "lib" / interp.name
    for name in (interp.name, "libnss_files.so.2", "libnss_dns.so.2"):
        src = interp.parent / name
        if src.exists():
            shutil.copy2(src.resolve(), appdir / "usr" / "lib" / name)
    if not ld_so.exists():
        raise click.ClickException(f"Failed to bundle ELF interpreter: {interp}")


def assemble_appdir(
    *,
    bundle_dir: Path,
    work_dir: Path,
    linuxdeploy: str,
    ldd: str,
    readelf: str,
    dry_run: bool,
) -> Path:
    """Assemble the portable AppDir with linuxdeploy and the bundled loader.

    The resulting AppDir bundles the glibc loader and NSS modules and can be
    launched via its AppRun; all other libraries are resolved from the host
    at runtime. It is the payload of the AppImage variant.
    """
    exe = bundle_dir / BINARY_NAME
    if not exe.exists():
        raise click.ClickException(f"Flutter Linux bundle binary not found: {exe}")
    icon_src = PROJECT_ROOT / "logo" / "logo-256.png"
    if not icon_src.exists():
        raise click.ClickException(f"AppImage icon not found: {icon_src}")

    appdir = work_dir / "AppDir"
    support_dir = work_dir / "support"
    if dry_run:
        info(f"[DRY-RUN] Would assemble AppDir: {appdir}")
        return appdir

    shutil.rmtree(appdir, ignore_errors=True)
    shutil.rmtree(support_dir, ignore_errors=True)
    (appdir / "usr" / "bin").mkdir(parents=True)
    support_dir.mkdir(parents=True)

    shutil.copy2(exe, appdir / "usr" / "bin" / BINARY_NAME)
    shutil.copytree(bundle_dir / "lib", appdir / "usr" / "bin" / "lib")
    shutil.copytree(bundle_dir / "data", appdir / "usr" / "bin" / "data")

    # Static packaging assets: desktop entry, AppRun, and a standard-sized
    # icon (linuxdeploy requires the icon basename to match the desktop
    # entry's Icon field).
    desktop_file = _PACKAGING_DIR / f"{APP_NAME.lower()}.desktop"
    app_run = _PACKAGING_DIR / "AppRun"
    icon_file = support_dir / "logo.png"
    for f in (desktop_file, app_run):
        if not f.exists():
            raise click.ClickException(f"Packaging asset not found: {f}")
    shutil.copy2(icon_src, icon_file)

    # Seed LD_LIBRARY_PATH with every dir ldd resolves for the bundle, so
    # linuxdeploy can find every NEEDED lib even after it rewrites rpaths.
    search_dirs = _resolved_lib_dirs(ldd, [exe, *sorted((bundle_dir / "lib").glob("*.so*"))])
    env = dict(os.environ)
    env["LD_LIBRARY_PATH"] = ":".join(
        [f"{appdir}/usr/bin/lib", *search_dirs, env.get("LD_LIBRARY_PATH", "")]
    ).rstrip(":")

    execute_command(
        [
            linuxdeploy,
            "--appdir",
            str(appdir),
            "--executable",
            str(appdir / "usr" / "bin" / BINARY_NAME),
            "--custom-apprun",
            str(app_run),
            "--desktop-file",
            str(desktop_file),
            "--icon-file",
            str(icon_file),
        ],
        "DEPLOYING DEPENDENCIES (LINUXDEPLOY)",
        dry_run,
        env=env,
    )

    _bundle_glibc_loader(appdir, readelf)

    # Drop duplicates of bundle libs that linuxdeploy redeployed into usr/lib.
    for f in (appdir / "usr" / "bin" / "lib").glob("*.so*"):
        (appdir / "usr" / "lib" / f.name).unlink(missing_ok=True)

    # Flutter's GTK embedder derives the data/ and lib/ paths relative to
    # /proc/self/exe; under the bundled ld.so that resolves to the loader
    # itself (usr/lib), so bridge it back to the real bundle layout.
    (appdir / "usr" / "lib" / "lib").symlink_to("../bin/lib")
    (appdir / "usr" / "lib" / "data").symlink_to("../bin/data")
    return appdir


def pack_appimage(
    *,
    appdir: Path,
    output_dir: Path,
    version: ProjectVersion,
    appimagetool: str,
    dry_run: bool,
) -> Path:
    """Pack an assembled AppDir into an AppImage with appimagetool."""
    ver = version.render_full()
    dst = output_dir / f"{ver}-linux.AppImage"
    pack_env = dict(os.environ)
    pack_env["VERSION"] = version.render_semver()
    pack_env["ARCH"] = "x86_64"
    execute_command(
        [
            appimagetool,
            "--updateinformation",
            f"gh-releases-zsync|{_GITHUB_REPO}|latest|*-linux.AppImage.zsync",
            str(appdir),
            str(dst),
        ],
        "PACKING APPIMAGE",
        dry_run,
        cwd=output_dir,
        env=pack_env,
    )
    if dry_run:
        info(f"[DRY-RUN] Would pack AppImage: {dst}")
    else:
        info(f"Packed AppImage: {dst}")
    return dst


def _zip_tree(src_dir: Path, root_name: str, dst: Path) -> None:
    """Zip the contents of src_dir under a top-level root_name folder.

    File permission bits and symlinks are preserved so the archive stays
    directly runnable after extraction.
    """
    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(src_dir.rglob("*")):
            arcname = str(Path(root_name) / path.relative_to(src_dir))
            if path.is_symlink():
                entry = zipfile.ZipInfo(arcname)
                entry.create_system = 3
                entry.external_attr = (stat.S_IFLNK | 0o777) << 16
                zf.writestr(entry, os.readlink(path))
            elif path.is_dir():
                entry = zipfile.ZipInfo(arcname + "/")
                entry.create_system = 3
                entry.external_attr = (stat.S_IFDIR | path.stat().st_mode & 0xFFFF) << 16
                zf.writestr(entry, b"")
            else:
                zf.write(path, arcname)


def pack_native_zip(
    *, bundle_dir: Path, output_dir: Path, version: ProjectVersion, dry_run: bool
) -> Path:
    """Pack the raw Flutter Linux release bundle into a zip archive as-is."""
    exe = bundle_dir / BINARY_NAME
    if not exe.exists():
        raise click.ClickException(f"Flutter Linux bundle binary not found: {exe}")
    ver = version.render_full()
    dst = output_dir / f"{ver}-linux-native.zip"
    if dry_run:
        info(f"[DRY-RUN] Would pack native zip archive: {dst}")
        return dst
    _zip_tree(bundle_dir, "eve-fit-assistant", dst)
    info(f"Packed native zip archive: {dst}")
    return dst
