from __future__ import annotations

import click

from click_aliases import ClickAliasedGroup
from colorama import Fore
from colorama import Style

from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.utils import get_command


def register_test_commands(cli_group: click.Group) -> None:
    @cli_group.group(aliases=["t"], cls=ClickAliasedGroup)
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

    @test.command("all")
    def test_all():
        """Run all test suites (Python + Dart)."""
        ctx = click.get_current_context()
        ctx.invoke(test_python)
        click.echo()
        ctx.invoke(test_dart)
