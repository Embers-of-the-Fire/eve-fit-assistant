from __future__ import annotations

import sys

import click

from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.data.workspace.config import WorkspaceConfig


def register_workspace_commands(cli_group: click.Group) -> None:
    @cli_group.group()
    def workspace():
        """Workspace related commands."""

    @workspace.command("list")
    def list_cmd():
        """List configured workspaces."""
        workspaces = bootstrap.config.CONFIGURATION.resources
        if len(workspaces) == 0:
            click.echo(
                styled([Style.BRIGHT + Fore.RED], "Error: ")
                + styled(Fore.RED, "No workspace configured.")
            )
            sys.exit(1)

        click.echo(
            styled(Fore.GREEN, "Found ")
            + styled([Style.BRIGHT, Fore.GREEN], f"{len(workspaces)}")
            + styled(Fore.GREEN, " workspace configurations.")
        )
        has_not_found = set()
        has_warning = set()
        has_error = set()
        for ws_key, ws_def in workspaces.items():
            if ws_def.descriptor.exists():
                click.echo(
                    styled([Style.BRIGHT, Fore.GREEN], "- [√] ") + f"{ws_key}: {ws_def.descriptor}"
                )
                descriptor = WorkspaceConfig.load_from_descriptor(ws_def.descriptor, no_check=True)

                if descriptor.ignore:
                    click.echo(
                        styled([Style.BRIGHT, Fore.YELLOW], "  [!] Warning: ")
                        + "workspace is marked as ignored.",
                    )
                    has_warning.add(ws_key)
                    continue

                if not descriptor.resources.fsd.exists() or not descriptor.resources.fsd.is_dir():
                    click.echo(
                        styled([Style.BRIGHT, Fore.RED], "  [!] Error: ")
                        + f"FSD path '{descriptor.resources.fsd}' does not exist or is not a directory.",
                    )
                    has_error.add(ws_key)

                if (
                    not descriptor.resources.resource_index.exists()
                    or not descriptor.resources.resource_index.is_file()
                ):
                    click.echo(
                        styled([Style.BRIGHT, Fore.RED], "  [!] Error: ")
                        + f"Resource index '{descriptor.resources.resource_index}' does not exist or is not a file.",
                    )
                    has_error.add(ws_key)

                if (
                    not descriptor.resources.application_index.exists()
                    or not descriptor.resources.application_index.is_file()
                ):
                    click.echo(
                        styled([Style.BRIGHT, Fore.RED], "  [!] Error: ")
                        + f"Application index '{descriptor.resources.application_index}' does not exist or is not a file.",
                    )
                    has_error.add(ws_key)

                if (
                    not descriptor.metadata.start_cfg.exists()
                    or not descriptor.metadata.start_cfg.is_file()
                ):
                    click.echo(
                        styled([Style.BRIGHT, Fore.RED], "  [!] Error: ")
                        + f"Start configuration '{descriptor.metadata.start_cfg}' does not exist or is not a file.",
                    )
                    has_error.add(ws_key)
            else:
                click.echo(
                    styled([Style.BRIGHT, Fore.RED], "- [!] ")
                    + f"{ws_key}: "
                    + styled([Style.BRIGHT, Fore.RED], "Descriptor not found: ")
                    + f"{ws_def.descriptor}"
                )
                has_not_found.add(ws_key)

        if len(has_not_found) > 0:
            click.echo(
                styled(Fore.RED, "Missing ")
                + styled([Style.BRIGHT, Fore.RED], f"{len(has_not_found)}")
                + styled(
                    Fore.RED,
                    " descriptor" + ("s" if len(has_not_found) > 1 else "") + ": ",
                )
                + ", ".join(has_not_found)
            )
        if len(has_warning) > 0:
            click.echo(
                styled(Fore.YELLOW, "Warning in ")
                + styled([Style.BRIGHT, Fore.YELLOW], f"{len(has_warning)}")
                + styled(
                    Fore.YELLOW,
                    " workspace" + ("s" if len(has_warning) > 1 else "") + ": ",
                )
                + ", ".join(has_warning)
            )
        if len(has_error) > 0:
            click.echo(
                styled(Fore.RED, "Error in ")
                + styled([Style.BRIGHT, Fore.RED], f"{len(has_error)}")
                + styled(
                    Fore.RED,
                    " workspace" + ("s" if len(has_error) > 1 else "") + ": ",
                )
                + ", ".join(has_error)
            )

        if has_error or has_not_found:
            sys.exit(1)

    @workspace.command()
    @click.argument("name")
    def default(name: str):
        """Set default build target resource."""
        _ = runtime.get_workspace(name)  # check

        ws_cache = bootstrap.config.WORKSPACE_CACHE
        if ws_cache.default_workspace is not None:
            click.echo(f"Switch default workspace from {ws_cache.default_workspace} to {name}.")
        else:
            click.echo(f"Set default workspace to {name}.")
        ws_cache.default_workspace = name
        ws_cache.synchronize()

    @workspace.command()
    @click.option("--pretty", is_flag=True, default=False, help="Pretty print the JSON output.")
    def inspect_json(pretty: bool):
        """Resolve the workspace configurations and print in JSON format."""
        descriptor = runtime.current_workspace_descriptor()
        click.echo(descriptor.model_dump_json(indent=4 if pretty else None))

    @workspace.command()
    @click.option("--pretty", is_flag=True, default=False, help="Pretty print the JSON output.")
    def cache(pretty: bool):
        """Print current workspace cache in JSON format."""
        click.echo(bootstrap.config.WORKSPACE_CACHE.model_dump_json(indent=4 if pretty else None))

    @cli_group.group()
    def config():
        """Configuration related commands."""

    @config.command()
    def display():
        """Print loaded configuration in JSON format."""
        click.echo(bootstrap.config.CONFIGURATION.model_dump_json(indent=4))
