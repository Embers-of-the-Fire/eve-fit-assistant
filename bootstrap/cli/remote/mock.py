from __future__ import annotations

import os
import signal
import subprocess
import time

from pathlib import Path

import click

from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.cli import runtime
from bootstrap.cli.remote.helpers import run_foreground
from bootstrap.cli.remote.helpers import wait_for_http
from bootstrap.color import styled
from bootstrap.remote.s3client import S3Client
from bootstrap.utils import get_command


_PROTECTED_PATHS: tuple[Path, ...] | None = None


def _get_protected_paths() -> tuple[Path, ...]:
    global _PROTECTED_PATHS
    if _PROTECTED_PATHS is None:
        cfg = bootstrap.config.DEV_CONFIGURATION
        dev_root = cfg.paths.root.resolve()
        _PROTECTED_PATHS = (
            Path("/"),
            Path.home(),
            dev_root,
        )
    return _PROTECTED_PATHS


def _is_safe_rmtree_target(path: Path) -> bool:
    resolved = path.resolve()
    if not resolved.is_dir():
        raise click.ClickException(f"Refusing to remove non-directory path: {resolved}")
    protected = _get_protected_paths()
    for p in protected:
        # Refuse when the target IS a protected path or an ancestor of one
        # (deleting it would wipe protected data); nested targets are fine.
        if resolved == p or resolved in p.parents:
            raise click.ClickException(
                f"Refusing to remove protected path: {resolved} (conflicts with {p})"
            )
    return True


def _default_daemon_paths(data_dir: Path, pid_file: Path | None, log_file: Path | None):
    resolved_pid = pid_file or data_dir.parent / f"{data_dir.name}.pid"
    resolved_log = log_file or data_dir.parent / f"{data_dir.name}.log"
    return resolved_pid, resolved_log


def _is_stale_pid_error(exc: BaseException) -> bool:
    if isinstance(exc, ProcessLookupError):
        return True
    return isinstance(exc, OSError) and getattr(exc, "winerror", None) == 87


def _start_s3_mock(
    *,
    host: str,
    port: int,
    console_port: int,
    data_dir: Path,
    bucket: str,
    access_key: str,
    secret_key: str,
    public_download: bool,
    daemon: bool = False,
    pid_file: Path | None = None,
    log_file: Path | None = None,
) -> None:
    data_dir.mkdir(parents=True, exist_ok=True)
    endpoint = f"http://{host}:{port}"
    console_endpoint = f"http://{host}:{console_port}"
    command = [
        "rustfs",
        str(data_dir),
        "--address",
        f"{host}:{port}",
        "--console-address",
        f"{host}:{console_port}",
    ]
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + " ".join(command))
    if runtime.is_dry_run():
        return

    rustfs = get_command("rustfs")
    command[0] = rustfs
    env = os.environ.copy()
    env["RUSTFS_ACCESS_KEY"] = access_key
    env["RUSTFS_SECRET_KEY"] = secret_key
    if daemon:
        resolved_pid, resolved_log = _default_daemon_paths(data_dir, pid_file, log_file)
        with open(resolved_log, "a", encoding="utf-8") as log_handle:
            process = subprocess.Popen(
                command,
                env=env,
                stdin=subprocess.DEVNULL,
                stdout=log_handle,
                stderr=subprocess.STDOUT,
                start_new_session=True,
            )
    else:
        process = subprocess.Popen(command, env=env, text=True)
    try:
        wait_for_http(f"{endpoint}/health/ready")

        client = S3Client(
            endpoint=endpoint,
            bucket=bucket,
            access_key=access_key,
            secret_key=secret_key,
        )
        client.create_bucket()
        client.set_public_download(public_download)

        click.echo(
            styled(
                Style.DIM,
                "  No pre-existing data published. Use `./x remote session` to build from scratch.",
            )
        )
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "RustFS console: ") + console_endpoint)
        if daemon:
            resolved_pid.write_text(f"{process.pid}\n", encoding="utf-8")
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "RustFS endpoint: ") + endpoint)
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "RustFS PID: ") + f"{process.pid}")
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "RustFS PID file: ") + str(resolved_pid))
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "RustFS log file: ") + str(resolved_log))
            click.echo(
                styled(Style.DIM, "  Detached. Stop with `./x remote mock stop` or kill the PID.")
            )
            return
        run_foreground(process, "\nRustFS remote mock interrupted by user.")
    except Exception:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait()
        raise


def _remove_mock_path(path: Path, label: str) -> bool:
    if not path.exists():
        return False
    _is_safe_rmtree_target(path)
    click.echo(styled(Style.DIM, f"  Removing {label}: {path}"))
    import shutil

    shutil.rmtree(path)
    return True


def register_remote_mock(remote: click.Group) -> None:
    @remote.group()
    def mock():
        """Remote mock origin commands."""

    @mock.command("clean")
    @click.option("--origin-dir", type=click.Path(path_type=Path), default=None)
    @click.option("--data-dir", type=click.Path(path_type=Path), default=None)
    def remote_mock_clean(origin_dir: Path | None, data_dir: Path | None):
        """Remove all persisted remote mock data (mock storage + origin directory)."""
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote
        mock_cfg = remote_cfg.require_mock("clean")

        resolved_data_dir = runtime.resolve_dev_path(data_dir or mock_cfg.data_dir)
        resolved_origin_dir = runtime.resolve_dev_path(origin_dir or remote_cfg.mock_origin_dir)

        any_removed = False
        if _remove_mock_path(resolved_data_dir, "mock data directory"):
            any_removed = True
        if _remove_mock_path(resolved_origin_dir, "mock origin directory"):
            any_removed = True

        if any_removed:
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "Remote mock cleaned."))
        else:
            click.echo(styled(Style.DIM, "Nothing to clean."))

    @mock.command("stop")
    @click.option("--data-dir", type=click.Path(path_type=Path), default=None)
    @click.option("--pid-file", type=click.Path(path_type=Path), default=None)
    def remote_mock_stop(data_dir: Path | None, pid_file: Path | None):
        """Stop a detached remote mock started with `launch --daemon`."""
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote
        mock_cfg = remote_cfg.require_mock("stop")

        resolved_data_dir = runtime.resolve_dev_path(data_dir or mock_cfg.data_dir)
        resolved_pid_file = runtime.resolve_dev_path(pid_file) if pid_file else None
        resolved_pid, _ = _default_daemon_paths(resolved_data_dir, resolved_pid_file, None)

        if not resolved_pid.is_file():
            click.echo(styled(Style.DIM, "No PID file found; nothing to stop."))
            return

        pid = int(resolved_pid.read_text(encoding="utf-8").strip())
        try:
            os.kill(pid, signal.SIGTERM)
        except OSError as exc:
            if _is_stale_pid_error(exc):
                click.echo(
                    styled(Style.DIM, f"Process {pid} is not running; removing stale PID file.")
                )
                resolved_pid.unlink(missing_ok=True)
                return
            raise

        for _ in range(40):
            try:
                os.kill(pid, 0)
            except OSError as exc:
                if _is_stale_pid_error(exc):
                    break
                raise
            time.sleep(0.25)
        else:
            try:
                os.kill(pid, getattr(signal, "SIGKILL", signal.SIGTERM))
            except OSError as exc:
                if not _is_stale_pid_error(exc):
                    raise

        resolved_pid.unlink(missing_ok=True)
        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Stopped remote mock (pid {pid})."))

    @mock.command("launch")
    @click.option("--host", default=None, help="Override remote mock host.")
    @click.option("--port", type=int, default=None, help="Override mock S3 API port.")
    @click.option("--console-port", type=int, default=None, help="Override mock console port.")
    @click.option("--bucket", default=None, help="Override mock bucket name.")
    @click.option("--access-key", default=None, help="Override mock access key.")
    @click.option("--secret-key", default=None, help="Override mock secret key.")
    @click.option("--data-dir", type=click.Path(path_type=Path), default=None)
    @click.option(
        "--public-download/--private",
        "public_download",
        default=None,
        help="Configure anonymous bucket downloads.",
    )
    @click.option(
        "--daemon",
        is_flag=True,
        default=False,
        help="Detach after startup instead of running in the foreground.",
    )
    @click.option(
        "--pid-file",
        type=click.Path(path_type=Path),
        default=None,
        help="PID file path for --daemon (default: <data-dir>.pid).",
    )
    @click.option(
        "--log-file",
        type=click.Path(path_type=Path),
        default=None,
        help="Log file path for --daemon (default: <data-dir>.log).",
    )
    def remote_mock_launch(
        host: str | None,
        port: int | None,
        console_port: int | None,
        bucket: str | None,
        access_key: str | None,
        secret_key: str | None,
        data_dir: Path | None,
        public_download: bool | None,
        daemon: bool,
        pid_file: Path | None,
        log_file: Path | None,
    ):
        """Launch a local RustFS remote mock against persisted storage.

        No pre-existing data is published - use `./x remote session` commands
        to build data from scratch. Run `./x remote mock clean` first to
        start with a completely empty store.
        """
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        bootstrap.config.ProjectConfiguration.ensure_loaded()
        remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote
        mock_cfg = remote_cfg.require_mock("mock")

        resolved_host = host or remote_cfg.host
        resolved_data_dir = runtime.resolve_dev_path(data_dir or mock_cfg.data_dir)
        resolved_port = port or mock_cfg.port
        resolved_console_port = console_port or mock_cfg.console_port
        resolved_bucket = bucket or mock_cfg.bucket
        resolved_access_key = (
            access_key
            if access_key
            else (mock_cfg.access_key.get_secret_value() if mock_cfg.access_key else "")
        )
        resolved_secret_key = (
            secret_key
            if secret_key
            else (mock_cfg.secret_key.get_secret_value() if mock_cfg.secret_key else "")
        )
        resolved_public_download = (
            public_download if public_download is not None else mock_cfg.public_download
        )
        resolved_pid_file = runtime.resolve_dev_path(pid_file) if pid_file else None
        resolved_log_file = runtime.resolve_dev_path(log_file) if log_file else None

        click.echo(styled([Style.BRIGHT, Fore.GREEN], "Mock data path: ") + str(resolved_data_dir))
        click.echo(
            styled(
                Style.DIM,
                "  Using persisted storage. Run `./x remote mock clean` for a fresh start.",
            )
        )
        _start_s3_mock(
            host=resolved_host,
            port=resolved_port,
            console_port=resolved_console_port,
            data_dir=resolved_data_dir,
            bucket=resolved_bucket,
            access_key=resolved_access_key,
            secret_key=resolved_secret_key,
            public_download=resolved_public_download,
            daemon=daemon,
            pid_file=resolved_pid_file,
            log_file=resolved_log_file,
        )
