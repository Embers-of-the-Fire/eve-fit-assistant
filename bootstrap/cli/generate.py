from __future__ import annotations

import asyncio
import shutil

from pathlib import Path

import click

from colorama import Fore
from colorama import Style
from watchfiles import awatch

from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.constant import EFA_APP_ROOT
from bootstrap.constant import I18N_ROOT
from bootstrap.constant import PROTOBUF_DART_OUT_PATH
from bootstrap.constant import PROTOBUF_PYTHON_OUT_PATH
from bootstrap.constant import PROTOBUF_SCHEMA_PATH
from bootstrap.data.codegen import CODEGEN_DART
from bootstrap.data.codegen.protobuf_ts import ProtobufTsResult
from bootstrap.data.codegen.protobuf_ts import generate_protobuf_ts
from bootstrap.log import info
from bootstrap.log import warning
from bootstrap.utils import get_command


def _run_protobuf() -> None:
    protoc = get_command("protoc")

    total = 0
    failed: set[str] = set()

    if not PROTOBUF_PYTHON_OUT_PATH.exists():
        if runtime.is_dry_run():
            info(f"[Dry-Run] Would create Python protobuf output path: {PROTOBUF_PYTHON_OUT_PATH}")
        else:
            warning("Python protobuf output path not found, creating it.")
            PROTOBUF_PYTHON_OUT_PATH.mkdir(parents=True, exist_ok=True)
    if not PROTOBUF_DART_OUT_PATH.exists():
        if runtime.is_dry_run():
            info(f"[Dry-Run] Would create Dart protobuf output path: {PROTOBUF_DART_OUT_PATH}")
        else:
            warning("Dart protobuf output path not found, creating it.")
            PROTOBUF_DART_OUT_PATH.mkdir(parents=True, exist_ok=True)

    for file in PROTOBUF_SCHEMA_PATH.glob("*.proto"):
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Generating protobuf code for: ") + f"{file}")
        runtime.execute(
            [
                protoc,
                f"--proto_path={PROTOBUF_SCHEMA_PATH}",
                f"--python_out={PROTOBUF_PYTHON_OUT_PATH}",
                f"--dart_out={PROTOBUF_DART_OUT_PATH}",
                file.name,
            ],
            "PROTOBUF CODEGEN OUTPUT",
        )
        total += 1

    ts_result = generate_protobuf_ts(runtime.execute, dry_run=runtime.is_dry_run())

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Protobuf code generation completed."))
    if len(failed) == 0:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "All files generated successfully."))
    else:
        click.echo(
            styled(Fore.GREEN, "Successfully generated: ")
            + styled([Style.BRIGHT, Fore.GREEN], f"{total - len(failed)}")
            + Fore.GREEN
            + f" file{'s' if total - len(failed) > 1 else ''}."
        )
        click.echo(
            styled(Fore.RED, "Failed to generate: ")
            + styled([Style.BRIGHT, Fore.RED], f"{len(failed)}")
            + Fore.RED
            + f" file{'s' if len(failed) > 1 else ''}: "
            + ", ".join(failed)
            + "."
        )
    if ts_result is ProtobufTsResult.GENERATED:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "TypeScript protobuf bindings generated."))
    elif ts_result is ProtobufTsResult.DRY_RUN:
        click.echo(
            styled(
                [Style.BRIGHT, Fore.YELLOW],
                "TypeScript protobuf bindings not generated (dry-run).",
            )
        )
    else:
        click.echo(
            styled(
                [Style.BRIGHT, Fore.YELLOW],
                "TypeScript protobuf bindings skipped (pnpm unavailable).",
            )
        )


def _run_rust() -> None:
    native_output_dir = EFA_APP_ROOT / "lib" / "native"
    if native_output_dir.exists():
        if runtime.is_dry_run():
            info(f"[Dry-Run] Would remove existing native output directory: {native_output_dir}")
        else:
            info(f"Removing existing native output directory: {native_output_dir}")
            shutil.rmtree(native_output_dir)
    flutter_rust_bridge_codegen = get_command("flutter_rust_bridge_codegen")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + "flutter_rust_bridge_codegen generate"
    )
    runtime.execute(
        [flutter_rust_bridge_codegen, "generate"], "FRB CODEGEN OUTPUT", cwd=EFA_APP_ROOT
    )
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Rust bridge code generation completed successfully.")
    )


def _run_dart(watch: bool) -> None:
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing codegen: "),
    )
    for codegen in CODEGEN_DART:
        for file in codegen():
            click.echo(f"  Modified {file}")

    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + f"melos run app:gen{':watch' if watch else ''}"
    )
    runtime.run_melos(
        "app:gen:watch" if watch else "app:gen",
        "DART BUILDRUNNER OUTPUT",
    )
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Dart build runner completed successfully."))


def _run_l10n_once() -> None:
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "melos run app:l10n")
    runtime.run_melos("app:l10n", "FLUTTER GEN-L10N OUTPUT")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "melos run pkg:l10n")
    runtime.run_melos("pkg:l10n", "FLUTTER GEN-L10N OUTPUT")


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
        """Code generation related commands."""
        ctx.ensure_object(dict)
        ctx.obj["format_source"] = format_source

    @generate.command("all")
    @click.pass_context
    def all_cmd(ctx: click.Context):
        """Generate all code."""
        _run_protobuf()
        _run_rust()
        _run_dart(watch=False)
        _run_l10n_once()

        if ctx.obj.get("format_source", False):
            runtime.run_format()

    @generate.command("protobuf")
    @click.pass_context
    def protobuf(ctx: click.Context):
        """Generate protobuf code for all supported languages."""
        _run_protobuf()
        if ctx.obj.get("format_source", False):
            runtime.run_format()

    @generate.command("rust")
    @click.pass_context
    def rust_cmd(ctx: click.Context):
        """Generate flutter-rust-bridge glue code."""
        _run_rust()
        if ctx.obj.get("format_source", False):
            runtime.run_format()

    @generate.command("dart")
    @click.option("--watch", "-w", is_flag=True, default=False, help="Run in watch mode.")
    @click.pass_context
    def dart_build_runner(ctx: click.Context, watch: bool):
        """Run `flutter pub run build_runner build`."""
        _run_dart(watch=watch)
        if ctx.obj.get("format_source", False):
            runtime.run_format()

    @generate.command("l10n")
    @click.option("--watch", "-w", is_flag=True, default=False, help="Run in watch mode.")
    @click.pass_context
    def gen_l10n(ctx: click.Context, watch: bool):
        """Generate localization files."""
        if watch:

            async def watch_l10n():
                _run_l10n_once()
                async for _ in awatch(str(I18N_ROOT)):
                    _run_l10n_once()

            try:
                asyncio.run(watch_l10n())
            except KeyboardInterrupt:
                click.echo(styled([Style.BRIGHT, Fore.YELLOW], "\nWatch mode interrupted by user."))
                return

        _run_l10n_once()
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Localization generation completed successfully.")
        )

        if ctx.obj.get("format_source", False):
            runtime.run_format()

    @generate.group("values")
    def generate_values():
        """Generate value-dependent code from the selected workspace."""

    @generate_values.command("dogma-units")
    @click.pass_context
    def dogma_units_cmd(ctx: click.Context):
        """Generate dogma unit ID constants."""
        from bootstrap.data.codegen.dogma_unit_id import codegen_dart

        files = asyncio.run(codegen_dart(runtime.current_workspace_descriptor()))
        for file in files:
            click.echo(f"  Modified {file}")

        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Dogma unit ID generation completed."))

        if ctx.obj.get("format_source", False):
            runtime.run_format()

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
