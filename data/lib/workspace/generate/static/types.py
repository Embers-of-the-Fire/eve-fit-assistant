from __future__ import annotations

from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field

from data.lib.log import error
from data.lib.log import info
from data.lib.schema import types_pb2
from data.lib.workspace.generate.static.utils import icon
from data.lib.workspace.generate.static.utils import loc


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


class TypeDef(BaseModel):
    typeID: int

    iconID: int | None = Field(default=None)
    graphicID: int | None = Field(default=None)

    groupID: int
    marketGroupID: int | None = Field(default=None)
    metaGroupID: int | None = Field(default=None)

    isDynamicType: bool = Field(default=False)
    published: bool

    typeNameID: int
    descriptionID: int | None = Field(default=None)

    def to_pb(self) -> types_pb2.Type:
        pb = types_pb2.Type()

        pb.type_id = self.typeID
        pb.icon.CopyFrom(icon(icon_id=self.iconID, graphic_id=self.graphicID))
        pb.group_id = self.groupID
        if self.marketGroupID is not None:
            pb.market_group_id = self.marketGroupID
        if self.metaGroupID is not None:
            pb.meta_group_id = self.metaGroupID
        pb.is_dynamic_type = self.isDynamicType
        pb.published = self.published
        pb.type_name.CopyFrom(loc(self.typeNameID))
        if self.descriptionID is not None:
            pb.description.CopyFrom(loc(self.descriptionID))

        return pb


async def generate(data: GeneratorDatasource, collection):
    info("Generating types...")
    types = await data.resources.fsd.get("types")

    cnt = 0
    for type_id, type_def in types.items():
        try:
            validated = TypeDef.model_validate(type_def)
        except Exception as e:
            error(f"Failed to validate type {type_id}: {e}")
            continue

        cnt += 1
        collection.types.append(validated.to_pb())

    info(f"Generated {cnt} types")
