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
import sys
import tomllib

from pathlib import Path
from typing import Any

from pydantic import BaseModel
from pydantic import ConfigDict
from pydantic import Field
from pydantic import ValidationError
from pydantic import model_validator

from data.lib.constant import CACHE_CONFIG_PATH
from data.lib.constant import CONFIG_PATH
from data.lib.constant import DEV_CONFIG_PATH
from data.lib.localization import LocalizationModel  # noqa:TC001
from data.lib.remote.channel import Channel
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


class BundleSchema(BaseModel):
    current: int
    min: int

    @model_validator(mode="after")
    def _validate_schema(self) -> BundleSchema:
        if self.current <= 0:
            raise ValueError(f"current must be positive, got {self.current}")
        if self.min <= 0:
            raise ValueError(f"min must be positive, got {self.min}")
        if self.min > self.current:
            raise ValueError(f"min ({self.min}) must be <= current ({self.current})")
        return self


class ProjectVersion(BaseModel):
    major: int
    minor: int
    patch: int
    pre_label: str = ""
    pre_num: int = 0
    build: int = 0

    @model_validator(mode="after")
    def _validate_version(self) -> ProjectVersion:
        if self.major < 0:
            raise ValueError(f"major must be >= 0, got {self.major}")
        if self.minor < 0:
            raise ValueError(f"minor must be >= 0, got {self.minor}")
        if self.patch < 0:
            raise ValueError(f"patch must be >= 0, got {self.patch}")
        if self.build < 0:
            raise ValueError(f"build must be >= 0, got {self.build}")
        if self.pre_label and self.pre_num < 1:
            raise ValueError(
                f"pre_num must be >= 1 when pre_label is set, "
                f"got pre_label={self.pre_label!r} pre_num={self.pre_num}"
            )
        if not self.pre_label and self.pre_num > 0:
            raise ValueError(
                f"pre_label must be set when pre_num > 0, "
                f"got pre_label={self.pre_label!r} pre_num={self.pre_num}"
            )
        return self

    def is_prerelease(self) -> bool:
        return bool(self.pre_label)

    def render_full(self) -> str:
        base = f"{self.major}.{self.minor}.{self.patch}"
        if self.is_prerelease():
            base = f"{base}-{self.pre_label}.{self.pre_num}"
        return f"{base}+{self.build}"

    def render_semver(self) -> str:
        base = f"{self.major}.{self.minor}.{self.patch}"
        if self.is_prerelease():
            base = f"{base}-{self.pre_label}.{self.pre_num}"
        return base

    def render_tag(self) -> str:
        return f"v{self.render_full()}"

    def bump_major(self) -> ProjectVersion:
        self.major += 1
        self.minor = 0
        self.patch = 0
        if self.is_prerelease():
            self.pre_num = 1
        return self

    def bump_minor(self) -> ProjectVersion:
        self.minor += 1
        self.patch = 0
        if self.is_prerelease():
            self.pre_num = 1
        return self

    def bump_patch(self) -> ProjectVersion:
        self.patch += 1
        if self.is_prerelease():
            self.pre_num = 1
        return self

    def clear_prerelease(self) -> ProjectVersion:
        self.pre_label = ""
        self.pre_num = 0
        return self


class ProjectConfiguration(BaseModel):
    localizations: ProjectLocalizations
    paths: ProjectPaths
    bundle_schema: BundleSchema
    version: ProjectVersion
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
    model_config = ConfigDict(validate_default=True)

    root: ProjectPath = Field(default="cache")

    @property
    def log_path(self) -> ProjectPath:
        return self.root / "log"

    def workspace_root_path(self, workspace_id: str) -> ProjectPath:
        return self.root / "workspaces" / workspace_id

    def workspace_cache_path(self, workspace_id: str) -> ProjectPath:
        return self.workspace_root_path(workspace_id)

    def workspace_generated_path(self, workspace_id: str) -> ProjectPath:
        return self.workspace_root_path(workspace_id) / "generated"

    def workspace_output_path(self, workspace_id: str) -> ProjectPath:
        return self.workspace_root_path(workspace_id) / "output"

    @property
    def session_dir(self) -> ProjectPath:
        return self.root / "remote" / "sessions"


class DeveloperWorkspace(BaseModel):
    default: str | None = Field(default=None)


class DeveloperBuild(BaseModel):
    model_config = ConfigDict(validate_default=True)

    skip_hash: bool = Field(default=False)
    baseline: ProjectPath | None = Field(default=None)


class DeveloperNative(BaseModel):
    model_config = ConfigDict(validate_default=True)

    fsd_format: str = Field(default="msgpack")
    fsd_binary_dir: ProjectPath | None = Field(default=None)
    fsd_loc_en_dir: ProjectPath | None = Field(default=None)
    output_dir: ProjectPath | None = Field(default=None)


class DeveloperRemoteMinio(BaseModel):
    """MinIO mock server configuration. All fields required — no silent defaults."""

    port: int
    console_port: int
    bucket: str
    access_key: str
    secret_key: str
    data_dir: Path
    alias: str
    public_download: bool
    verify_upload: bool = False
    verify_workers: int = 4


class DeveloperRemoteS3(BaseModel):
    """S3-compatible remote publishing configuration. All fields required — no silent defaults."""

    endpoint: str
    bucket: str
    access_key: str
    secret_key: str
    alias: str
    public_download: bool
    verify_upload: bool = True
    verify_workers: int = 4


def _fail_remote_sub(toml_key: str, command_group: str) -> None:
    print(
        f"Error: [{toml_key}] is not configured in efa.dev.toml.\n"
        f"       This section is required for `./x remote {command_group}` commands.\n"
        f"       See efa.dev.example.toml for the expected format.",
        file=sys.stderr,
    )
    sys.exit(1)


class DeveloperRemote(BaseModel):
    model_config = ConfigDict(validate_default=True)

    resource_root: str = Field(default="efa/v1")
    channel: Channel = Field(default=Channel.TESTING)
    host: str = Field(default="127.0.0.1")
    mock_origin_dir: Path = Field(default=Path("remote/mock-origin"))
    verify_upload: bool | None = None
    verify_workers: int | None = None
    minio: DeveloperRemoteMinio | None = None
    s3: DeveloperRemoteS3 | None = None

    def require_minio(self) -> DeveloperRemoteMinio:
        if self.minio is None:
            _fail_remote_sub("remote.minio", "mock")
        return self.minio  # type: ignore[return-value]

    def require_s3(self) -> DeveloperRemoteS3:
        if self.s3 is None:
            _fail_remote_sub("remote.s3", "publish")
        return self.s3  # type: ignore[return-value]


class DeveloperConfiguration(BaseModel):
    paths: DeveloperPaths = Field(default_factory=DeveloperPaths)
    workspace: DeveloperWorkspace = Field(default_factory=DeveloperWorkspace)
    build: DeveloperBuild = Field(default_factory=DeveloperBuild)
    native: DeveloperNative = Field(default_factory=DeveloperNative)
    remote: DeveloperRemote = Field(default_factory=DeveloperRemote)

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
