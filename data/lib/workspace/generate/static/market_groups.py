from __future__ import annotations

from collections import defaultdict
from typing import TYPE_CHECKING
from typing import Literal

from pydantic import BaseModel
from pydantic import Field

from data.lib.log import error
from data.lib.log import info
from data.lib.schema import market_groups_pb2
from data.lib.workspace.generate.static.types import TypeDef
from data.lib.workspace.generate.static.utils import icon
from data.lib.workspace.generate.static.utils import loc


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


class MarketGroupDef(BaseModel):
    nameID: int
    descriptionID: int | None = Field(default=None)

    iconID: int | None = Field(default=None)

    hasTypes: bool

    parentGroupID: int | None = Field(default=None)

    def to_pb(
        self, self_id: int, groups: list[int], types: list[int]
    ) -> market_groups_pb2.MarketGroup:
        pb = market_groups_pb2.MarketGroup()

        pb.market_group_id = self_id
        pb.market_group_name.CopyFrom(loc(self.nameID))
        if self.descriptionID is not None:
            pb.description.CopyFrom(loc(self.descriptionID))
        pb.icon.CopyFrom(icon(self.iconID))
        if self.parentGroupID is not None:
            pb.parent_group_id = self.parentGroupID
        pb.groups.extend(groups)
        pb.types.extend(types)

        return pb


async def generate(data: GeneratorDatasource, collection):
    info("Generating market_groups...")
    market_groups = await data.resources.fsd.get("marketGroups")

    tree: defaultdict[
        int, dict[Literal["def", "groups", "types"], list[int] | None | MarketGroupDef]
    ] = defaultdict(lambda: {"def": None, "groups": [], "types": []})
    cnt = 0
    for market_group_id, market_group_def in market_groups.items():
        try:
            validated = MarketGroupDef.model_validate(market_group_def)
        except Exception as e:
            error(f"Failed to validate market group {market_group_id}: {e}")
            continue

        if validated.parentGroupID is not None:
            tree[validated.parentGroupID]["groups"].append(market_group_id)

        tree[market_group_id]["def"] = validated

        cnt += 1

    types = await data.resources.fsd.get("types")
    for type_id, type_def in types.items():
        try:
            validated = TypeDef.model_validate(type_def)
        except Exception as e:
            error(f"Failed to validate type {type_id}: {e}")
            continue

        if validated.marketGroupID is not None:
            tree[validated.marketGroupID]["types"].append(type_id)

    for market_group_id, data in tree.items():
        if data["def"] is None:
            error(f"Market group {market_group_id} has no definition")
            continue

        collection.market_groups.append(
            data["def"].to_pb(
                self_id=market_group_id,
                groups=data["groups"],
                types=data["types"],
            )
        )

    info(f"Generated {cnt} market groups")
