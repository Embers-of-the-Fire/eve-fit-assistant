from __future__ import annotations

import shutil

from typing import TYPE_CHECKING

from bootstrap.constant import PROJECT_ROOT
from bootstrap.log import warning


if TYPE_CHECKING:
    from collections.abc import Callable


def generate_protobuf_ts(execute: Callable[..., str], *, required: bool = False) -> bool:
    """Generate TypeScript protobuf bindings (protobuf-es) for the platform-facing schemas.

    ``execute`` matches the signature of ``bootstrap.cli.runtime.execute`` /
    ``bootstrap.utils.execute_command`` so both interactive and CI paths can reuse this.
    Delegates to the ``efa-proto-ts`` package's ``generate`` script (buf, npm-distributed,
    no protoc required); pnpm puts the package's ``node_modules/.bin`` on PATH so buf can
    resolve the ``protoc-gen-es`` plugin. Skips with a warning when pnpm is unavailable,
    unless ``required`` is set, in which case a missing pnpm raises ``FileNotFoundError``.

    Returns True when the bindings were generated, False when the step was skipped.
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
        return False

    execute(
        [pnpm, "--filter", "efa-proto-ts", "generate"],
        "PROTOBUF TS CODEGEN OUTPUT",
        cwd=PROJECT_ROOT,
    )
    return True
