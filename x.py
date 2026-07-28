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
from bootstrap.config import apply_dev_config_overrides
from bootstrap.config import apply_project_config_overrides


init(autoreset=True)

if __name__ != "__main__":
    print(
        styled([Style.BRIGHT, Fore.RED], "Invalid Usage: ")
        + "`x.py` must be used as a script, not a module!"
    )
    sys.exit(0)


def _parse_env_option(
    _ctx: click.Context,
    _param: click.Parameter,
    value: tuple[str, ...] | None,
) -> list[tuple[str, str]]:
    """Parse repeated ``key=value`` options into a list of overrides."""
    overrides: list[tuple[str, str]] = []
    for item in value or ():
        if "=" not in item:
            raise click.BadParameter(f"Invalid override {item!r}, expected format: key=value")
        key, val = item.split("=", 1)
        overrides.append((key, val))
    return overrides


@click.group(
    context_settings={
        "help_option_names": ["-h", "--help"],
    },
)
@click.option("--dry-run", is_flag=True, default=False, help="Show the command without executing.")
@click.option("--workspace", "--ws", "ws_name", default=None, help="Set current workspace.")
@click.option(
    "--dev-env",
    "dev_env_overrides",
    multiple=True,
    callback=_parse_env_option,
    default=None,
    help="Override a value in efa.dev.toml before validation (e.g. --dev-env ci.storage.secret_key=abc).",
)
@click.option(
    "--conf-env",
    "conf_env_overrides",
    multiple=True,
    callback=_parse_env_option,
    default=None,
    help="Override a value in efa.config.toml before validation (e.g. --conf-env version.major=1).",
)
@click.pass_context
def cli(ctx, dry_run, ws_name, dev_env_overrides, conf_env_overrides):
    """EFA Workspace Manager."""
    runtime.set_dry_run(dry_run)

    apply_dev_config_overrides(dev_env_overrides)
    apply_project_config_overrides(conf_env_overrides)

    ProjectConfiguration.load_from_global()
    WorkspaceCache.load_from_global()

    if ws_name:
        WorkspaceCache.select_workspace(ws_name)


register_all_commands(cli)


cli()
