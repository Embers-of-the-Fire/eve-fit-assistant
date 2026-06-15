from __future__ import annotations

import shutil

import click

from colorama import Fore
from colorama import Style

from data.lib.codegen import CODEGEN_DART
from data.lib.color import styled
from data.lib.constant import PROJECT_ROOT
from data.lib.constant import PROTOBUF_DART_OUT_PATH
from data.lib.constant import PROTOBUF_PYTHON_OUT_PATH
from data.lib.constant import PROTOBUF_SCHEMA_PATH
from data.lib.log import info
from data.lib.log import warning
from data.lib.utils import execute_command
from data.lib.utils import get_command


def _step_protobuf() -> None:
    """Generate protobuf code for Python and Dart."""
    protoc = get_command("protoc")

    if not PROTOBUF_PYTHON_OUT_PATH.exists():
        warning("Python protobuf output path not found, creating it.")
        PROTOBUF_PYTHON_OUT_PATH.mkdir(parents=True, exist_ok=True)
    if not PROTOBUF_DART_OUT_PATH.exists():
        warning("Dart protobuf output path not found, creating it.")
        PROTOBUF_DART_OUT_PATH.mkdir(parents=True, exist_ok=True)

    for file in PROTOBUF_SCHEMA_PATH.glob("*.proto"):
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Generating protobuf code for: ") + f"{file}")
        execute_command(
            [
                protoc,
                f"--proto_path={PROTOBUF_SCHEMA_PATH}",
                f"--python_out={PROTOBUF_PYTHON_OUT_PATH}",
                f"--dart_out={PROTOBUF_DART_OUT_PATH}",
                file.name,
            ],
            "PROTOBUF CODEGEN OUTPUT",
        )

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Protobuf code generation completed."))
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "All files generated successfully."))


def _step_frb() -> None:
    """Generate flutter-rust-bridge glue code."""
    native_output_dir = PROJECT_ROOT / "lib" / "native"
    if native_output_dir.exists():
        info(f"Removing existing native output directory: {native_output_dir}")
        shutil.rmtree(native_output_dir)
    flutter_rust_bridge_codegen = get_command("flutter_rust_bridge_codegen")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + "flutter_rust_bridge_codegen generate"
    )
    execute_command([flutter_rust_bridge_codegen, "generate"], "FRB CODEGEN OUTPUT")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Rust bridge code generation completed successfully.")
    )


def _step_dart_build_runner() -> None:
    """Run Dart code generation (custom codegens + build_runner)."""
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing codegen: "),
    )
    for codegen in CODEGEN_DART:
        for file in codegen():
            click.echo(f"  Modified {file}")

    flutter = get_command("flutter")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + "flutter pub run build_runner build --delete-conflicting-outputs"
    )
    execute_command(
        [
            flutter,
            "pub",
            "run",
            "build_runner",
            "build",
            "--delete-conflicting-outputs",
        ],
        "DART BUILDRUNNER OUTPUT",
    )
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Dart build runner completed successfully."))


def _step_l10n() -> None:
    """Generate localization files."""
    flutter = get_command("flutter")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "flutter gen-l10n")
    execute_command([flutter, "gen-l10n"], "FLUTTER GEN-L10N OUTPUT")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Localization generation completed successfully.")
    )


CODEGEN_STEPS = {
    "protobuf": {"run": _step_protobuf, "depends": []},
    "frb": {"run": _step_frb, "depends": []},
    "dart_build_runner": {"run": _step_dart_build_runner, "depends": ["frb", "protobuf"]},
    "l10n": {"run": _step_l10n, "depends": []},
}


LANGUAGE_STEPS = {
    "python": ["protobuf"],
    "dart": ["protobuf", "frb", "dart_build_runner", "l10n"],
    "site": [],
    "all": ["protobuf", "frb", "dart_build_runner", "l10n"],
}


def _resolve_steps(requested: list[str]) -> list[str]:
    """Resolve requested step names to a topologically-sorted list with transitive dependencies."""
    needed: set[str] = set(requested)

    changed = True
    while changed:
        changed = False
        for name in list(needed):
            for dep in CODEGEN_STEPS[name]["depends"]:
                if dep not in needed:
                    needed.add(dep)
                    changed = True

    result: list[str] = []
    visited: set[str] = set()
    temp: set[str] = set()

    def visit(name: str) -> None:
        if name in temp:
            raise ValueError(f"Circular dependency detected: {name}")
        if name in visited:
            return
        temp.add(name)
        for dep in CODEGEN_STEPS[name]["depends"]:
            visit(dep)
        temp.discard(name)
        visited.add(name)
        result.append(name)

    for name in sorted(needed):
        if name not in visited:
            visit(name)

    return result


def run_codegen(lang: str) -> None:
    """Run code generation for a language, resolving dependencies automatically.

    Uses CODEGEN_STEPS and LANGUAGE_STEPS to determine which generators to run,
    resolves their dependencies with topological sort, and executes each step.
    """
    step_names = LANGUAGE_STEPS.get(lang)
    if step_names is None:
        click.echo(styled([Style.BRIGHT, Fore.RED], f"Unknown language: {lang}"))
        return

    if not step_names:
        click.echo(styled([Style.BRIGHT, Fore.YELLOW], f"No generation steps for language: {lang}"))
        return

    resolved = _resolve_steps(step_names)
    for name in resolved:
        step = CODEGEN_STEPS[name]
        click.echo(styled([Style.BRIGHT, Fore.CYAN], f"--- CI codegen step: {name} ---"))
        step["run"]()

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "All code generation completed successfully."))
