from __future__ import annotations

from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field

from data.lib.log import error
from data.lib.log import info
from data.lib.schema import categories_pb2
from data.lib.workspace.generate.static.utils import icon
from data.lib.workspace.generate.static.utils import loc


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


class CategoryDef(BaseModel):
    categoryID: int
    published: bool

    categoryNameID: int

    iconID: int | None = Field(default=None)

    def to_pb(self) -> categories_pb2.Category:
        pb = categories_pb2.Category()

        pb.category_id = self.categoryID
        pb.category_name.CopyFrom(loc(self.categoryNameID))
        pb.published = self.published
        pb.icon.CopyFrom(icon(self.iconID))

        return pb


async def generate(data: GeneratorDatasource, collection):
    info("Generating categories...")
    categories = await data.resources.fsd.get("categories")

    cnt = 0
    for category_id, category_def in categories.items():
        try:
            validated = CategoryDef.model_validate(category_def)
        except Exception as e:
            error(f"Failed to validate category {category_id}: {e}")
            continue

        cnt += 1
        collection.categories.append(validated.to_pb())

    info(f"Generated {cnt} categories")
