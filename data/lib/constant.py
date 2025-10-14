from __future__ import annotations

from pathlib import Path


PROJECT_ROOT = Path(__file__).parent.parent.parent.resolve()
CONFIG_PATH = PROJECT_ROOT / "efa.config.toml"
CACHE_CONFIG_PATH = PROJECT_ROOT / ".efa.cache"

WORKSPACE_NAME_ENV_VAR = "EFA_WORKSPACE_NAME"

PROTOBUF_SCHEMA_PATH = PROJECT_ROOT / "data" / "schema"
PROTOBUF_PYTHON_OUT_PATH = PROJECT_ROOT / "data" / "lib" / "schema"
PROTOBUF_DART_OUT_PATH = PROJECT_ROOT / "lib" / "data" / "proto"

NATIVE_LIB_ROOT = PROJECT_ROOT / "rust" / "lib" / "eve-fit-os"

I18N_ROOT = PROJECT_ROOT / "l10n"

DART_ROOT = PROJECT_ROOT / "lib"
