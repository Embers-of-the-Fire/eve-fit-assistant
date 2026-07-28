from __future__ import annotations

from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field

from bootstrap.data.schema import groups_pb2
from bootstrap.data.workspace.generate.static.utils import icon
from bootstrap.data.workspace.generate.static.utils import loc
from bootstrap.log import error
from bootstrap.log import info


if TYPE_CHECKING:
    from bootstrap.data.workspace.generate import GeneratorDatasource


class GroupDef(BaseModel):
    groupID: int
    categoryID: int

    groupNameID: int

    iconID: int | None = Field(default=None)

    published: int

    def to_pb(self) -> groups_pb2.Group:
        pb = groups_pb2.Group()

        pb.group_id = self.groupID
        pb.category_id = self.categoryID
        pb.group_name.CopyFrom(loc(self.groupNameID))
        pb.published = self.published
        pb.icon.CopyFrom(icon(self.iconID))

        return pb


async def generate(data: GeneratorDatasource, collection):
    info("Generating groups...")
    groups = await data.resources.fsd.get("groups")

    cnt = 0
    for group_id, group_def in groups.items():
        try:
            validated = GroupDef.model_validate(group_def)
        except Exception as e:  # noqa: BLE001
            error(f"Failed to validate group {group_id}: {e}")
            continue

        cnt += 1
        collection.groups[group_id].CopyFrom(validated.to_pb())

    info(f"Generated {cnt} groups")
