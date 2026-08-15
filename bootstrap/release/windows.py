"""Windows release packaging: native (raw bundle) zip and MSI installer variants.

Native variant: the raw Flutter Windows release bundle zipped as-is.

Installer variant: a per-user, multi-language (en-US base + embedded language
transforms) MSI built with the WiX v6 toolset from
distro/windows/installer/Package.wxs; the release bundle is harvested via
WiX wildcard harvesting (<Files Include="...\\**" />). Each additional culture
is built separately, diffed against the base MSI with
`wix msi transform -t language`, and embedded as a substorage named by LCID
(Windows Installer auto-applies it for matching UI languages).
"""

from __future__ import annotations

import ctypes
import tempfile
import uuid
import zipfile

from pathlib import Path
from typing import TYPE_CHECKING

import click

from bootstrap.constant import EFA_APP_ROOT
from bootstrap.constant import PROJECT_ROOT
from bootstrap.log import info
from bootstrap.release.msi import MSIHANDLE
from bootstrap.release.msi import Msi
from bootstrap.utils import execute_command


if TYPE_CHECKING:
    from bootstrap.config import ProjectVersion


BINARY_NAME = "eve_fit_assistant"

BUNDLE_DIR = EFA_APP_ROOT / "build" / "windows" / "x64" / "runner" / "Release"
_PACKAGING_DIR = PROJECT_ROOT / "distro" / "windows" / "installer"

_WIX_UI_EXTENSION = "WixToolset.UI.wixext"

_MSI_ARCH = "x64"
# (culture, LCID) pairs; the first entry is the MSI base language.
_MSI_CULTURES: tuple[tuple[str, int], ...] = (("en-US", 1033), ("zh-CN", 2052))

# UpgradeCode derivation inputs (UUIDv5, RFC 4122 §4.3). The resulting GUID is
# the MSI product-family identity: it must NEVER change between releases, so
# these inputs must never change either.
_UPGRADE_CODE_NAMESPACE = uuid.NAMESPACE_URL
_UPGRADE_CODE_NAME = "https://efa-tech.dev/msi/upgrade-code"

_MSIMODIFY_INSERT = 1
_VT_LPSTR = 30
_PID_TEMPLATE = 7


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

    Prerelease labels cannot appear in MSI versions, and Windows Installer
    compares only the first three fields, so same-triple prerelease upgrades
    rely on MajorUpgrade AllowSameVersionUpgrades in Package.wxs. The fourth
    field is display-only (ARP) to distinguish builds.
    """
    return f"{version.major}.{version.minor}.{version.patch}.{version.build}"


def upgrade_code() -> str:
    """Derive the MSI UpgradeCode as a deterministic UUIDv5.

    Computed as uuid5(NAMESPACE_URL, _UPGRADE_CODE_NAME) (RFC 4122 §4.3, SHA-1
    over namespace + name). Being deterministic, it is stable across builds and
    machines while remaining unique to this product family. Do not change the
    inputs: the UpgradeCode links every release of the MSI for MajorUpgrade.
    """
    return str(uuid.uuid5(_UPGRADE_CODE_NAMESPACE, _UPGRADE_CODE_NAME)).upper()


def pack_msi(
    *, bundle_dir: Path, output_dir: Path, version: ProjectVersion, wix: str, dry_run: bool
) -> Path:
    """Build the per-user multi-language MSI installer from the WiX source."""
    wxs = _PACKAGING_DIR / "Package.wxs"
    if not wxs.exists():
        raise click.ClickException(f"WiX source file not found: {wxs}")
    for culture, _ in _MSI_CULTURES:
        wxl = _wxl_path(culture)
        if not wxl.exists():
            raise click.ClickException(f"WiX localization file not found: {wxl}")
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

    base_culture, _ = _MSI_CULTURES[0]
    extra_cultures = _MSI_CULTURES[1:]

    execute_command(
        _build_msi_args(wix, wxs, bundle_dir, version, base_culture, dst),
        f"BUILDING MSI INSTALLER ({base_culture})",
        dry_run,
    )
    if dry_run:
        for culture, lcid in extra_cultures:
            info(f"[DRY-RUN] Would embed {culture} language transform (LCID {lcid}) into: {dst}")
        info(f"[DRY-RUN] Would build MSI installer: {dst}")
        return dst

    with tempfile.TemporaryDirectory(prefix="efa-msi-") as tmp:
        tmp_dir = Path(tmp)
        for culture, lcid in extra_cultures:
            localized = tmp_dir / f"{culture}.msi"
            mst = tmp_dir / f"{lcid}.mst"
            execute_command(
                _build_msi_args(wix, wxs, bundle_dir, version, culture, localized),
                f"BUILDING MSI INSTALLER ({culture})",
                dry_run,
            )
            _sync_product_code(dst, localized)
            execute_command(
                [
                    wix,
                    "msi",
                    "transform",
                    "-t",
                    "language",
                    str(dst),
                    str(localized),
                    "-o",
                    str(mst),
                ],
                f"CREATING {culture} LANGUAGE TRANSFORM",
                dry_run,
            )
            _embed_language_transform(dst, mst, lcid)
            info(f"Embedded {culture} language transform (LCID {lcid}) into: {dst}")

    info(f"Built MSI installer: {dst}")
    return dst


def _wxl_path(culture: str) -> Path:
    return _PACKAGING_DIR / f"Package.{culture.lower()}.wxl"


def _build_msi_args(
    wix: str, wxs: Path, bundle_dir: Path, version: ProjectVersion, culture: str, out: Path
) -> list[str]:
    return [
        wix,
        "build",
        str(wxs),
        "-d",
        f"SourceDir={bundle_dir}",
        "-d",
        f"MsiVersion={msi_version(version)}",
        "-d",
        f"UpgradeCode={upgrade_code()}",
        "-d",
        f"RepoRoot={PROJECT_ROOT}",
        "-d",
        f"AppRoot={EFA_APP_ROOT}",
        "-arch",
        _MSI_ARCH,
        "-culture",
        culture,
        "-loc",
        str(_wxl_path(culture)),
        "-ext",
        _WIX_UI_EXTENSION,
        "-pdbtype",
        "none",
        "-o",
        str(out),
    ]


def _read_product_code(msi: Msi, msi_path: Path) -> str:
    from ctypes import wintypes

    query = "SELECT `Value` FROM `Property` WHERE `Property`='ProductCode'"
    with (
        msi.open_database(msi_path) as db,
        msi.open_view(db, query, what=f"ProductCode in {msi_path}") as view,
    ):
        rc = msi.dll.MsiViewExecute(view, 0)
        if rc != 0:
            raise click.ClickException(f"Reading ProductCode failed (error {rc}) for {msi_path}")
        with msi.fetch_record(view, what=f"ProductCode in {msi_path}") as record:
            size = wintypes.DWORD(64)
            buffer = ctypes.create_unicode_buffer(64)
            rc = msi.dll.MsiRecordGetStringW(record, 1, buffer, ctypes.byref(size))
            if rc != 0:
                raise click.ClickException(
                    f"Reading ProductCode failed (error {rc}) for {msi_path}"
                )
            return buffer.value


def _sync_product_code(base_msi: Path, localized_msi: Path) -> None:
    """Copy the base MSI's ProductCode into a localized build.

    WiX auto-generates a random ProductCode per build, but the language
    transform must keep both builds as the same product instance.
    """
    msi = Msi()
    code = _read_product_code(msi, base_msi)
    with msi.open_database(localized_msi, transact=True) as db:
        query = "UPDATE `Property` SET `Value`=? WHERE `Property`='ProductCode'"
        with msi.open_view(db, query, what=f"ProductCode in {localized_msi}") as view:
            with msi.create_record(1) as record:
                rc = msi.dll.MsiRecordSetStringW(record, 1, code)
                if rc == 0:
                    rc = msi.dll.MsiViewExecute(view, record)
            if rc != 0:
                raise click.ClickException(
                    f"Syncing ProductCode failed (error {rc}) for {localized_msi}"
                )
        rc = msi.dll.MsiDatabaseCommit(db)
        if rc != 0:
            raise click.ClickException(
                f"Syncing ProductCode failed (error {rc}) for {localized_msi}"
            )


def _embed_language_transform(msi_path: Path, mst_path: Path, lcid: int) -> None:
    """Embed a language transform into an MSI as a substorage named by LCID.

    Also appends the LCID to the Template Summary language list so Windows
    Installer auto-applies the transform for matching UI languages.
    """
    msi = Msi()
    with msi.open_database(msi_path, transact=True) as db:
        _insert_substorage(msi, db, mst_path, str(lcid))
        _register_template_language(msi, db, lcid)
        rc = msi.dll.MsiDatabaseCommit(db)
        if rc != 0:
            raise click.ClickException(f"MsiDatabaseCommit failed (error {rc}) for {msi_path}")


def _insert_substorage(msi: Msi, db: MSIHANDLE, mst_path: Path, name: str) -> None:
    with (
        msi.open_view(db, "SELECT `Name`, `Data` FROM `_Storages`", what="_Storages") as view,
        msi.create_record(2) as record,
    ):
        rc = msi.dll.MsiRecordSetStringW(record, 1, name)
        if rc == 0:
            rc = msi.dll.MsiRecordSetStreamW(record, 2, str(mst_path))
        if rc != 0:
            raise click.ClickException(f"MsiRecordSetStream failed (error {rc}) for {mst_path}")
        rc = msi.dll.MsiViewExecute(view, 0)
        if rc == 0:
            rc = msi.dll.MsiViewModify(view, _MSIMODIFY_INSERT, record)
        if rc != 0:
            raise click.ClickException(
                f"Embedding substorage '{name}' failed (error {rc}) for {mst_path}"
            )


def _append_lcid(template: str, lcid: int) -> str:
    platform, _, languages = template.partition(";")
    language_ids = [lang for lang in languages.split(",") if lang]
    if str(lcid) not in language_ids:
        language_ids.append(str(lcid))
    return f"{platform};{','.join(language_ids)}"


def _register_template_language(msi: Msi, db: MSIHANDLE, lcid: int) -> None:
    from ctypes import wintypes

    with msi.summary_info(db, 1) as summary:
        prop_type = wintypes.UINT()
        int_value = wintypes.INT()
        file_time = wintypes.FILETIME()
        size = wintypes.DWORD(0)
        msi.dll.MsiSummaryInfoGetPropertyW(
            summary,
            _PID_TEMPLATE,
            ctypes.byref(prop_type),
            ctypes.byref(int_value),
            ctypes.byref(file_time),
            None,
            ctypes.byref(size),
        )
        buffer = ctypes.create_unicode_buffer(size.value + 1)
        size = wintypes.DWORD(size.value + 1)
        rc = msi.dll.MsiSummaryInfoGetPropertyW(
            summary,
            _PID_TEMPLATE,
            ctypes.byref(prop_type),
            ctypes.byref(int_value),
            ctypes.byref(file_time),
            buffer,
            ctypes.byref(size),
        )
        if rc != 0:
            raise click.ClickException(f"MsiSummaryInfoGetProperty failed (error {rc})")
        template = _append_lcid(buffer.value, lcid)
        rc = msi.dll.MsiSummaryInfoSetPropertyW(
            summary, _PID_TEMPLATE, _VT_LPSTR, 0, None, template
        )
        if rc == 0:
            rc = msi.dll.MsiSummaryInfoPersist(summary)
        if rc != 0:
            raise click.ClickException(f"Updating template summary failed (error {rc})")
