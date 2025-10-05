from __future__ import annotations

from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field

from data.lib.log import error
from data.lib.log import info
from data.lib.schema import meta_groups_pb2
from data.lib.workspace.generate.static.utils import icon
from data.lib.workspace.generate.static.utils import loc


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


class MetaGroupDef(BaseModel):
    nameID: int
    iconID: int | None = Field(default=None)

    def to_pb(self, self_id: int) -> meta_groups_pb2.MetaGroup:
        pb = meta_groups_pb2.MetaGroup()

        pb.meta_group_id = self_id
        pb.meta_group_name.CopyFrom(loc(self.nameID))
        pb.icon.CopyFrom(icon(self.iconID))

        return pb


async def generate(data: GeneratorDatasource, collection):
    info("Generating meta groups...")
    meta_groups = await data.resources.fsd.get("metaGroups")

    cnt = 0
    for meta_group_id, meta_group_def in meta_groups.items():
        try:
            validated = MetaGroupDef.model_validate(meta_group_def)
        except Exception as e:
            error(f"Failed to validate meta group {meta_group_id}: {e}")
            continue

        cnt += 1
        collection.meta_groups.append(validated.to_pb(meta_group_id))

    info(f"Generated {cnt} meta groups")
