from __future__ import annotations

from enum import StrEnum
from enum import unique
from typing import TYPE_CHECKING


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

    def __init__(self, base_generate_out_path: Path, base_output_path: Path):
        self.__base_generate_out_path = base_generate_out_path
        self.__base_output_path = base_output_path

        self.native_root_path.mkdir(parents=True, exist_ok=True)
        self.static_root_path.mkdir(parents=True, exist_ok=True)
        self.localization_root_path.mkdir(parents=True, exist_ok=True)
        self.images_root_path.mkdir(parents=True, exist_ok=True)
        self.icons_root_path.mkdir(parents=True, exist_ok=True)
        self.graphics_root_path.mkdir(parents=True, exist_ok=True)

    @property
    def base_generate_out_path(self) -> Path:
        return self.__base_generate_out_path

    @property
    def base_output_path(self) -> Path:
        return self.__base_output_path

    @property
    def descriptor_path(self) -> Path:
        path = self.__base_generate_out_path / "descriptor.json"
        return path

    @property
    def static_root_path(self) -> Path:
        path = self.__base_generate_out_path / "static"
        path.mkdir(parents=True, exist_ok=True)
        return path

    @property
    def static_collection_path(self) -> Path:
        path = self.static_root_path / "collection.pb2"
        return path

    @property
    def localization_root_path(self) -> Path:
        path = self.__base_generate_out_path / "localization"
        path.mkdir(parents=True, exist_ok=True)
        return path

    def get_localization_path(self, lang: str) -> Path:
        path = self.localization_root_path / f"localization_{lang}.pb2"
        return path

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
