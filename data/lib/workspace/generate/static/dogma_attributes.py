from __future__ import annotations

from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field

from data.lib.log import error
from data.lib.log import info
from data.lib.schema import dogma_attributes_pb2
from data.lib.workspace.generate.static.utils import icon
from data.lib.workspace.generate.static.utils import loc


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


class DogmaAttributeDef(BaseModel):
    attributeID: int
    name: str
    description: str = Field(default_factory=str)
    iconID: int | None = Field(default=None)

    displayNameID: int | None = Field(default=None)
    tooltipDescriptionID: int | None = Field(default=None)

    published: bool = Field(default=False)
    highIsGood: bool = Field(default=False)
    displayWhenZero: bool = Field(default=False)

    unitID: int | None = Field(default=None)
    stackable: bool = Field(default=False)

    defaultValue: float | None = Field(default=None)
    categoryID: int | None = Field(default=None)

    def to_pb(self) -> dogma_attributes_pb2.DogmaAttribute:
        pb = dogma_attributes_pb2.DogmaAttribute()

        pb.dogma_attribute_id = self.attributeID
        pb.name = self.name
        pb.description = self.description

        pb.icon.CopyFrom(icon(icon_id=self.iconID))

        if self.displayNameID is not None:
            pb.display_name.CopyFrom(loc(self.displayNameID))
        if self.tooltipDescriptionID is not None:
            pb.tooltip_description.CopyFrom(loc(self.tooltipDescriptionID))

        pb.published = self.published
        pb.high_is_good = self.highIsGood
        pb.display_when_zero = self.displayWhenZero

        if self.unitID is not None:
            pb.unit_id = self.unitID
        pb.stackable = self.stackable

        if self.defaultValue is not None:
            pb.default_value = self.defaultValue
        if self.categoryID is not None:
            pb.category_id = self.categoryID

        return pb


async def generate(data: GeneratorDatasource, collection):
    info("Generating dogma attributes...")
    dogma_attributes = await data.resources.fsd.get("dogmaAttributes")

    cnt = 0
    for dogma_attribute_id, dogma_attribute_def in dogma_attributes.items():
        try:
            validated = DogmaAttributeDef.model_validate(dogma_attribute_def)
        except Exception as e:
            error(f"Failed to validate dogma attribute {dogma_attribute_id}: {e}")
            continue

        cnt += 1
        collection.dogma_attributes[validated.attributeID].CopyFrom(validated.to_pb())

    info(f"Generated {cnt} dogma attributes")
