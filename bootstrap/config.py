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
from pydantic import SecretStr
from pydantic import ValidationError
from pydantic import model_validator

from bootstrap.constant import CACHE_CONFIG_PATH
from bootstrap.constant import CONFIG_PATH
from bootstrap.constant import DEV_CONFIG_PATH
from bootstrap.localization import LocalizationModel  # noqa:TC001
from bootstrap.remote.channel import Channel
from bootstrap.validator import ProjectPath  # noqa:TC001


CONFIGURATION: ProjectConfiguration | None = None
DEV_CONFIGURATION: DeveloperConfiguration | None = None
WORKSPACE_CACHE: WorkspaceCache | None = None

_DEV_CONFIG_OVERRIDES: list[tuple[str, str]] = []
_PROJECT_CONFIG_OVERRIDES: list[tuple[str, str]] = []


def _split_key(key: str) -> list[str]:
    """Split a dotted override key into its path components."""
    return key.split(".")


def _set_nested_value(data: dict, key_path: list[str], value: Any) -> None:
    """Set ``value`` at ``key_path`` inside ``data``, creating tables as needed.

    Raises ``KeyError`` if an intermediate value is not a dictionary.
    """
    *head, tail = key_path
    node = data
    for part in head:
        if part not in node:
            node[part] = {}
        node = node[part]
        if not isinstance(node, dict):
            raise KeyError(".".join(key_path))
    node[tail] = value


def _apply_overrides(
    cfg: dict,
    overrides: list[tuple[str, str]],
) -> dict:
    """Apply CLI overrides to a raw TOML dictionary.

    Values are parsed as TOML primitives so numbers, booleans, and arrays work.
    If a value is not valid bare TOML (e.g. contains special characters), it is
    treated as a literal string.
    """
    for raw_key, raw_value in overrides:
        key_path = _split_key(raw_key)
        try:
            parsed_value = tomllib.loads(f"value = {raw_value}")["value"]
        except tomllib.TOMLDecodeError:
            parsed_value = raw_value
        _set_nested_value(cfg, key_path, parsed_value)
    return cfg


def apply_dev_config_overrides(overrides: list[tuple[str, str]]) -> None:
    """Register overrides to apply when loading ``efa.dev.toml``."""
    global _DEV_CONFIG_OVERRIDES
    _DEV_CONFIG_OVERRIDES = overrides


def apply_project_config_overrides(overrides: list[tuple[str, str]]) -> None:
    """Register overrides to apply when loading ``efa.config.toml``."""
    global _PROJECT_CONFIG_OVERRIDES
    _PROJECT_CONFIG_OVERRIDES = overrides


class ProjectLocalizations(BaseModel):
    default: LocalizationModel
    supported: list[LocalizationModel]
    translation: dict[str, str]


class ProjectPaths(BaseModel):
    log: ProjectPath


class ProjectResource(BaseModel):
    descriptor: ProjectPath


class ProjectVersion(BaseModel):
    major: int
    minor: int
    patch: int
    pre_label: str = ""
    pre_num: int = 0
    build: int = 0
    data_schema: int = Field(default=2)

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
        if self.build:
            base = f"{base}+{self.build}"
        return base

    def render_semver(self) -> str:
        base = f"{self.major}.{self.minor}.{self.patch}"
        if self.is_prerelease():
            base = f"{base}-{self.pre_label}.{self.pre_num}"
        return base

    def render_tag(self) -> str:
        return f"v{self.render_semver()}"


class SchemaConfig(BaseModel):
    """Schema version configuration."""

    resource_root: str = Field(default="efa/v2")
    channel: Channel = Field(default=Channel.TESTING)
    schema_version: int = Field(default=2)

    @model_validator(mode="after")
    def _validate_schema(self) -> SchemaConfig:
        if self.schema_version <= 0:
            raise ValueError(f"schema_version must be positive, got {self.schema_version}")
        return self


class ProjectConfiguration(BaseModel):
    localizations: ProjectLocalizations
    paths: ProjectPaths
    data_schema: SchemaConfig = Field(default_factory=SchemaConfig)
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

        cfg = _apply_overrides(cfg, _PROJECT_CONFIG_OVERRIDES)

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

    @property
    def schema_dir(self) -> ProjectPath:
        return self.root / "schema"


class DeveloperWorkspace(BaseModel):
    default: str | None = Field(default=None)


class DeveloperCodegen(BaseModel):
    model_config = ConfigDict(validate_default=True)

    attr_id_source: ProjectPath | None = Field(default=None)


class DeveloperBuild(BaseModel):
    model_config = ConfigDict(validate_default=True)

    author: str = Field(default="")
    description: str = Field(default="")


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
    access_key: SecretStr
    secret_key: SecretStr
    data_dir: Path
    alias: str
    public_download: bool
    verify_upload: bool = False
    verify_workers: int = 4


class DeveloperRemoteS3(BaseModel):
    """S3-compatible remote publishing configuration. All fields required — no silent defaults."""

    endpoint: str
    bucket: str
    access_key: SecretStr
    secret_key: SecretStr
    alias: str
    public_download: bool
    verify_upload: bool = True
    verify_workers: int = 4


class DeveloperCiStorage(BaseModel):
    """CI data storage configuration (Cloudflare R2)."""

    endpoint: str
    bucket: str
    alias: str
    access_key: SecretStr
    secret_key: SecretStr
    public_url: str | None = None


class DeveloperCiRawArtifacts(BaseModel):
    """Raw artifact upload target inside the CI bucket."""

    remote_root: str = Field(default="data-generator/raw-artifact")
    endpoint: str | None = None
    bucket: str | None = None
    alias: str | None = None
    access_key: SecretStr | None = None
    secret_key: SecretStr | None = None
    public_url: str | None = None


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

    channel: Channel = Field(default=Channel.TESTING)
    host: str = Field(default="127.0.0.1")
    mock_origin_dir: Path = Field(default=Path("remote/mock-origin"))
    verify_upload: bool | None = None
    verify_workers: int | None = None
    minio: DeveloperRemoteMinio | None = None
    s3: DeveloperRemoteS3 | None = None

    def require_minio(self, command_group: str = "mock") -> DeveloperRemoteMinio:
        if self.minio is None:
            _fail_remote_sub("remote.minio", command_group)
        return self.minio  # type: ignore[return-value]

    def require_s3(self, command_group: str = "publish") -> DeveloperRemoteS3:
        if self.s3 is None:
            _fail_remote_sub("remote.s3", command_group)
        return self.s3  # type: ignore[return-value]


class DeveloperCi(BaseModel):
    model_config = ConfigDict(validate_default=True)

    storage: DeveloperCiStorage | None = None
    raw_artifacts: DeveloperCiRawArtifacts | None = None

    def require_storage(self) -> DeveloperCiStorage:
        if self.storage is None:
            print(
                "Error: [ci.storage] is not configured in efa.dev.toml.\n"
                "       Required for CI storage commands (e.g. ``./x ci pack-data`` "
                "and ``./x ci raw-data upload``).\n"
                "       See efa.dev.example.toml.",
                file=sys.stderr,
            )
            sys.exit(1)
        return self.storage

    def require_raw_artifacts(self) -> tuple[DeveloperCiRawArtifacts, DeveloperCiStorage]:
        if self.raw_artifacts is None:
            self.raw_artifacts = DeveloperCiRawArtifacts()
        return self.raw_artifacts, self.require_storage()


class DeveloperConfiguration(BaseModel):
    paths: DeveloperPaths = Field(default_factory=DeveloperPaths)
    workspace: DeveloperWorkspace = Field(default_factory=DeveloperWorkspace)
    build: DeveloperBuild = Field(default_factory=DeveloperBuild)
    codegen: DeveloperCodegen = Field(default_factory=DeveloperCodegen)
    native: DeveloperNative = Field(default_factory=DeveloperNative)
    remote: DeveloperRemote = Field(default_factory=DeveloperRemote)
    ci: DeveloperCi = Field(default_factory=DeveloperCi)

    @staticmethod
    def load_from_global():
        cfg = {}
        try:
            with open(DEV_CONFIG_PATH, "rb") as cfg_f:
                cfg = tomllib.load(cfg_f)
        except FileNotFoundError:
            pass

        cfg = _apply_overrides(cfg, _DEV_CONFIG_OVERRIDES)

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
