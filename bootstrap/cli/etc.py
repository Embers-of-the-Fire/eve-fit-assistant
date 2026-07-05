from __future__ import annotations

import click

from colorama import Fore
from colorama import Style

from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.constant import PROJECT_ROOT
from bootstrap.etc.codeart import generate_codeart
from bootstrap.log import warning
from bootstrap.utils import get_command


def register_etc_commands(cli_group: click.Group) -> None:
    @cli_group.group()
    def etc():
        """Extra toolsets."""

    @etc.command("codeart")
    def etc_codeart_cmd():
        """Generate the codeart image."""
        warning("Generate codeart requires tokei with json output installed and exported via path.")
        tokei = get_command("tokei")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "tokei . -o json")
        stdout = runtime.execute([tokei, ".", "-o", "json"], "TOKEI OUTPUT")

        output_file = PROJECT_ROOT / "codeart.png"
        generate_codeart(stdout, output_file)
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Codeart image generated successfully: ")
            + str(output_file)
        )
