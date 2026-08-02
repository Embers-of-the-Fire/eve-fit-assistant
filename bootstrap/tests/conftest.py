from __future__ import annotations

import asyncio
import inspect
import sys

from pathlib import Path

import pytest


@pytest.fixture(scope="session")
def project_root() -> Path:
    return Path(__file__).resolve().parent.parent.parent


def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    if sys.platform != "win32":
        return
    loopback_only = pytest.mark.allow_hosts(["127.0.0.1", "::1"])
    for item in items:
        obj = getattr(item, "obj", None)
        if asyncio.iscoroutinefunction(obj) or inspect.isasyncgenfunction(obj):
            item.add_marker(loopback_only)
