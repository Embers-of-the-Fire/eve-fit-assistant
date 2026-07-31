"""Linux AppImage packaging via linuxdeploy + appimagetool.

Replaces the old appimage-builder recipe. linuxdeploy resolves and bundles the
shared-library dependencies of the Flutter Linux bundle; appimagetool packs the
resulting AppDir into an AppImage.

Two nix-specific concerns are handled explicitly:

- The bundle binary's PT_INTERP points into the nix store, so the glibc loader
  (and its NSS modules) is bundled and the custom AppRun launches the app
  through it. This also makes host graphics drivers work: their symbols are
  satisfied by the bundled (newer) glibc.
- linuxdeploy's excludelist skips libs that are still NEEDED by the binary
  (harfbuzz, fontconfig, X11 client libs, ...), so a fixpoint pass bundles
  every ldd-resolvable lib not yet in the AppDir, except the dlopen'd
  graphics-driver family, which must always come from the host.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess

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

# dlopen'd graphics-driver stack: always provided by the host, never bundled,
# so the AppImage stays portable and uses the host's GPU drivers.
_DRIVER_LIB_PATTERN = re.compile(
    r"^lib(GL|EGL|GLESv2|OpenGL|GLX|GLdispatch|vulkan|drm|gbm|va|va-drm|va-x11|nvidia|cuda)[.-]"
)


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


def _bundle_glibc_loader(appdir: Path, readelf: str) -> Path:
    """Copy the ELF interpreter (ld-linux) and glibc NSS modules into the AppDir."""
    interp = _elf_interpreter(appdir / "usr" / "bin" / BINARY_NAME, readelf)
    ld_so = appdir / "usr" / "lib" / interp.name
    for name in (interp.name, "libnss_files.so.2", "libnss_dns.so.2"):
        src = interp.parent / name
        if src.exists():
            shutil.copy2(src.resolve(), appdir / "usr" / "lib" / name)
    if not ld_so.exists():
        raise click.ClickException(f"Failed to bundle ELF interpreter: {interp}")
    return ld_so


def _bundle_missing_libs(appdir: Path, ld_so: Path, search_path: str) -> None:
    """Fixpoint: bundle every resolvable lib not yet in the AppDir.

    Skips the dlopen'd graphics-driver family, which must come from the host.
    """
    usr_lib = appdir / "usr" / "lib"
    targets = [appdir / "usr" / "bin" / BINARY_NAME]
    targets.extend(sorted((appdir / "usr" / "bin" / "lib").glob("*.so*")))
    lib_path = f"{appdir}/usr/bin/lib:{usr_lib}:{search_path}"
    while True:
        missing: dict[str, Path] = {}
        for f in targets + sorted(usr_lib.glob("*.so*")):
            out = subprocess.run(
                [str(ld_so), "--library-path", lib_path, "--list", str(f)],
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                check=False,
            )
            for line in out.stdout.splitlines():
                parts = line.split()
                if (
                    len(parts) >= 3
                    and parts[2].startswith("/")
                    and not parts[2].startswith(str(appdir))
                ):
                    missing.setdefault(parts[0], Path(parts[2]))
        added = False
        for name, src in missing.items():
            if _DRIVER_LIB_PATTERN.match(name) or (usr_lib / name).exists():
                continue
            debug(f"Bundling additional library: {src}")
            shutil.copy2(src.resolve(), usr_lib / name)
            added = True
        if not added:
            break


def build_appimage(
    *,
    bundle_dir: Path,
    work_dir: Path,
    output_dir: Path,
    version: ProjectVersion,
    linuxdeploy: str,
    appimagetool: str,
    ldd: str,
    readelf: str,
    dry_run: bool,
) -> None:
    """Assemble the AppDir with linuxdeploy and pack it with appimagetool."""
    exe = bundle_dir / BINARY_NAME
    if not exe.exists():
        raise click.ClickException(f"Flutter Linux bundle binary not found: {exe}")
    icon_src = PROJECT_ROOT / "logo" / "logo-256.png"
    if not icon_src.exists():
        raise click.ClickException(f"AppImage icon not found: {icon_src}")

    appdir = work_dir / "AppDir"
    support_dir = work_dir / "support"
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

    if dry_run:
        return

    ld_so = _bundle_glibc_loader(appdir, readelf)
    _bundle_missing_libs(appdir, ld_so, ":".join(search_dirs))

    # Drop duplicates of bundle libs that linuxdeploy redeployed into usr/lib.
    for f in (appdir / "usr" / "bin" / "lib").glob("*.so*"):
        (appdir / "usr" / "lib" / f.name).unlink(missing_ok=True)

    # Flutter's GTK embedder derives the data/ and lib/ paths relative to
    # /proc/self/exe; under the bundled ld.so that resolves to the loader
    # itself (usr/lib), so bridge it back to the real bundle layout.
    (appdir / "usr" / "lib" / "lib").symlink_to("../bin/lib")
    (appdir / "usr" / "lib" / "data").symlink_to("../bin/data")

    ver = version.render_full()
    dst = output_dir / f"{ver}-linux.AppImage"
    pack_env = dict(env)
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
    info(f"Packed AppImage: {dst}")
