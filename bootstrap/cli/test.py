from __future__ import annotations

import os
import shutil

import click

from colorama import Fore
from colorama import Style

from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.utils import get_command


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
        """Run Flutter/Dart tests on the web platform in headless Chrome."""
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
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
            + "flutter test --platform chrome"
        )
        runtime.execute([flutter, "test", "--platform", "chrome"], "FLUTTER WEB TEST OUTPUT")

    @test.command("all")
    def test_all():
        """Run all test suites (Python + Dart + Web)."""
        ctx = click.get_current_context()
        ctx.invoke(test_python)
        click.echo()
        ctx.invoke(test_dart)
        click.echo()
        ctx.invoke(test_web)
