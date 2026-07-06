"""CI raw-data updater for EVE client builds."""

from __future__ import annotations

from bootstrap.data.updater.server import SERVER_ALIASES
from bootstrap.data.updater.server import ServerConfig
from bootstrap.data.updater.server import ServerId
from bootstrap.data.updater.server import get_server_config


__all__ = [
    "SERVER_ALIASES",
    "ServerConfig",
    "ServerId",
    "get_server_config",
]
