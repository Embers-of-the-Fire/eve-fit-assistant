from __future__ import annotations

import tomllib

from pathlib import Path  # noqa:TC003
from typing import Annotated
from typing import Literal

from pydantic import BaseModel
from pydantic import BeforeValidator
from pydantic import Field

from data.lib.log import error
from data.lib.log import warning
from data.lib.validator import validate_url_template


class WorkspacePaths(BaseModel):
    cache: Path
    generated: Path
    output: Path

    def resolve(self, descriptor_root: Path, no_check: bool = False):
        if not self.cache.is_absolute():
            self.cache = (descriptor_root / self.cache).resolve()
        if not self.generated.is_absolute():
            self.generated = (descriptor_root / self.generated).resolve()
        if not self.output.is_absolute():
            self.output = (descriptor_root / self.output).resolve()

        if no_check:
            return

        if not self.cache.exists():
            warning(f"Cache path does not exist, creating: {self.cache}")
            self.cache.mkdir(parents=True, exist_ok=True)
        if not self.cache.is_dir():
            error(f"Cache path is not a directory: {self.cache}")
            exit(1)

        if not self.generated.exists():
            warning(f"Generate output path does not exist, creating: {self.generated}")
            self.generated.mkdir(parents=True, exist_ok=True)
        if not self.generated.is_dir():
            error(f"Generate output path is not a directory: {self.generated}")
            exit(1)

        if not self.output.exists():
            warning(f"Output path does not exist, creating: {self.output}")
            self.output.mkdir(parents=True, exist_ok=True)
        if not self.output.is_dir():
            error(f"Output path is not a directory: {self.output}")
            exit(1)


class WorkspaceMetadata(BaseModel):
    start_cfg: Path
    name: dict[Literal["en", "zh"], str]
    identifier: str

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
    fsd: Path
    patches: Path

    def resolve(self, descriptor_root: Path, no_check: bool = False):
        if not self.resource_index.is_absolute():
            self.resource_index = (descriptor_root / self.resource_index).resolve()
        if not self.application_index.is_absolute():
            self.application_index = (descriptor_root / self.application_index).resolve()
        if not self.fsd.is_absolute():
            self.fsd = (descriptor_root / self.fsd).resolve()
        if not self.patches.is_absolute():
            self.patches = (descriptor_root / self.patches).resolve()

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

        if not self.fsd.exists():
            error(f"FSD resource path does not exist: {self.fsd}")
            exit(1)
        if not self.fsd.is_dir():
            error(f"FSD resource path is not a directory: {self.fsd}")
            exit(1)
        
        if not self.patches.exists():
            error(f"Patches path does not exist: {self.patches}")
            exit(1)
        if not self.patches.is_dir():
            error(f"Patches path is not a directory: {self.patches}")
            exit(1)


class WorkspaceServices(BaseModel):
    resource_url: Annotated[
        str, BeforeValidator(validate_url_template(["resource_url", "resource_type"]))
    ]


class WorkspaceConfig(BaseModel):
    ignore: bool = Field(default=False)
    paths: WorkspacePaths
    metadata: WorkspaceMetadata
    resources: WorkspaceResources
    services: WorkspaceServices

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
