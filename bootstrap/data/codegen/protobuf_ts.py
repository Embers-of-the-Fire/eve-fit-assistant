from __future__ import annotations

import enum
import shutil

from typing import TYPE_CHECKING

from bootstrap.constant import PROJECT_ROOT
from bootstrap.log import info
from bootstrap.log import warning


if TYPE_CHECKING:
    from collections.abc import Callable


class ProtobufTsResult(enum.Enum):
    """Outcome of a TypeScript protobuf binding generation attempt."""

    GENERATED = enum.auto()
    SKIPPED = enum.auto()
    DRY_RUN = enum.auto()


def generate_protobuf_ts(
    execute: Callable[..., str], *, required: bool = False, dry_run: bool = False
) -> ProtobufTsResult:
    """Generate TypeScript protobuf bindings (protobuf-es) for the platform-facing schemas.

    ``execute`` matches the signature of ``bootstrap.cli.runtime.execute`` /
    ``bootstrap.utils.execute_command`` so both interactive and CI paths can reuse this.
    Delegates to the ``efa-proto-ts`` package's ``generate`` script (buf, npm-distributed,
    no protoc required); pnpm puts the package's ``node_modules/.bin`` on PATH so buf can
    resolve the ``protoc-gen-es`` plugin. A filtered ``pnpm install`` runs first because
    codegen may execute in an environment that never installs JS dependencies. Skips with
    a warning when pnpm is unavailable, unless ``required`` is set, in which case a
    missing pnpm raises ``FileNotFoundError``.

    Returns ``GENERATED`` only after real generation, ``SKIPPED`` when the step was
    skipped, and ``DRY_RUN`` when ``dry_run`` is set (no bindings were written).
    """
    pnpm = shutil.which("pnpm")
    if pnpm is None:
        if required:
            raise FileNotFoundError(
                "pnpm not found on PATH; install dependencies with `pnpm install` "
                "to enable TypeScript protobuf generation."
            )
        warning(
            "pnpm not found on PATH; "
            "install dependencies with `pnpm install` to enable TypeScript protobuf "
            "generation. Skipping."
        )
        return ProtobufTsResult.SKIPPED

    if dry_run:
        info(f"[Dry-Run] Would generate TypeScript protobuf bindings: {pnpm}")
        return ProtobufTsResult.DRY_RUN

    execute(
        [pnpm, "install", "--filter", "efa-proto-ts"],
        "PNPM INSTALL OUTPUT",
        cwd=PROJECT_ROOT,
    )
    execute(
        [pnpm, "--filter", "efa-proto-ts", "generate"],
        "PROTOBUF TS CODEGEN OUTPUT",
        cwd=PROJECT_ROOT,
    )
    return ProtobufTsResult.GENERATED
