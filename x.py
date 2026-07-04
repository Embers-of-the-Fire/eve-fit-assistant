"""
EVE Fit Assistant Workspace Manager

This script is used to manage all workspace-level operations,
including code generating, data processing and application bundling.

This file, `x.py`, shares the virtual environment with other sub projects.
You should use `uv run x.py` to execute the script.

To synchronize the python environment, execute `uv sync` from the commandline.

**About Env-Vars**
Some of the commands support environment variables to pass parameters,
but that's not recommended. And the script itself won't load dotenv files.
Please use the configuration files to configure the tool, or pass parameters directly.

**Architecture**
`x.py` is intentionally tiny: it only bootstraps the environment, builds the
root Click group, and delegates every command group to a `register_*` function
under `bootstrap.cli`. Add or modify commands there, not here.
"""

# ruff: noqa: E402
# Allow monkey patch to global PYTHON PATH for schema imports

from __future__ import annotations

import sys

from pathlib import Path

from dotenv import load_dotenv


PROJECT_ROOT = Path(__file__).parent.resolve()


def __fix_env():
    sys.path.insert(0, str((PROJECT_ROOT / "bootstrap" / "data" / "schema").resolve()))
    load_dotenv()


__fix_env()

import click

from colorama import Fore
from colorama import Style
from colorama import init

from bootstrap.cli import register_all_commands
from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.config import ProjectConfiguration
from bootstrap.config import WorkspaceCache


init(autoreset=True)

if __name__ != "__main__":
    print(
        styled([Style.BRIGHT, Fore.RED], "Invalid Usage: ")
        + "`x.py` must be used as a script, not a module!"
    )
    exit(0)

ProjectConfiguration.load_from_global()
WorkspaceCache.load_from_global()


@click.group(
    context_settings={
        "help_option_names": ["-h", "--help"],
    },
)
@click.option("--dry-run", is_flag=True, default=False, help="Show the command without executing.")
@click.option("--workspace", "--ws", "ws_name", default=None, help="Set current workspace.")
def cli(dry_run, ws_name):
    """EFA Workspace Manager."""
    runtime.set_dry_run(dry_run)

    if ws_name:
        WorkspaceCache.select_workspace(ws_name)


register_all_commands(cli)


cli()
