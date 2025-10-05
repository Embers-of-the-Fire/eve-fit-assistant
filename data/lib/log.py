from __future__ import annotations

import logging
import sys
import time

from typing import ClassVar

from colorama import Back
from colorama import Fore
from colorama import Style

import data.lib.config

from data.lib.color import styled


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

if len(LOGGER.handlers) == 0:
    data.lib.config.ProjectConfiguration.ensure_loaded()
    if not data.lib.config.CONFIGURATION.paths.log.exists():
        data.lib.config.CONFIGURATION.paths.log.mkdir(parents=True, exist_ok=True)

    LOGGER.setLevel(logging.DEBUG)
    log_filename = f"{time.strftime('%Y%m%d-%H%M%S')}.log"
    file_handler = logging.FileHandler(
        data.lib.config.CONFIGURATION.paths.log / log_filename, mode="w", encoding="utf-8"
    )
    file_handler.setLevel(logging.DEBUG)

    console_handler = logging.StreamHandler(sys.stderr)
    console_handler.setLevel(logging.INFO)

    file_formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] [%(pathname)s]: %(message)s")
    file_handler.setFormatter(file_formatter)

    console_handler.setFormatter(ColoredTerminalFormatter())

    LOGGER.addHandler(file_handler)
    LOGGER.addHandler(console_handler)

info = LOGGER.info
warning = LOGGER.warning
error = LOGGER.error
debug = LOGGER.debug
critical = LOGGER.critical
