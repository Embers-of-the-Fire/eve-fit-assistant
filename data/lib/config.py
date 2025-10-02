"""
EFA overall config manager

This module contains user-defined configurations
used when developing EFA locally.

The config file should be `<project root>/efa.config.toml`.
See `<project root>/efa.config.example.toml` for more information.
"""

from __future__ import annotations

import json
import tomllib

from pydantic import BaseModel
from pydantic import Field
from pydantic import ValidationError

from data.lib.constant import CACHE_CONFIG_PATH
from data.lib.constant import CONFIG_PATH
from data.lib.validator import ProjectPath  # noqa:TC001


CONFIGURATION: ProjectConfiguration | None = None
WORKSPACE_CACHE: WorkspaceCache | None = None


class ProjectPaths(BaseModel):
    log: ProjectPath


class ProjectResource(BaseModel):
    descriptor: ProjectPath


class ProjectConfiguration(BaseModel):
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


class WorkspaceCache(BaseModel):
    default_workspace: str | None = Field(default=None)

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
        except ValidationError as e:
            print(f"Invalid cache format: {e!r}")
            raise

    def synchronize(self):
        with open(CACHE_CONFIG_PATH, "w+") as f:
            f.write(self.model_dump_json())
