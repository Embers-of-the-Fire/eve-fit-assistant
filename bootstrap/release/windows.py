"""Windows release packaging: native (raw bundle) zip and MSI installer variants.

Native variant: the raw Flutter Windows release bundle zipped as-is.

Installer variant: a per-user MSI built with the WiX v6 toolset from
distro/windows/installer/Package.wxs; the release bundle is harvested via
WiX wildcard harvesting (<Files Include="...\\**" />).
"""

from __future__ import annotations

import zipfile

from pathlib import Path
from typing import TYPE_CHECKING

import click

from bootstrap.constant import PROJECT_ROOT
from bootstrap.log import info
from bootstrap.utils import execute_command


if TYPE_CHECKING:
    from bootstrap.config import ProjectVersion


APP_NAME = "EFA"
BINARY_NAME = "eve_fit_assistant"

BUNDLE_DIR = PROJECT_ROOT / "build" / "windows" / "x64" / "runner" / "Release"
_PACKAGING_DIR = PROJECT_ROOT / "distro" / "windows" / "installer"

_WIX_UI_EXTENSION = "WixToolset.UI.wixext"


def validate_bundle(bundle_dir: Path) -> None:
    """Ensure the Flutter Windows release bundle contains the expected files."""
    for name in (f"{BINARY_NAME}.exe", "flutter_windows.dll"):
        f = bundle_dir / name
        if not f.exists():
            raise click.ClickException(f"Flutter Windows bundle file not found: {f}")


def _zip_tree(src_dir: Path, root_name: str, dst: Path) -> None:
    """Zip the contents of src_dir under a top-level root_name folder."""
    with zipfile.ZipFile(dst, "w", zipfile.ZIP_DEFLATED) as zf:
        for path in sorted(src_dir.rglob("*")):
            if path.is_dir():
                continue
            zf.write(path, str(Path(root_name) / path.relative_to(src_dir)))


def pack_native_zip(
    *, bundle_dir: Path, output_dir: Path, version: ProjectVersion, dry_run: bool
) -> Path:
    """Pack the raw Flutter Windows release bundle into a zip archive as-is."""
    ver = version.render_full()
    dst = output_dir / f"{ver}-windows-native.zip"
    if dry_run:
        info(f"[DRY-RUN] Would pack native zip archive: {dst}")
        return dst
    exe = bundle_dir / f"{BINARY_NAME}.exe"
    if not exe.exists():
        raise click.ClickException(f"Flutter Windows bundle binary not found: {exe}")
    _zip_tree(bundle_dir, "eve-fit-assistant", dst)
    info(f"Packed native zip archive: {dst}")
    return dst


def msi_version(version: ProjectVersion) -> str:
    """Map the project version to MSI's strictly numeric four-part version.

    Prerelease labels cannot appear in MSI versions, so the build number
    distinguishes builds that share the same major.minor.patch triple.
    """
    return f"{version.major}.{version.minor}.{version.patch}.{version.build}"


def pack_msi(
    *, bundle_dir: Path, output_dir: Path, version: ProjectVersion, wix: str, dry_run: bool
) -> Path:
    """Build the per-user MSI installer from the WiX source with the wix CLI."""
    wxs = _PACKAGING_DIR / "Package.wxs"
    if not wxs.exists():
        raise click.ClickException(f"WiX source file not found: {wxs}")
    ver = version.render_full()
    dst = output_dir / f"{ver}-windows-setup.msi"

    extensions = execute_command(
        [wix, "extension", "list", "-g"], "LISTING WIX EXTENSIONS", dry_run, capture_stdout=True
    )
    if _WIX_UI_EXTENSION not in extensions:
        execute_command(
            [wix, "extension", "add", "-g", _WIX_UI_EXTENSION],
            "ADDING WIX UI EXTENSION",
            dry_run,
        )

    execute_command(
        [
            wix,
            "build",
            str(wxs),
            "-d",
            f"SourceDir={bundle_dir}",
            "-d",
            f"MsiVersion={msi_version(version)}",
            "-d",
            f"RepoRoot={PROJECT_ROOT}",
            "-ext",
            _WIX_UI_EXTENSION,
            "-pdbtype",
            "none",
            "-o",
            str(dst),
        ],
        "BUILDING MSI INSTALLER",
        dry_run,
    )
    if dry_run:
        info(f"[DRY-RUN] Would build MSI installer: {dst}")
    else:
        info(f"Built MSI installer: {dst}")
    return dst
