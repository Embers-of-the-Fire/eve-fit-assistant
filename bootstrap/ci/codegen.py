"""Layer 2 — the codegen step graph.

Code generation is a set of named steps, each declaring its own step-level
dependencies (for example, Dart ``build_runner`` requires the FRB bridge and
protobuf outputs). This graph is the single definition of what codegen
exists; every codegen entry point (CI-scoped generation, local ``./x
generate``, release pipelines) executes steps through it.

Codegen is scoped by packages, and only by packages: the steps required for a
set of packages are the union of ``Package.codegen`` over the dependency
closure of those packages, then the step-level dependency closure of that
union, topologically ordered.
"""

from __future__ import annotations

import asyncio
import shutil

from dataclasses import dataclass
from typing import TYPE_CHECKING

import click

from colorama import Fore
from colorama import Style

from bootstrap.color import styled
from bootstrap.constant import EFA_APP_ROOT
from bootstrap.constant import PROTOBUF_DART_OUT_PATH
from bootstrap.constant import PROTOBUF_PYTHON_OUT_PATH
from bootstrap.constant import PROTOBUF_SCHEMA_PATH
from bootstrap.log import info
from bootstrap.log import warning
from bootstrap.utils import get_command


if TYPE_CHECKING:
    from collections.abc import Callable
    from collections.abc import Iterable


def _runtime():
    # Lazy import: ``bootstrap.cli.runtime`` owns the dry-run state and the
    # command wrappers; importing it at module scope would couple the step
    # graph to CLI registration order.
    from bootstrap.cli import runtime

    return runtime


def _run_protobuf() -> None:
    """Generate protobuf code for Python and Dart."""
    runtime = _runtime()
    protoc = get_command("protoc")

    for out_path, label in (
        (PROTOBUF_PYTHON_OUT_PATH, "Python"),
        (PROTOBUF_DART_OUT_PATH, "Dart"),
    ):
        if not out_path.exists():
            if runtime.is_dry_run():
                info(f"[Dry-Run] Would create {label} protobuf output path: {out_path}")
            else:
                warning(f"{label} protobuf output path not found, creating it.")
                out_path.mkdir(parents=True, exist_ok=True)

    for file in sorted(PROTOBUF_SCHEMA_PATH.glob("*.proto")):
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

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Protobuf code generation completed."))


def _run_protobuf_ts() -> None:
    """Generate TypeScript protobuf bindings via buf (requires pnpm)."""
    from bootstrap.data.codegen.protobuf_ts import ProtobufTsResult
    from bootstrap.data.codegen.protobuf_ts import generate_protobuf_ts

    runtime = _runtime()
    result = generate_protobuf_ts(runtime.execute, dry_run=runtime.is_dry_run())
    if result is ProtobufTsResult.GENERATED:
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "TypeScript protobuf bindings generated."))
    elif result is ProtobufTsResult.DRY_RUN:
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


def _run_frb() -> None:
    """Generate flutter_rust_bridge glue code (Rust side and Dart side)."""
    runtime = _runtime()
    native_output_dir = EFA_APP_ROOT / "lib" / "native"
    if native_output_dir.exists():
        if runtime.is_dry_run():
            info(f"[Dry-Run] Would remove existing native output directory: {native_output_dir}")
        else:
            info(f"Removing existing native output directory: {native_output_dir}")
            shutil.rmtree(native_output_dir)
    codegen = get_command("flutter_rust_bridge_codegen")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + "flutter_rust_bridge_codegen generate"
    )
    runtime.execute([codegen, "generate"], "FRB CODEGEN OUTPUT", cwd=EFA_APP_ROOT)
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Rust bridge code generation completed successfully.")
    )


def _run_dart_tools() -> None:
    """Run the custom Dart code generators (assets, ids, schema version)."""
    from bootstrap.data.codegen import CODEGEN_DART

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing codegen: "))
    for codegen in CODEGEN_DART:
        for file in codegen():
            click.echo(f"  Modified {file}")


def _run_build_runner() -> None:
    """Run the app's ``build_runner`` code generation."""
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "melos run app:gen")
    _runtime().run_melos("app:gen", "DART BUILDRUNNER OUTPUT")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Dart build runner completed successfully."))


def _run_l10n() -> None:
    """Generate localization files for the app and the snapshot package."""
    runtime = _runtime()
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "melos run app:l10n")
    runtime.run_melos("app:l10n", "FLUTTER GEN-L10N OUTPUT")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "melos run pkg:l10n")
    runtime.run_melos("pkg:l10n", "FLUTTER GEN-L10N OUTPUT")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Localization generation completed successfully.")
    )


def _run_acl() -> None:
    """Generate ACL fixtures and product bindings for both runtimes.

    Thin wrapper over pnpm scripts; the generators live in
    ``packages/acl/tool`` and ``packages/efa_acl/ts``. A filtered
    ``pnpm install`` runs first because codegen may execute in an environment
    that never installs JS dependencies. Skips with a warning when pnpm is
    unavailable (local convenience; the CI codegen shell always has pnpm).
    """
    runtime = _runtime()
    pnpm = shutil.which("pnpm")
    if pnpm is None:
        warning(
            "pnpm not found on PATH; install dependencies with `pnpm install` "
            "to enable ACL code generation. Skipping."
        )
        return
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + "pnpm install --filter acl-tool"
    )
    runtime.execute([pnpm, "install", "--filter", "acl-tool"], "PNPM INSTALL OUTPUT")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + "pnpm --filter acl-tool generate:fixtures"
    )
    runtime.execute([pnpm, "--filter", "acl-tool", "generate:fixtures"], "ACL CODEGEN OUTPUT")
    click.echo(
        styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
        + "pnpm --filter efa-acl-ts generate"
    )
    runtime.execute([pnpm, "--filter", "efa-acl-ts", "generate"], "EFA ACL CODEGEN OUTPUT")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "ACL code generation completed."))


def _run_dogma_units() -> None:
    """Generate dogma unit ID constants from the selected workspace."""
    from bootstrap.data.codegen.dogma_unit_id import codegen_dart

    files = asyncio.run(codegen_dart(_runtime().current_workspace_descriptor()))
    for file in files:
        click.echo(f"  Modified {file}")
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Dogma unit ID generation completed."))


@dataclass(frozen=True)
class Step:
    """A named codegen step with its step-level dependencies."""

    name: str
    run: Callable[[], None]
    requires: tuple[str, ...] = ()
    # Local-only steps are excluded from `all_steps()`: they depend on a
    # selected data workspace and are never part of CI or release codegen.
    local_only: bool = False


STEPS: tuple[Step, ...] = (
    Step("protobuf", _run_protobuf),
    Step("protobuf_ts", _run_protobuf_ts),
    Step("frb", _run_frb),
    Step("dart_tools", _run_dart_tools),
    Step("build_runner", _run_build_runner, requires=("frb", "protobuf")),
    Step("l10n", _run_l10n),
    Step("acl", _run_acl),
    Step("dogma_units", _run_dogma_units, local_only=True),
)

_STEPS_BY_NAME = {step.name: step for step in STEPS}


def resolve_steps(names: Iterable[str]) -> list[str]:
    """Resolve step names to a topologically ordered list with transitive deps."""
    requested = list(names)
    unknown = set(requested) - _STEPS_BY_NAME.keys()
    if unknown:
        raise ValueError(f"Unknown codegen step(s): {', '.join(sorted(unknown))}")

    needed: set[str] = set()
    stack = list(requested)
    while stack:
        current = stack.pop()
        if current in needed:
            continue
        needed.add(current)
        stack.extend(_STEPS_BY_NAME[current].requires)

    ordered: list[str] = []
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str) -> None:
        if name in visiting:
            raise ValueError(f"Circular codegen step dependency: {name}")
        if name in visited:
            return
        visiting.add(name)
        for dep in _STEPS_BY_NAME[name].requires:
            visit(dep)
        visiting.discard(name)
        visited.add(name)
        ordered.append(name)

    for name in sorted(needed):
        visit(name)
    return ordered


def all_step_names() -> list[str]:
    """Every CI/release-relevant step, topologically ordered."""
    return resolve_steps(step.name for step in STEPS if not step.local_only)


def steps_for_packages(package_ids: Iterable[str]) -> list[str]:
    """The codegen steps required to lint or test the given packages.

    The union of ``Package.codegen`` over the dependency closure of the given
    packages, closed over step-level dependencies and topologically ordered.
    """
    from bootstrap.ci.registry import PACKAGES

    by_id = {p.id: p for p in PACKAGES}
    unknown = set(package_ids) - by_id.keys()
    if unknown:
        raise ValueError(f"Unknown package(s): {', '.join(sorted(unknown))}")

    closure: set[str] = set()
    stack = list(package_ids)
    while stack:
        current = stack.pop()
        if current in closure:
            continue
        closure.add(current)
        stack.extend(by_id[current].depends_on)

    names: set[str] = set()
    for package_id in closure:
        names.update(by_id[package_id].codegen)
    return resolve_steps(names)


def run_steps(names: Iterable[str]) -> None:
    """Execute the given steps (with transitive dependencies) in order."""
    for name in resolve_steps(names):
        click.echo(styled([Style.BRIGHT, Fore.CYAN], f"--- codegen step: {name} ---"))
        _STEPS_BY_NAME[name].run()
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "All code generation completed successfully."))
