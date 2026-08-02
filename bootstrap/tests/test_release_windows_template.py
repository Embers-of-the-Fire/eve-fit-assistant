"""Tests for the MSI template summary-string helpers in bootstrap.release.windows."""

from __future__ import annotations

import pytest

from bootstrap.release.windows import _append_lcid


@pytest.mark.parametrize(
    ("template", "lcid", "expected"),
    [
        ("x64;1033", 2052, "x64;1033,2052"),
        ("x64;", 1033, "x64;1033"),
        ("x64", 2052, "x64;2052"),
        ("x64;1033,2052", 2052, "x64;1033,2052"),
        ("x64;1033,", 2052, "x64;1033,2052"),
        (";1033", 2052, ";1033,2052"),
    ],
)
def test_append_lcid(template: str, lcid: int, expected: str) -> None:
    assert _append_lcid(template, lcid) == expected
