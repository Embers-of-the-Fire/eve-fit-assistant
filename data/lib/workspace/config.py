from __future__ import annotations

import tomllib

from pathlib import Path  # noqa:TC003
from typing import Literal

from pydantic import BaseModel
from pydantic import Field

from data.lib.log import error
from data.lib.log import warning


class WorkspacePaths(BaseModel):
    fsd: Path

    def resolve(self, descriptor_root: Path, no_check: bool = False):
        if not self.fsd.is_absolute():
            self.fsd = (descriptor_root / self.fsd).resolve()

        if no_check:
            return

        if not self.fsd.exists():
            error(f"FSD path does not exist: {self.fsd}")
        if not self.fsd.is_dir():
            error(f"FSD path is not a directory: {self.fsd}")


class WorkspaceMetadata(BaseModel):
    start_cfg: Path
    name: dict[Literal["en", "zh"], str]

    def resolve(self, descriptor_root: Path, no_check: bool = False):
        if not self.start_cfg.is_absolute():
            self.start_cfg = (descriptor_root / self.start_cfg).resolve()

        if no_check:
            return

        if not self.start_cfg.exists():
            error(f"Start configuration file does not exist: {self.start_cfg}")
            exit(1)
        if not self.start_cfg.is_file():
            error(f"Start configuration path is not a file: {self.start_cfg}")
            exit(1)

        en_name = self.name.get("en")
        zh_name = self.name.get("zh")
        if not en_name and not zh_name:
            error("At least one of the workspace names (en or zh) must be provided.")
            exit(1)
        if en_name and not zh_name:
            warning("Chinese name (zh) is missing; defaulting to English name.")
        if zh_name and not en_name:
            warning("English name (en) is missing; defaulting to Chinese name.")


class WorkspaceResources(BaseModel):
    resource_index: Path
    application_index: Path

    def resolve(self, descriptor_root: Path, no_check: bool = False):
        if not self.resource_index.is_absolute():
            self.resource_index = (descriptor_root / self.resource_index).resolve()
        if not self.application_index.is_absolute():
            self.application_index = (descriptor_root / self.application_index).resolve()

        if no_check:
            return

        if not self.resource_index.exists():
            error(f"Resource index file does not exist: {self.resource_index}")
            exit(1)
        if not self.resource_index.is_file():
            error(f"Resource index path is not a file: {self.resource_index}")
            exit(1)

        if not self.application_index.exists():
            error(f"Application index file does not exist: {self.application_index}")
            exit(1)
        if not self.application_index.is_file():
            error(f"Application index path is not a file: {self.application_index}")
            exit(1)


class WorkspaceConfig(BaseModel):
    ignore: bool = Field(default=False)
    paths: WorkspacePaths
    metadata: WorkspaceMetadata
    resources: WorkspaceResources

    @staticmethod
    def load_from_descriptor(descriptor_path: Path, no_check: bool = False) -> WorkspaceConfig:
        if not descriptor_path.exists():
            error(f"Descriptor file does not exist: {descriptor_path}")
            exit(1)
        if not descriptor_path.is_file():
            error(f"Descriptor path is not a file: {descriptor_path}")
            exit(1)

        try:
            with open(descriptor_path, "rb") as f:
                cfg = tomllib.load(f)
        except Exception as e:
            error(f"Failed to read or parse descriptor file: {e!r}")
            exit(1)

        try:
            workspace_config = WorkspaceConfig.model_validate(cfg)
        except Exception as e:
            error(f"Failed to validate workspace configuration: {e!r}")
            exit(1)

        workspace_config.resolve(descriptor_path.parent, no_check)
        return workspace_config

    def resolve(self, descriptor_root: Path, no_check: bool = False):
        self.paths.resolve(descriptor_root, no_check)
        self.metadata.resolve(descriptor_root, no_check)
        self.resources.resolve(descriptor_root, no_check)
