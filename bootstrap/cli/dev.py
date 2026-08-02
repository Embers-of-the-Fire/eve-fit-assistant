from __future__ import annotations

import shutil
import sys

import click

from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.cli import runtime
from bootstrap.color import styled
from bootstrap.constant import DEV_CONFIG_PATH
from bootstrap.constant import NATIVE_LIB_ROOT
from bootstrap.constant import PROJECT_ROOT
from bootstrap.utils import get_command


def _env_add(argv: list[str], python: bool, rust: bool, dart: bool, dry_run: bool) -> None:
    if dry_run:
        click.echo(
            styled([Style.BRIGHT, Fore.YELLOW], "Warning: ")
            + "--dry-run is not supported for env add; no package manager command was executed."
        )
        return

    if len(list(filter(None, [python, rust, dart]))) > 1:
        click.echo(
            styled([Style.BRIGHT, Fore.RED], "Invalid usage: ")
            + "Only one of --python, --dart/--flutter, --rust can be specified."
        )
        sys.exit(1)

    if python:
        if len(argv) == 0:
            click.echo(
                styled([Style.BRIGHT, Fore.RED], "Invalid usage: ") + "No package specified to add."
            )
            sys.exit(1)
        uv = get_command("uv")
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + f"uv add {' '.join(argv)}"
        )
        runtime.execute([uv, "add", *argv], "UV ADD OUTPUT")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Python package(s) added successfully."))
        return
    elif dart:
        if len(argv) == 0:
            click.echo(
                styled([Style.BRIGHT, Fore.RED], "Invalid usage: ") + "No package specified to add."
            )
            sys.exit(1)
        flutter = get_command("flutter")
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
            + f"flutter pub add {' '.join(argv)}"
        )
        runtime.execute([flutter, "pub", "add", *argv], "FLUTTER PUB ADD OUTPUT")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Dart package(s) added successfully."))
        return
    elif rust:
        if len(argv) == 0:
            click.echo(
                styled([Style.BRIGHT, Fore.RED], "Invalid usage: ") + "No package specified to add."
            )
            sys.exit(1)
        cargo = get_command("cargo")
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Executing command: ")
            + f"cargo add {' '.join(argv)}"
        )
        runtime.execute([cargo, "add", *argv], "CARGO ADD OUTPUT")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Rust package(s) added successfully."))
        return

    # parse arguments
    pkgs = {
        "python": {
            "norm": [],
            "dev": [],
        },
        "dart": [],
        "rust": {
            "norm": [],
            "dev": [],
            "build": [],
        },
        "unknown": [],
    }
    for arg in argv:
        if arg.startswith(("py:", "python:")):
            inner = arg.split(":", 1)[1].strip()
            if len(inner) == 0:
                pkgs["unknown"].append(arg)
            elif inner.startswith("dev:"):
                pkg = inner.split(":", 1)[1].strip()
                if len(pkg) == 0:
                    pkgs["unknown"].append(arg)
                else:
                    pkgs["python"]["dev"].append(pkg)
            else:
                pkgs["python"]["norm"].append(inner)
        elif arg.startswith(("dart:", "flutter:", "fl:")):
            inner = arg.split(":", 1)[1].strip()
            if len(inner) == 0:
                pkgs["unknown"].append(arg)
            else:
                pkgs["dart"].append(inner)
        elif arg.startswith(("rs:", "rust:")):
            inner = arg.split(":", 1)[1].strip()
            if len(inner) == 0:
                pkgs["unknown"].append(arg)
            elif inner.startswith("dev:"):
                pkg = inner.split(":", 1)[1].strip()
                if len(pkg) == 0:
                    pkgs["unknown"].append(arg)
                else:
                    pkgs["rust"]["dev"].append(pkg)
            elif inner.startswith("build:"):
                pkg = inner.split(":", 1)[1].strip()
                if len(pkg) == 0:
                    pkgs["unknown"].append(arg)
                else:
                    pkgs["rust"]["build"].append(pkg)
            else:
                pkgs["rust"]["norm"].append(inner)
        else:
            pkgs["unknown"].append(arg)

    if (x := sum(map(len, pkgs["python"].values()))) > 0:
        click.echo(
            styled(Fore.GREEN, "Adding ")
            + styled([Style.BRIGHT, Fore.GREEN], f"{x}")
            + styled(Fore.GREEN, f" python package{'s' if x > 1 else ''}.")
        )
        uv = get_command("uv")
        norm = pkgs["python"]["norm"]
        if len(norm) > 0:
            click.echo(
                f"  · Adding normal package{'s' if len(norm) > 1 else ''}: " + ", ".join(norm)
            )
            runtime.execute([uv, "add", *norm], "UV ADD OUTPUT (NORMAL)")

        dev = pkgs["python"]["dev"]
        if len(dev) > 0:
            click.echo(f"  · Adding dev package{'s' if len(dev) > 1 else ''}: " + ", ".join(dev))
            runtime.execute([uv, "add", "--dev", *dev], "UV ADD OUTPUT (DEV)")

    if (x := len(pkgs["dart"])) > 0:
        click.echo(
            styled(Fore.GREEN, "Adding ")
            + styled([Style.BRIGHT, Fore.GREEN], f"{x}")
            + styled(Fore.GREEN, f" dart package{'s' if x > 1 else ''}.")
        )
        flutter = get_command("flutter")
        click.echo(f"  · Adding package{'s' if x > 1 else ''}: " + ", ".join(pkgs["dart"]))
        runtime.execute([flutter, "pub", "add", *pkgs["dart"]], "FLUTTER PUB ADD OUTPUT")

    if (x := sum(map(len, pkgs["rust"].values()))) > 0:
        click.echo(
            styled(Fore.GREEN, "Adding ")
            + styled([Style.BRIGHT, Fore.GREEN], f"{x}")
            + styled(Fore.GREEN, f" rust package{'s' if x > 1 else ''}.")
        )
        cargo = get_command("cargo")
        norm = pkgs["rust"]["norm"]
        if len(norm) > 0:
            click.echo(
                f"  · Adding normal package{'s' if len(norm) > 1 else ''}: " + ", ".join(norm)
            )
            runtime.execute([cargo, "add", *norm], "CARGO ADD OUTPUT (NORMAL)")

        dev = pkgs["rust"]["dev"]
        if len(dev) > 0:
            click.echo(f"  · Adding dev package{'s' if len(dev) > 1 else ''}: " + ", ".join(dev))
            runtime.execute([cargo, "add", "--dev", *dev], "CARGO ADD OUTPUT (DEV)")

        build = pkgs["rust"]["build"]
        if len(build) > 0:
            click.echo(
                f"  · Adding build package{'s' if len(build) > 1 else ''}: " + ", ".join(build)
            )
            runtime.execute([cargo, "add", "--build", *build], "CARGO ADD OUTPUT (BUILD)")

    if (x := len(pkgs["unknown"])) > 0:
        click.echo(
            styled([Style.BRIGHT, Fore.YELLOW], "Warning: ")
            + f"{x} unknown argument{'s' if x > 1 else ''} ignored: "
            + ", ".join(pkgs["unknown"])
        )


_ENV_ADD_OPTIONS = [
    click.option(
        "--python",
        "--py",
        is_flag=True,
        default=False,
        help="Treat all arguments as python packages.\nThis will forward the command to `uv add`.",
    ),
    click.option(
        "--rust",
        "--rs",
        is_flag=True,
        default=False,
        help="Treat all arguments as rust packages.\nThis will forward the command to `cargo add`.",
    ),
    click.option(
        "--dart",
        "--flutter",
        "--fl",
        is_flag=True,
        default=False,
        help="Treat all arguments as dart packages.\nThis will forward the command to `flutter pub add`.",
    ),
    click.option(
        "--dry-run", is_flag=True, default=False, help="Show the command without executing."
    ),
]


def _apply_options(options):
    def decorator(func):
        for option in reversed(options):
            func = option(func)
        return func

    return decorator


def _quote_dotenv_value(value: object) -> str:
    text = str(value)
    if "'" in text or "\\\\" in text:
        escaped = text.replace("\\", "\\\\").replace('"', '\\"')
        return f'"{escaped}"'
    return "'" + text + "'"


def register_dev_commands(cli_group: click.Group) -> None:
    @cli_group.group()
    def dev():
        """Developer environment commands."""

    @dev.command("init-cfg")
    def dev_init_cfg():
        """Create efa.dev.toml from the example template."""
        if DEV_CONFIG_PATH.exists():
            click.echo(
                styled([Style.BRIGHT, Fore.YELLOW], "Warning: ") + "efa.dev.toml already exists."
            )
            return

        template = PROJECT_ROOT / "efa.dev.example.toml"
        shutil.copyfile(template, DEV_CONFIG_PATH)
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Created developer config: ") + str(DEV_CONFIG_PATH)
        )

    @dev.group()
    def env():
        """Developer environment setup commands."""

    @env.command("install")
    def dev_env_install():
        """Install all tools in the current environment."""
        runtime.env_install()
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Environment setup completed successfully."))

    @env.command("upgrade")
    def dev_env_upgrade():
        """Upgrade all tools in the current environment."""
        runtime.env_upgrade()
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Environment upgrade completed successfully.")
        )

    @env.command("write-backend")
    def dev_env_write_backend():
        """Write rust/lib/eve-fit-os/.env from efa.dev.toml."""
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        native = bootstrap.config.DEV_CONFIGURATION.native

        values = {
            "FSD_FORMAT": native.fsd_format,
            "FSD_BINARY_DIR": native.fsd_binary_dir,
            "FSD_LOC_EN_DIR": native.fsd_loc_en_dir,
            "OUTPUT_DIR": native.output_dir,
        }
        missing = [key for key, value in values.items() if value is None]
        if len(missing) > 0:
            raise click.ClickException(
                "Missing native developer config value(s): " + ", ".join(sorted(missing))
            )

        env_path = NATIVE_LIB_ROOT / ".env"
        lines = [f"{key}={_quote_dotenv_value(value)}" for key, value in values.items()]
        env_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Wrote backend env: ") + str(env_path))

    @env.command(
        "add",
        context_settings={
            "ignore_unknown_options": True,
            "allow_extra_args": True,
        },
    )
    @_apply_options(_ENV_ADD_OPTIONS)
    @click.pass_context
    def dev_env_add(ctx: click.Context, python, rust, dart, dry_run):
        """Add new tool to the current environment.

        This command accept the following syntax:

        \b
        If `--python`, `--py` is specified, then all arguments after it are treated as python packages to install.
            The command will be directly passed to `uv add`.
        If `--dart`, `--flutter`, `--fl` is specified, then all arguments after it are treated as dart packages to install.
            The command will be directly passed to `flutter pub add`.
        If `--rust`, `--rs` is specified, then all arguments after it are treated as rust packages to install.
            The command will be directly passed to `cargo add`.
        If none of the above is specified, then:
            If the package starts with `py:` or `python:`, it is treated as a python package to install.
                If the package starts with `dev:`, it is treated as a development dependency.
            If the package starts with `dart:`, `flutter:` or `fl:`, it is treated as a dart package to install.
                all package literals will be forwarded to `flutter pub add`.
            If the package starts with `rs:` or `rust:` it is treated as a rust package to install.
                If the package starts with `dev:`, it is treated as a development dependency.
                If the package starts with `build:`, it is treated as a build dependency.
            If not specified, the package won't be installed.
        """
        _env_add(list(ctx.args), python, rust, dart, dry_run)

    @cli_group.group()
    def environment():
        """Environment related commands. Prefer `x dev env`."""

    @environment.command(
        context_settings={
            "ignore_unknown_options": True,
            "allow_extra_args": True,
        }
    )
    @_apply_options(_ENV_ADD_OPTIONS)
    @click.pass_context
    def add(ctx: click.Context, python, rust, dart, dry_run):
        """Add new tool to the current environment. Prefer `x dev env add`."""
        _env_add(list(ctx.args), python, rust, dart, dry_run)

    @environment.command()
    def install():
        """Install all tools in the current environment. Prefer `x dev env install`."""
        runtime.env_install()
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Environment setup completed successfully."))

    @environment.command()
    def upgrade():
        """Upgrade all tools in the current environment. Prefer `x dev env upgrade`."""
        runtime.env_upgrade()
        click.echo(
            styled([Style.BRIGHT, Fore.GREEN], "Environment upgrade completed successfully.")
        )
