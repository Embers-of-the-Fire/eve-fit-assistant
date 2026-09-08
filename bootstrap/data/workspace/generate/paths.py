from __future__ import annotations

from enum import StrEnum
from enum import unique
from pathlib import PurePosixPath
from typing import TYPE_CHECKING

import bootstrap.config


if TYPE_CHECKING:
    from pathlib import Path


@unique
class GraphicVariantType(StrEnum):
    NONE = ""
    BP = "bp"
    BPC = "bpc"


class PathManager:
    __base_generate_out_path: Path
    __base_output_path: Path

    def __init__(self, full_generate_out_path: Path, base_output_path: Path):
        self.__base_generate_out_path = full_generate_out_path
        self.__base_output_path = base_output_path

        # Resource layout vocabulary shared with the app via codegen.
        bootstrap.config.ProjectConfiguration.ensure_loaded()
        assert bootstrap.config.CONFIGURATION is not None
        vocab = bootstrap.config.CONFIGURATION.resolution
        self.__legacy_localization_db_rel = PurePosixPath(vocab.legacy_localization_db)
        self.__localization_locales_rel = PurePosixPath(vocab.localization_locales_prefix)

        self.full_generate_out_path.mkdir(parents=True, exist_ok=True)
        self.native_root_path.mkdir(parents=True, exist_ok=True)
        self.static_root_path.mkdir(parents=True, exist_ok=True)
        self.localization_root_path.mkdir(parents=True, exist_ok=True)
        self.images_root_path.mkdir(parents=True, exist_ok=True)
        self.icons_root_path.mkdir(parents=True, exist_ok=True)
        self.graphics_root_path.mkdir(parents=True, exist_ok=True)

    @property
    def full_generate_out_path(self) -> Path:
        return self.__base_generate_out_path / "full"

    @property
    def base_output_path(self) -> Path:
        return self.__base_output_path

    @property
    def static_root_path(self) -> Path:
        path = self.full_generate_out_path / "static"
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def static_collection_path(self) -> Path:
        path = self.static_root_path / "collection.pb2"
        return path

    @property
    def localization_root_path(self) -> Path:
        path = self.full_generate_out_path / self.__legacy_localization_db_rel.parent
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def localization_db_path(self) -> Path:
        """SQLite database with all localized strings (lazy query access).

        Localization ships only as this database; per-language `.pb2` files
        are no longer emitted.
        """
        return self.full_generate_out_path / self.__legacy_localization_db_rel

    @property
    def localization_locales_root_path(self) -> Path:
        """Directory of the per-locale localization databases."""
        path = self.full_generate_out_path / self.__localization_locales_rel
        path.mkdir(parents=True, exist_ok=True)
        return path

    def localization_locale_db_path(self, lang: str) -> Path:
        """Per-locale SQLite database with the localized strings of one locale."""
        return self.localization_locales_root_path / f"{lang}.db"

    @property
    def agent_root_path(self) -> Path:
        path = self.full_generate_out_path / "agent"
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def agent_resource_db_path(self) -> Path:
        """SQLite database with AI-agent (chat) support data.

        Ships as a dedicated database (separate from `localization.db`) so
        agent-only payloads stay out of the general localization corpus.
        """
        return self.agent_root_path / "agent_resource.db"

    @property
    def native_root_path(self) -> Path:
        path = self.static_root_path / "native"
        path.mkdir(parents=True, exist_ok=True)
        return path

    def get_native_path(self, variant: str) -> Path:
        path = self.native_root_path / variant
        return path

    @property
    def images_root_path(self) -> Path:
        path = self.static_root_path / "images"
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def icons_root_path(self) -> Path:
        path = self.images_root_path / "icons"
        path.mkdir(parents=True, exist_ok=True)
        return path

    def get_icon_path(self, icon_id: int) -> Path:
        path = self.icons_root_path / f"{icon_id}.png"
        return path

    @property
    def graphics_root_path(self) -> Path:
        path = self.images_root_path / "graphics"
        path.mkdir(parents=True, exist_ok=True)
        return path

    def get_graphic_path(
        self, graphic_id: int, variant: GraphicVariantType = GraphicVariantType.NONE
    ):
        if variant != GraphicVariantType.NONE:
            path = self.graphics_root_path / f"{graphic_id}_{variant}.png"
        else:
            path = self.graphics_root_path / f"{graphic_id}.png"
        return path
