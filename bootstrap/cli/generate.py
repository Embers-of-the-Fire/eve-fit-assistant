from __future__ import annotations

import asyncio

from pathlib import Path

import click

from colorama import Fore
from colorama import Style
from watchfiles import awatch

from bootstrap.ci.codegen import all_step_names
from bootstrap.ci.codegen import run_steps
from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.constant import I18N_ROOT


def register_generate_commands(cli_group: click.Group) -> None:
    @cli_group.group()
    @click.option(
        "--format",
        "-f",
        "format_source",
        is_flag=True,
        default=False,
        help="Run formatter after generation.",
    )
    @click.pass_context
    def generate(ctx: click.Context, format_source: bool):
        """Code generation related commands.

        Every subcommand executes steps through the codegen step graph
        (``bootstrap.ci.codegen``), the single definition of what codegen
        exists.
        """
        ctx.ensure_object(dict)
        ctx.obj["format_source"] = format_source

    def _maybe_format(ctx: click.Context) -> None:
        if ctx.obj.get("format_source", False):
            runtime.run_format()

    @generate.command("all")
    @click.pass_context
    def all_cmd(ctx: click.Context):
        """Generate all code."""
        run_steps(all_step_names())
        _maybe_format(ctx)

    @generate.command("protobuf")
    @click.pass_context
    def protobuf(ctx: click.Context):
        """Generate protobuf code for all supported languages."""
        run_steps(["protobuf", "protobuf_ts"])
        _maybe_format(ctx)

    @generate.command("rust")
    @click.pass_context
    def rust_cmd(ctx: click.Context):
        """Generate flutter-rust-bridge glue code."""
        run_steps(["frb"])
        _maybe_format(ctx)

    @generate.command("dart")
    @click.option("--watch", "-w", is_flag=True, default=False, help="Run in watch mode.")
    @click.pass_context
    def dart_build_runner(ctx: click.Context, watch: bool):
        """Run `flutter pub run build_runner build`."""
        if watch:
            run_steps(["dart_tools"])
            click.echo(
                styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
                + "melos run app:gen:watch"
            )
            runtime.run_melos("app:gen:watch", "DART BUILDRUNNER OUTPUT")
        else:
            run_steps(["dart_tools", "build_runner"])
        _maybe_format(ctx)

    @generate.command("acl")
    @click.pass_context
    def acl_cmd(ctx: click.Context):
        """Generate ACL fixtures and product bindings for both runtimes."""
        run_steps(["acl"])
        _maybe_format(ctx)

    @generate.command("l10n")
    @click.option("--watch", "-w", is_flag=True, default=False, help="Run in watch mode.")
    @click.pass_context
    def gen_l10n(ctx: click.Context, watch: bool):
        """Generate localization files."""
        if watch:

            async def watch_l10n():
                run_steps(["l10n"])
                async for _ in awatch(str(I18N_ROOT)):
                    run_steps(["l10n"])

            try:
                asyncio.run(watch_l10n())
            except KeyboardInterrupt:
                click.echo(styled([Style.BRIGHT, Fore.YELLOW], "\nWatch mode interrupted by user."))
                return

        run_steps(["l10n"])
        _maybe_format(ctx)

    @generate.group("values")
    def generate_values():
        """Generate value-dependent code from the selected workspace."""

    @generate_values.command("dogma-units")
    @click.pass_context
    def dogma_units_cmd(ctx: click.Context):
        """Generate dogma unit ID constants."""
        run_steps(["dogma_units"])
        _maybe_format(ctx)

    @generate.command("schema")
    @click.option(
        "--dir",
        "build_dir",
        type=click.Path(path_type=Path),
        required=True,
        help="Build directory containing workspace output.",
    )
    @click.option(
        "--server",
        "server_id",
        required=True,
        help="Server ID for the checkout catalog (e.g., 'serenity').",
    )
    @click.option(
        "--schema-root",
        type=click.Path(path_type=Path),
        default=None,
        help="Unified schema root directory (default from dev config).",
    )
    @click.option("--author", default=None, help="Author identifier for the snapshot.")
    @click.option("--description", default=None, help="Description for the snapshot.")
    def generate_schema_cmd(build_dir, server_id, schema_root, author, description):
        """Generate a V2 schema checkout from workspace build output."""
        import bootstrap.config

        from bootstrap.data.workspace.generate.schema import generate_schema_checkout

        if schema_root is None:
            bootstrap.config.DeveloperConfiguration.ensure_loaded()
            schema_root = bootstrap.config.DEV_CONFIGURATION.paths.schema_dir

        hash_ = generate_schema_checkout(
            config=None,
            build_dir=build_dir,
            schema_root=schema_root,
            server_id=server_id,
            author=author,
            description=description,
        )
        if hash_:
            click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Checkout hash: {hash_}"))
        else:
            click.echo(styled([Style.BRIGHT, Fore.RED], "No files found — checkout not generated."))
