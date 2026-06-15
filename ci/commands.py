from __future__ import annotations

import json
import tarfile

from pathlib import Path

import click

from ci.lint import run_lint
from ci.suites import SUITE_DEFINITIONS
from ci.suites import calculate_ci_matrix
from click_aliases import ClickAliasedGroup
from colorama import Fore
from colorama import Style
from data.lib.color import styled
from data.lib.utils import execute_command
from data.lib.utils import get_command


def register_ci_commands(cli_group: click.Group) -> None:
    @cli_group.group(aliases=["c"], cls=ClickAliasedGroup)
    def ci():
        """CI/CD helper commands."""

    @ci.command("matrix")
    @click.option("--from-file", type=click.Path(exists=True), default=None)
    @click.option("--full", is_flag=True, default=False)
    def ci_matrix(from_file, full):
        """Calculate CI job matrix from changed files. Outputs JSON to stdout."""
        if full:
            suites = [
                {
                    "suite": s["suite"],
                    "shell": s["shell"],
                    "lint_command": s["lint_command"],
                    "command": s["command"],
                }
                for s in SUITE_DEFINITIONS
            ]
        elif from_file:
            with open(from_file) as f:
                files = [line.strip() for line in f if line.strip()]
            suites = calculate_ci_matrix(files)
        else:
            suites = []

        print(json.dumps(suites))

    @ci.command("lint")
    @click.option(
        "--lang",
        type=click.Choice(["all", "python", "dart", "rust", "site"]),
        default="all",
        help="Limit linting to a specific language (default: all).",
    )
    def ci_lint(lang: str):
        """Check formatting and linting without modifying files."""
        run_lint(lang, no_check=False, check_only=True, dry_run=False)

    @ci.command("pack-data")
    @click.option(
        "--output", "-o", default="cache/ci/ci-native-data.tar.gz", help="Output tarball path"
    )
    @click.option(
        "--upload", is_flag=True, default=False, help="Upload to CI storage after packing"
    )
    def ci_pack_data(output, upload):
        """Pack native CI data into a tarball for upload to CI storage."""
        import data.lib.config

        data.lib.config.DeveloperConfiguration.ensure_loaded()
        storage = data.lib.config.DEV_CONFIGURATION.ci.require_storage()
        native = data.lib.config.DEV_CONFIGURATION.native
        if native.output_dir is None:
            raise click.ClickException("Missing [native].output_dir in efa.dev.toml")

        output_dir = native.output_dir
        json_dir = output_dir / "json"
        pb2_dir = output_dir / "pb2"

        required_json = ["dogmaAttributes.json", "dogmaEffects.json"]
        required_pb2 = [
            "types.pb2",
            "dogmaAttributes.pb2",
            "dogmaEffects.pb2",
            "typeDogma.pb2",
            "dbuffcollections.pb2",
        ]

        missing = []
        for f in required_json:
            if not (json_dir / f).exists():
                missing.append(f"json/{f}")
        for f in required_pb2:
            if not (pb2_dir / f).exists():
                missing.append(f"pb2/{f}")

        if missing:
            raise click.ClickException(
                "Missing files (run `./x build data` first):\n  " + "\n  ".join(missing)
            )

        out_path = Path(output).resolve()
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with tarfile.open(out_path, "w:gz") as tar:
            for f in required_json:
                tar.add(json_dir / f, arcname=f"json/{f}")
            for f in required_pb2:
                tar.add(pb2_dir / f, arcname=f"pb2/{f}")

        total = len(required_json) + len(required_pb2)
        size_mb = out_path.stat().st_size / (1024 * 1024)
        click.echo(
            styled(
                [Style.BRIGHT, Fore.GREEN],
                f"Packed {total} files ({size_mb:.1f} MiB) -> {out_path}",
            )
        )

        remote_path = (
            f"{storage.alias}/{storage.bucket}/build-dependencies/ci-native-data.tar.gz"
        )

        if upload:
            mc = get_command("mc")
            execute_command(
                [
                    mc,
                    "alias",
                    "set",
                    storage.alias,
                    storage.endpoint,
                    storage.access_key,
                    storage.secret_key,
                ],
                "CI STORAGE ALIAS",
            )
            execute_command([mc, "cp", str(out_path), remote_path], "CI STORAGE UPLOAD")
        else:
            click.echo(f"Upload with: mc cp {out_path} {remote_path}")
