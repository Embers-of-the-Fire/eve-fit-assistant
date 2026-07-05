"""Server definitions and URL builders for the CI raw-data updater."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal


ServerId = Literal["tranquility", "serenity", "singularity"]
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
    fsd_dumper_server: Literal["tq", "se"]


def get_server_config(server_id: ServerId) -> ServerConfig:
    """Return the configuration for the given server."""
    if server_id == "tranquility":
        return ServerConfig(
            id=server_id,
            manifest_url="https://binaries.eveonline.com/eveclient_TQ.json",
            index_url_template="https://binaries.eveonline.com/eveonline_{build}.txt",
            binary_download_url="https://binaries.eveonline.com/{resource_url}",
            resource_download_url="https://resources.eveonline.com/{resource_url}",
            index_file_name="index_tranquility.txt",
            fsd_dumper_server="tq",
        )
    if server_id == "singularity":
        return ServerConfig(
            id=server_id,
            manifest_url="https://binaries.eveonline.com/eveclient_SISI.json",
            index_url_template="https://binaries.eveonline.com/eveonline_{build}.txt",
            binary_download_url="https://binaries.eveonline.com/{resource_url}",
            resource_download_url="https://resources.eveonline.com/{resource_url}",
            index_file_name="index_singularity.txt",
            fsd_dumper_server="tq",
        )
    if server_id == "serenity":
        return ServerConfig(
            id=server_id,
            manifest_url=(
                "http://eve-china-version-files.oss-cn-hangzhou.aliyuncs.com/"
                "eveclient_SERENITY.json"
            ),
            index_url_template=(
                "http://eve-china-version-files.oss-cn-hangzhou.aliyuncs.com/eveonline_{build}.txt"
            ),
            binary_download_url="https://ma79.gdl.netease.com/eve/binaries/{resource_url}",
            resource_download_url="https://ma79.gdl.netease.com/eve/resources/{resource_url}",
            index_file_name="index_serenity.txt",
            fsd_dumper_server="se",
        )
    raise ValueError(f"Unknown server id: {server_id}")
