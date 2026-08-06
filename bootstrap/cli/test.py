from __future__ import annotations

import os
import re
import shutil

import click

from colorama import Fore
from colorama import Style

from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.constant import PROJECT_ROOT
from bootstrap.utils import get_command


_VM_ONLY_TEST = re.compile(r"@TestOn\(\s*[\"']vm[\"']\s*\)")

_WEB_SQLITE_ASSETS = ("db_worker.js", "sqlite3.wasm")


def _collect_web_test_suites() -> list[str]:
    """Collect test suites compilable for the web platform.

    The web test pipeline compiles every selected suite, so VM-only suites
    (which may import ``dart:ffi``/``dart:io``-only libraries) must be
    excluded from the selection instead of relying on ``@TestOn`` filtering.
    """
    test_root = PROJECT_ROOT / "test"
    suites: list[str] = []
    for path in sorted(test_root.rglob("*_test.dart")):
        header = path.read_text(encoding="utf-8").splitlines()[:30]
        if any(_VM_ONLY_TEST.search(line) for line in header):
            continue
        suites.append(str(path.relative_to(PROJECT_ROOT)))
    return suites


def _stage_web_sqlite_assets() -> None:
    """Copy the sqlite web worker assets into the served ``test/`` tree.

    The flutter web test server only serves the project's ``test/`` directory
    (at the server root), so the sqlite3 worker bundle shipped under
    ``web/sqlite/`` for production builds is mirrored to ``test/web/sqlite/``
    where web tests can fetch it.
    """
    source = PROJECT_ROOT / "web" / "sqlite"
    target = PROJECT_ROOT / "test" / "web" / "sqlite"
    target.mkdir(parents=True, exist_ok=True)
    for name in _WEB_SQLITE_ASSETS:
        shutil.copy2(source / name, target / name)


def register_test_commands(cli_group: click.Group) -> None:
    @cli_group.group()
    def test():
        """Run project test suites."""

    @test.command("python")
    def test_python():
        """Run Python tests via pytest."""
        uv = get_command("uv")
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
            + "uv run pytest bootstrap/tests/"
        )
        runtime.execute([uv, "run", "pytest", "bootstrap/tests/"], "PYTEST OUTPUT")

    @test.command("dart")
    def test_dart():
        """Run Flutter/Dart tests."""
        flutter = get_command("flutter")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "flutter test")
        runtime.execute([flutter, "test"], "FLUTTER TEST OUTPUT")

    @test.command("web")
    def test_web():
        """Run Flutter/Dart tests on the web platform in headless Chrome.

        Suites are compiled to JS (no ``--wasm``): the flutter web test harness
        cannot run sqlite3_web under dart2wasm in headless Chrome (dedicated
        workers and OPFS sync access handles are unavailable there), while the
        JS build exercises the real worker + OPFS path. VM-only suites are
        excluded from the selection because the web test pipeline compiles
        every selected suite regardless of ``@TestOn``, and those suites import
        ``dart:ffi``-only libraries.
        """
        flutter = get_command("flutter")
        chrome = os.environ.get("CHROME_EXECUTABLE")
        if not chrome:
            for candidate in ("google-chrome", "chromium", "chrome"):
                chrome = shutil.which(candidate)
                if chrome:
                    break
        if not chrome:
            raise click.ClickException(
                "Chrome not found. Set CHROME_EXECUTABLE or install google-chrome/chromium."
            )
        os.environ["CHROME_EXECUTABLE"] = chrome

        suites = _collect_web_test_suites()
        if not suites:
            raise click.ClickException("No web-compatible test suites found under test/.")
        if not runtime.is_dry_run():
            _stage_web_sqlite_assets()

        command = [flutter, "test", "--platform", "chrome", *suites]
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
            + "flutter test --platform chrome"
        )
        runtime.execute(command, "FLUTTER WEB TEST OUTPUT")

    @test.command("all")
    def test_all():
        """Run all test suites (Python + Dart + Web)."""
        ctx = click.get_current_context()
        ctx.invoke(test_python)
        click.echo()
        ctx.invoke(test_dart)
        click.echo()
        ctx.invoke(test_web)
