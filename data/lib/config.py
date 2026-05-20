"""
EFA overall config manager

This module contains user-defined configurations
used when developing EFA locally.

The config file should be `<project root>/efa.config.toml`.
See `<project root>/efa.config.example.toml` for more information.

The optional developer config file should be `<project root>/efa.dev.toml`.
See `<project root>/efa.dev.example.toml` for more information.
"""

from __future__ import annotations

import json
import tomllib

from typing import Any

from pydantic import BaseModel
from pydantic import Field
from pydantic import ValidationError

from data.lib.constant import CACHE_CONFIG_PATH
from data.lib.constant import CONFIG_PATH
from data.lib.constant import DEV_CONFIG_PATH
from data.lib.localization import LocalizationModel  # noqa:TC001
from data.lib.validator import ProjectPath  # noqa:TC001


CONFIGURATION: ProjectConfiguration | None = None
DEV_CONFIGURATION: DeveloperConfiguration | None = None
WORKSPACE_CACHE: WorkspaceCache | None = None


class ProjectLocalizations(BaseModel):
    default: LocalizationModel
    supported: list[LocalizationModel]
    translation: dict[str, str]


class ProjectPaths(BaseModel):
    log: ProjectPath


class ProjectResource(BaseModel):
    descriptor: ProjectPath


class ProjectConfiguration(BaseModel):
    localizations: ProjectLocalizations
    paths: ProjectPaths
    resources: dict[str, ProjectResource] = Field(default_factory=dict)

    @staticmethod
    def load_from_global():
        try:
            with open(CONFIG_PATH, "rb") as cfg_f:
                cfg = tomllib.load(cfg_f)
        except FileNotFoundError:
            print(f"Unable to find `eva.config.toml`, expected to be placed at {CONFIG_PATH}")
            raise

        try:
            global CONFIGURATION
            CONFIGURATION = ProjectConfiguration.model_validate(cfg)
        except ValidationError as e:
            print(f"Invalid configuration format: {e!r}")
            raise

    @staticmethod
    def ensure_loaded():
        global CONFIGURATION
        if CONFIGURATION is None:
            ProjectConfiguration.load_from_global()


class DeveloperPaths(BaseModel):
    root: ProjectPath = Field(default="cache")
    log: str = Field(default="log")
    workspaces: str = Field(default="workspaces")
    generated: str = Field(default="generated")
    output: str = Field(default="output")

    @property
    def log_path(self) -> ProjectPath:
        return self.root / self.log

    def workspace_root_path(self, workspace_id: str) -> ProjectPath:
        return self.root / self.workspaces / workspace_id

    def workspace_cache_path(self, workspace_id: str) -> ProjectPath:
        return self.workspace_root_path(workspace_id)

    def workspace_generated_path(self, workspace_id: str) -> ProjectPath:
        return self.workspace_root_path(workspace_id) / self.generated

    def workspace_output_path(self, workspace_id: str) -> ProjectPath:
        return self.workspace_root_path(workspace_id) / self.output


class DeveloperWorkspace(BaseModel):
    default: str | None = Field(default=None)


class DeveloperBuild(BaseModel):
    skip_hash: bool = Field(default=False)
    baseline: ProjectPath | None = Field(default=None)


class DeveloperNative(BaseModel):
    fsd_format: str = Field(default="msgpack")
    fsd_binary_dir: ProjectPath | None = Field(default=None)
    fsd_loc_en_dir: ProjectPath | None = Field(default=None)
    output_dir: ProjectPath | None = Field(default=None)


class DeveloperConfiguration(BaseModel):
    paths: DeveloperPaths = Field(default_factory=DeveloperPaths)
    workspace: DeveloperWorkspace = Field(default_factory=DeveloperWorkspace)
    build: DeveloperBuild = Field(default_factory=DeveloperBuild)
    native: DeveloperNative = Field(default_factory=DeveloperNative)

    @staticmethod
    def load_from_global():
        cfg = {}
        try:
            with open(DEV_CONFIG_PATH, "rb") as cfg_f:
                cfg = tomllib.load(cfg_f)
        except FileNotFoundError:
            pass

        try:
            global DEV_CONFIGURATION
            DEV_CONFIGURATION = DeveloperConfiguration.model_validate(cfg)
        except ValidationError as e:
            print(f"Invalid developer configuration format: {e!r}")
            raise

    @staticmethod
    def ensure_loaded():
        global DEV_CONFIGURATION
        if DEV_CONFIGURATION is None:
            DeveloperConfiguration.load_from_global()


class WorkspaceCache(BaseModel):
    default_workspace: str | None = Field(default=None)

    current_workspace: str | None = Field(default=None)

    def model_post_init(self, context: Any, /) -> None:
        self.current_workspace = self.default_workspace

    @staticmethod
    def load_from_global():
        cache = {}
        try:
            with open(CACHE_CONFIG_PATH, "r") as f:
                cache = json.load(f)
        except FileNotFoundError:
            with open(CACHE_CONFIG_PATH, "w+") as f:
                f.write("{}")

        try:
            global WORKSPACE_CACHE
            WORKSPACE_CACHE = WorkspaceCache.model_validate(cache)
            DeveloperConfiguration.ensure_loaded()
            if WORKSPACE_CACHE.default_workspace is None:
                WORKSPACE_CACHE.default_workspace = DEV_CONFIGURATION.workspace.default
                WORKSPACE_CACHE.current_workspace = WORKSPACE_CACHE.default_workspace
        except ValidationError as e:
            print(f"Invalid cache format: {e!r}")
            raise

    @staticmethod
    def select_workspace(name: str):
        global WORKSPACE_CACHE
        assert WORKSPACE_CACHE is not None
        WORKSPACE_CACHE.current_workspace = name

    def synchronize(self):
        with open(CACHE_CONFIG_PATH, "w+") as f:
            f.write(self.model_dump_json(exclude={"current_workspace"}))
