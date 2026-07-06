from __future__ import annotations

import logging
import sys
import time

from typing import ClassVar

from colorama import Back
from colorama import Fore
from colorama import Style

import bootstrap.config

from bootstrap.color import styled


class ColoredTerminalFormatter(logging.Formatter):
    MESSAGE_FORMAT = " %(message)s"
    LEVELNAME_FORMAT = "[%(levelname)s]"
    FORMATS: ClassVar[dict[int, str]] = {
        logging.INFO: styled([Style.BRIGHT, Fore.GREEN], LEVELNAME_FORMAT),
        logging.WARNING: styled([Style.BRIGHT, Fore.YELLOW], LEVELNAME_FORMAT),
        logging.ERROR: styled([Style.BRIGHT, Fore.RED], LEVELNAME_FORMAT),
        logging.DEBUG: styled([Style.DIM, Fore.BLUE], LEVELNAME_FORMAT),
        logging.CRITICAL: styled([Style.BRIGHT, Fore.BLACK, Back.RED], LEVELNAME_FORMAT),
    }

    def format(self, record):
        fmt = (
            ColoredTerminalFormatter.FORMATS.get(
                record.levelno,
                ColoredTerminalFormatter.LEVELNAME_FORMAT,
            )
            + ColoredTerminalFormatter.MESSAGE_FORMAT
        )
        return logging.Formatter(fmt).format(record)


LOGGER = logging.getLogger("EFA")


def _ensure_handlers() -> None:
    """Initialize logging handlers lazily on first use.

    Import-time config loading caused ``--dev-env`` overrides to be ignored,
    because the CLI registers those overrides only after the command modules
    have been imported. Lazy initialization ensures the first log call triggers
    config load after overrides are in place.
    """
    if LOGGER.handlers:
        return

    try:
        bootstrap.config.ProjectConfiguration.ensure_loaded()
        bootstrap.config.DeveloperConfiguration.ensure_loaded()
        log_path = bootstrap.config.DEV_CONFIGURATION.paths.log_path
        if not log_path.exists():
            log_path.mkdir(parents=True, exist_ok=True)

        LOGGER.setLevel(logging.DEBUG)
        log_filename = f"{time.strftime('%Y%m%d-%H%M%S')}.log"
        file_handler = logging.FileHandler(log_path / log_filename, mode="w", encoding="utf-8")
        file_handler.setLevel(logging.DEBUG)

        console_handler = logging.StreamHandler(sys.stderr)
        console_handler.setLevel(logging.INFO)

        file_formatter = logging.Formatter(
            "[%(asctime)s] [%(levelname)s] [%(pathname)s]: %(message)s"
        )
        file_handler.setFormatter(file_formatter)

        console_handler.setFormatter(ColoredTerminalFormatter())

        LOGGER.addHandler(file_handler)
        LOGGER.addHandler(console_handler)
    except Exception as exc:
        # Config or filesystem setup failed. Install a minimal stderr fallback
        # so the message being logged (often from an ``except`` block) is not
        # swallowed by this secondary failure.
        fallback = logging.StreamHandler(sys.stderr)
        fallback.setLevel(logging.NOTSET)
        fallback.setFormatter(logging.Formatter("[%(levelname)s] %(message)s"))
        LOGGER.setLevel(logging.DEBUG)
        LOGGER.addHandler(fallback)
        fallback.emit(
            logging.LogRecord(
                name=LOGGER.name,
                level=logging.WARNING,
                pathname=__file__,
                lineno=0,
                msg="Logging setup failed, using stderr fallback: %s",
                args=(exc,),
                exc_info=None,
            )
        )


def info(msg: object, *args, **kwargs) -> None:
    _ensure_handlers()
    kwargs.setdefault("stacklevel", 2)
    LOGGER.info(msg, *args, **kwargs)


def warning(msg: object, *args, **kwargs) -> None:
    _ensure_handlers()
    kwargs.setdefault("stacklevel", 2)
    LOGGER.warning(msg, *args, **kwargs)


def error(msg: object, *args, **kwargs) -> None:
    _ensure_handlers()
    kwargs.setdefault("stacklevel", 2)
    LOGGER.error(msg, *args, **kwargs)


def debug(msg: object, *args, **kwargs) -> None:
    _ensure_handlers()
    kwargs.setdefault("stacklevel", 2)
    LOGGER.debug(msg, *args, **kwargs)


def critical(msg: object, *args, **kwargs) -> None:
    _ensure_handlers()
    kwargs.setdefault("stacklevel", 2)
    LOGGER.critical(msg, *args, **kwargs)
