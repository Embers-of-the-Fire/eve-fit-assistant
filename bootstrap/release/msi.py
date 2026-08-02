"""Shared ctypes bindings for the Windows Installer API (msi.dll).

Every msi.dll function used by the release pipeline has its argtypes/restype
declared here so bad arguments fail at call time, and every MSIHANDLE
acquisition (database, view, record, summary info) is wrapped in a
contextlib context manager so handles are closed on all return and error
paths.
"""

from __future__ import annotations

import contextlib
import ctypes

from typing import TYPE_CHECKING

import click


if TYPE_CHECKING:
    from collections.abc import Iterator
    from pathlib import Path


MSIHANDLE = ctypes.c_ulong

ERROR_SUCCESS = 0

# MsiOpenDatabaseW szPersist sentinels (LPCWSTR-cast constants in C).
MSIDBOPEN_READONLY = 0
MSIDBOPEN_TRANSACT = 1


class Msi:
    """Prototype-declared msi.dll handle with RAII wrappers for MSIHANDLEs."""

    def __init__(self) -> None:
        from ctypes import wintypes

        dll = ctypes.WinDLL("msi")

        dll.MsiOpenDatabaseW.argtypes = [
            wintypes.LPCWSTR,
            ctypes.c_void_p,  # szPersist: LPCWSTR path or MSIDBOPEN_* sentinel
            ctypes.POINTER(MSIHANDLE),
        ]
        dll.MsiOpenDatabaseW.restype = wintypes.UINT

        dll.MsiDatabaseOpenViewW.argtypes = [
            MSIHANDLE,
            wintypes.LPCWSTR,
            ctypes.POINTER(MSIHANDLE),
        ]
        dll.MsiDatabaseOpenViewW.restype = wintypes.UINT

        dll.MsiViewExecute.argtypes = [MSIHANDLE, MSIHANDLE]
        dll.MsiViewExecute.restype = wintypes.UINT

        dll.MsiViewFetch.argtypes = [MSIHANDLE, ctypes.POINTER(MSIHANDLE)]
        dll.MsiViewFetch.restype = wintypes.UINT

        dll.MsiViewModify.argtypes = [MSIHANDLE, ctypes.c_int, MSIHANDLE]
        dll.MsiViewModify.restype = wintypes.UINT

        dll.MsiViewClose.argtypes = [MSIHANDLE]
        dll.MsiViewClose.restype = wintypes.UINT

        dll.MsiDatabaseCommit.argtypes = [MSIHANDLE]
        dll.MsiDatabaseCommit.restype = wintypes.UINT

        dll.MsiCreateRecord.argtypes = [wintypes.UINT]
        dll.MsiCreateRecord.restype = MSIHANDLE

        dll.MsiRecordGetStringW.argtypes = [
            MSIHANDLE,
            wintypes.UINT,
            wintypes.LPWSTR,
            ctypes.POINTER(wintypes.DWORD),
        ]
        dll.MsiRecordGetStringW.restype = wintypes.UINT

        dll.MsiRecordSetStringW.argtypes = [MSIHANDLE, wintypes.UINT, wintypes.LPCWSTR]
        dll.MsiRecordSetStringW.restype = wintypes.UINT

        dll.MsiRecordSetStreamW.argtypes = [MSIHANDLE, wintypes.UINT, wintypes.LPCWSTR]
        dll.MsiRecordSetStreamW.restype = wintypes.UINT

        dll.MsiGetSummaryInformationW.argtypes = [
            MSIHANDLE,
            wintypes.LPCWSTR,
            wintypes.UINT,
            ctypes.POINTER(MSIHANDLE),
        ]
        dll.MsiGetSummaryInformationW.restype = wintypes.UINT

        dll.MsiSummaryInfoGetPropertyW.argtypes = [
            MSIHANDLE,
            wintypes.UINT,
            ctypes.POINTER(wintypes.UINT),
            ctypes.POINTER(wintypes.INT),
            ctypes.POINTER(wintypes.FILETIME),
            wintypes.LPWSTR,
            ctypes.POINTER(wintypes.DWORD),
        ]
        dll.MsiSummaryInfoGetPropertyW.restype = wintypes.UINT

        dll.MsiSummaryInfoSetPropertyW.argtypes = [
            MSIHANDLE,
            wintypes.UINT,
            wintypes.UINT,
            wintypes.INT,
            ctypes.POINTER(wintypes.FILETIME),
            wintypes.LPCWSTR,
        ]
        dll.MsiSummaryInfoSetPropertyW.restype = wintypes.UINT

        dll.MsiSummaryInfoPersist.argtypes = [MSIHANDLE]
        dll.MsiSummaryInfoPersist.restype = wintypes.UINT

        dll.MsiCloseHandle.argtypes = [MSIHANDLE]
        dll.MsiCloseHandle.restype = wintypes.UINT

        self.dll = dll

    @contextlib.contextmanager
    def open_database(self, path: Path, *, transact: bool = False) -> Iterator[MSIHANDLE]:
        """Open an MSI database, closing the handle when the block exits."""
        db = MSIHANDLE()
        persist = MSIDBOPEN_TRANSACT if transact else MSIDBOPEN_READONLY
        rc = self.dll.MsiOpenDatabaseW(str(path), persist, ctypes.byref(db))
        if rc != ERROR_SUCCESS:
            raise click.ClickException(f"MsiOpenDatabase failed (error {rc}) for {path}")
        try:
            yield db
        finally:
            self.dll.MsiCloseHandle(db)

    @contextlib.contextmanager
    def open_view(self, db: MSIHANDLE, query: str, *, what: str) -> Iterator[MSIHANDLE]:
        """Open a database view, closing the view and handle on exit."""
        view = MSIHANDLE()
        rc = self.dll.MsiDatabaseOpenViewW(db, query, ctypes.byref(view))
        if rc != ERROR_SUCCESS:
            raise click.ClickException(f"MsiDatabaseOpenView failed (error {rc}) for {what}")
        try:
            yield view
        finally:
            self.dll.MsiViewClose(view)
            self.dll.MsiCloseHandle(view)

    @contextlib.contextmanager
    def fetch_record(self, view: MSIHANDLE, *, what: str) -> Iterator[MSIHANDLE]:
        """Fetch the next record of an executed view, closing it on exit."""
        record = MSIHANDLE()
        rc = self.dll.MsiViewFetch(view, ctypes.byref(record))
        if rc != ERROR_SUCCESS:
            raise click.ClickException(f"MsiViewFetch failed (error {rc}) for {what}")
        try:
            yield record
        finally:
            self.dll.MsiCloseHandle(record)

    @contextlib.contextmanager
    def create_record(self, field_count: int) -> Iterator[int]:
        """Create a record with field_count fields, closing it on exit."""
        record: int = self.dll.MsiCreateRecord(field_count)
        if record == 0:
            raise click.ClickException(f"MsiCreateRecord failed for {field_count} fields")
        try:
            yield record
        finally:
            self.dll.MsiCloseHandle(record)

    @contextlib.contextmanager
    def summary_info(self, db: MSIHANDLE, update_count: int) -> Iterator[MSIHANDLE]:
        """Open the summary information stream, closing the handle on exit."""
        summary = MSIHANDLE()
        rc = self.dll.MsiGetSummaryInformationW(db, None, update_count, ctypes.byref(summary))
        if rc != ERROR_SUCCESS:
            raise click.ClickException(f"MsiGetSummaryInformation failed (error {rc})")
        try:
            yield summary
        finally:
            self.dll.MsiCloseHandle(summary)
