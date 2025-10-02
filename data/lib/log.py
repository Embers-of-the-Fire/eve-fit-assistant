from __future__ import annotations

import logging
import sys

import data.lib.config


LOGGER = logging.getLogger("EFA")

if len(LOGGER.handlers) == 0:
    data.lib.config.ProjectConfiguration.ensure_loaded()

    LOGGER.setLevel(logging.DEBUG)
    file_handler = logging.FileHandler(
        data.lib.config.CONFIGURATION.paths.log, mode="w", encoding="utf-8"
    )
    file_handler.setLevel(logging.DEBUG)

    console_handler = logging.StreamHandler(sys.stderr)
    console_handler.setLevel(logging.INFO)

    file_formatter = logging.Formatter("[%(asctime)s] [%(levelname)s] [%(pathname)s]: %(message)s")
    file_handler.setFormatter(file_formatter)

    console_formatter = logging.Formatter("[%(levelname)s]: %(message)s")
    console_handler.setFormatter(console_formatter)

    LOGGER.addHandler(file_handler)
    LOGGER.addHandler(console_handler)

info = LOGGER.info
warning = LOGGER.warning
error = LOGGER.error
debug = LOGGER.debug
critical = LOGGER.critical
