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
        if resolved == p or p in resolved.parents:
            raise click.ClickException(
                f"Refusing to remove protected path: {resolved} (conflicts with {p})"
            )
    return True


def _default_daemon_paths(data_dir: Path, pid_file: Path | None, log_file: Path | None):
    resolved_pid = pid_file or data_dir.parent / f"{data_dir.name}.pid"
    resolved_log = log_file or data_dir.parent / f"{data_dir.name}.log"
    return resolved_pid, resolved_log


def _start_minio_remote_mock(
    *,
    host: str,
    port: int,
    console_port: int,
    data_dir: Path,
    bucket: str,
    access_key: str,
    secret_key: str,
    alias_name: str,
    public_download: bool,
    daemon: bool = False,
    pid_file: Path | None = None,
    log_file: Path | None = None,
) -> None:
    data_dir.mkdir(parents=True, exist_ok=True)
    endpoint = f"http://{host}:{port}"
    console_endpoint = f"http://{host}:{console_port}"
    command = [
        "minio",
        "server",
        str(data_dir),
        "--address",
        f"{host}:{port}",
        "--console-address",
        f"{host}:{console_port}",
    ]
    click.echo(styled([Style.BRIGHT, Fore.GREEN], "Executing command: ") + " ".join(command))
    if runtime.is_dry_run():
        return

    minio = get_command("minio")
    command[0] = minio
    env = os.environ.copy()
    env["MINIO_ROOT_USER"] = access_key
    env["MINIO_ROOT_PASSWORD"] = secret_key
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
        wait_for_http(f"{endpoint}/minio/health/ready")

        mc = get_command("mc")
        bucket_target = f"{alias_name}/{bucket}"
        redacted = "<redacted>"
        runtime.execute_redacted(
            [mc, "alias", "set", alias_name, endpoint, access_key, secret_key, "--api", "s3v4"],
            [mc, "alias", "set", alias_name, endpoint, redacted, redacted, "--api", "s3v4"],
            "REMOTE MOCK ALIAS",
        )
        runtime.execute(
            [mc, "mb", "--ignore-existing", bucket_target],
            "REMOTE MOCK BUCKET",
        )
        if public_download:
            runtime.execute(
                [mc, "anonymous", "set", "download", bucket_target],
                "REMOTE MOCK ANONYMOUS",
            )
        else:
            runtime.execute(
                [mc, "anonymous", "set", "none", bucket_target],
                "REMOTE MOCK ANONYMOUS",
            )

        click.echo(
            styled(
                Style.DIM,
                "  No pre-existing data published. Use `./x remote session` to build from scratch.",
            )
        )
        click.echo(styled([Style.BRIGHT, Fore.GREEN], "MinIO console: ") + console_endpoint)
        if daemon:
            resolved_pid.write_text(f"{process.pid}\n", encoding="utf-8")
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "MinIO endpoint: ") + endpoint)
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "MinIO PID: ") + f"{process.pid}")
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "MinIO PID file: ") + str(resolved_pid))
            click.echo(styled([Style.BRIGHT, Fore.GREEN], "MinIO log file: ") + str(resolved_log))
            click.echo(
                styled(Style.DIM, "  Detached. Stop with `./x remote mock stop` or kill the PID.")
            )
            return
        run_foreground(process, "\nMinIO remote mock interrupted by user.")
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
        """Remove all persisted remote mock data (MinIO storage + origin directory)."""
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote
        minio = remote_cfg.require_minio("clean")

        resolved_data_dir = runtime.resolve_dev_path(data_dir or minio.data_dir)
        resolved_origin_dir = runtime.resolve_dev_path(origin_dir or remote_cfg.mock_origin_dir)

        any_removed = False
        if _remove_mock_path(resolved_data_dir, "MinIO data directory"):
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
        """Stop a detached MinIO remote mock started with `launch --daemon`."""
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote
        minio = remote_cfg.require_minio("stop")

        resolved_data_dir = runtime.resolve_dev_path(data_dir or minio.data_dir)
        resolved_pid_file = runtime.resolve_dev_path(pid_file) if pid_file else None
        resolved_pid, _ = _default_daemon_paths(resolved_data_dir, resolved_pid_file, None)

        if not resolved_pid.is_file():
            click.echo(styled(Style.DIM, "No PID file found; nothing to stop."))
            return

        pid = int(resolved_pid.read_text(encoding="utf-8").strip())
        try:
            os.kill(pid, signal.SIGTERM)
        except ProcessLookupError:
            click.echo(styled(Style.DIM, f"Process {pid} is not running; removing stale PID file."))
            resolved_pid.unlink()
            return

        for _ in range(40):
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                break
            time.sleep(0.25)
        else:
            os.kill(pid, getattr(signal, "SIGKILL", signal.SIGTERM))

        resolved_pid.unlink(missing_ok=True)
        click.echo(styled([Style.BRIGHT, Fore.GREEN], f"Stopped MinIO mock (pid {pid})."))

    @mock.command("launch")
    @click.option("--host", default=None, help="Override remote mock host.")
    @click.option("--port", type=int, default=None, help="Override MinIO API port.")
    @click.option("--console-port", type=int, default=None, help="Override MinIO console port.")
    @click.option("--bucket", default=None, help="Override MinIO bucket name.")
    @click.option("--access-key", default=None, help="Override MinIO access key.")
    @click.option("--secret-key", default=None, help="Override MinIO secret key.")
    @click.option("--alias", "alias_name", default=None, help="Override mc alias name.")
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
        alias_name: str | None,
        data_dir: Path | None,
        public_download: bool | None,
        daemon: bool,
        pid_file: Path | None,
        log_file: Path | None,
    ):
        """Launch a local MinIO remote mock against persisted storage.

        No pre-existing data is published - use `./x remote session` commands
        to build data from scratch. Run `./x remote mock clean` first to
        start with a completely empty store.
        """
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        bootstrap.config.ProjectConfiguration.ensure_loaded()
        remote_cfg = bootstrap.config.DEV_CONFIGURATION.remote
        minio = remote_cfg.require_minio("mock")

        resolved_host = host or remote_cfg.host
        resolved_data_dir = runtime.resolve_dev_path(data_dir or minio.data_dir)
        resolved_port = port or minio.port
        resolved_console_port = console_port or minio.console_port
        resolved_bucket = bucket or minio.bucket
        resolved_access_key = (
            access_key
            if access_key
            else (minio.access_key.get_secret_value() if minio.access_key else "")
        )
        resolved_secret_key = (
            secret_key
            if secret_key
            else (minio.secret_key.get_secret_value() if minio.secret_key else "")
        )
        resolved_alias = alias_name or minio.alias
        resolved_public_download = (
            public_download if public_download is not None else minio.public_download
        )
        resolved_pid_file = runtime.resolve_dev_path(pid_file) if pid_file else None
        resolved_log_file = runtime.resolve_dev_path(log_file) if log_file else None

        click.echo(styled([Style.BRIGHT, Fore.GREEN], "MinIO data path: ") + str(resolved_data_dir))
        click.echo(
            styled(
                Style.DIM,
                "  Using persisted storage. Run `./x remote mock clean` for a fresh start.",
            )
        )
        _start_minio_remote_mock(
            host=resolved_host,
            port=resolved_port,
            console_port=resolved_console_port,
            data_dir=resolved_data_dir,
            bucket=resolved_bucket,
            access_key=resolved_access_key,
            secret_key=resolved_secret_key,
            alias_name=resolved_alias,
            public_download=resolved_public_download,
            daemon=daemon,
            pid_file=resolved_pid_file,
            log_file=resolved_log_file,
        )
