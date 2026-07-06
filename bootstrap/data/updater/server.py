"""Server definitions and URL builders for the CI raw-data updater."""

from __future__ import annotations

import tomllib

from dataclasses import dataclass
from typing import TYPE_CHECKING

from bootstrap.constant import PROJECT_ROOT


if TYPE_CHECKING:
    from pathlib import Path


ServerId = str
SERVER_ALIASES = {"tq": "tranquility", "se": "serenity", "sisi": "singularity"}


@dataclass(frozen=True)
class ServerConfig:
    """Configuration for a single EVE server data source."""

    id: ServerId
    manifest_url: str
    index_url_template: str
    binary_download_url: str
    resource_download_url: str
    index_file_name: str
    fsd_dumper_server: str


def _discover_server_ids(resources_root: Path | None = None) -> frozenset[str]:
    """Return the set of server ids declared under ``data/resources``.

    A resource directory is treated as a server when its ``descriptor.toml`` has
    ``metadata.server = true`` and is not ignored.
    """
    if resources_root is None:
        resources_root = PROJECT_ROOT / "data" / "resources"
    if not resources_root.is_dir():
        return frozenset()

    server_ids: set[str] = set()
    for entry in resources_root.iterdir():
        if not entry.is_dir():
            continue
        descriptor_path = entry / "descriptor.toml"
        if not descriptor_path.is_file():
            continue
        try:
            with open(descriptor_path, "rb") as f:
                data = tomllib.load(f)
        except Exception:
            continue
        if data.get("ignore", False):
            continue
        metadata = data.get("metadata") or {}
        if metadata.get("server", False):
            identifier = metadata.get("identifier")
            if isinstance(identifier, str) and identifier:
                server_ids.add(identifier)
    return frozenset(server_ids)


def _build_server_configs() -> dict[str, ServerConfig]:
    """Return the static server configuration table keyed by server id."""
    return {
        "tranquility": ServerConfig(
            id="tranquility",
            manifest_url="https://binaries.eveonline.com/eveclient_TQ.json",
            index_url_template="https://binaries.eveonline.com/eveonline_{build}.txt",
            binary_download_url="https://binaries.eveonline.com/{resource_url}",
            resource_download_url="https://resources.eveonline.com/{resource_url}",
            index_file_name="index_tranquility.txt",
            fsd_dumper_server="tq",
        ),
        "singularity": ServerConfig(
            id="singularity",
            manifest_url="https://binaries.eveonline.com/eveclient_SISI.json",
            index_url_template="https://binaries.eveonline.com/eveonline_{build}.txt",
            binary_download_url="https://binaries.eveonline.com/{resource_url}",
            resource_download_url="https://resources.eveonline.com/{resource_url}",
            index_file_name="index_singularity.txt",
            fsd_dumper_server="tq",
        ),
        "serenity": ServerConfig(
            id="serenity",
            manifest_url=(
                "https://eve-china-version-files.oss-cn-hangzhou.aliyuncs.com/"
                "eveclient_SERENITY.json"
            ),
            index_url_template=(
                "https://eve-china-version-files.oss-cn-hangzhou.aliyuncs.com/eveonline_{build}.txt"
            ),
            binary_download_url="https://ma79.gdl.netease.com/eve/binaries/{resource_url}",
            resource_download_url="https://ma79.gdl.netease.com/eve/resources/{resource_url}",
            index_file_name="index_serenity.txt",
            fsd_dumper_server="se",
        ),
    }


SERVER_IDS = _discover_server_ids()
_SERVER_CONFIGS = _build_server_configs()


def _validate_server_definitions() -> None:
    """Fail fast if the code and the resource tree disagree on server ids."""
    alias_targets = set(SERVER_ALIASES.values())
    unknown_aliases = alias_targets - SERVER_IDS
    if unknown_aliases:
        raise RuntimeError(
            f"SERVER_ALIASES references unknown server ids: {sorted(unknown_aliases)}"
        )

    configured = set(_SERVER_CONFIGS.keys())
    missing_configs = SERVER_IDS - configured
    extra_configs = configured - SERVER_IDS
    if missing_configs or extra_configs:
        raise RuntimeError(
            f"Server config mismatch: missing={sorted(missing_configs)} "
            f"extra={sorted(extra_configs)}"
        )


_validate_server_definitions()


def resolve_server_id(server_id: str) -> ServerId:
    """Normalize a server identifier to its canonical form."""
    normalized = SERVER_ALIASES.get(server_id.lower(), server_id.lower())
    if normalized in SERVER_IDS:
        return normalized
    raise ValueError(f"Unknown server id: {server_id}")


def get_server_config(server_id: ServerId) -> ServerConfig:
    """Return the configuration for the given server."""
    if server_id not in SERVER_IDS:
        raise ValueError(f"Unknown server id: {server_id}")
    config = _SERVER_CONFIGS.get(server_id)
    if config is None:
        raise ValueError(f"Unknown server id: {server_id}")
    return config


def list_server_ids() -> list[ServerId]:
    """Return all canonical server ids in a stable order."""
    return sorted(SERVER_IDS)


def _reset_for_tests(resources_root: Path | None = None) -> None:
    """Internal hook used by tests to recompute server ids from a fake tree."""
    global SERVER_IDS
    SERVER_IDS = _discover_server_ids(resources_root)
    _validate_server_definitions()


__all__ = [
    "SERVER_ALIASES",
    "SERVER_IDS",
    "ServerConfig",
    "ServerId",
    "get_server_config",
    "list_server_ids",
    "resolve_server_id",
]
