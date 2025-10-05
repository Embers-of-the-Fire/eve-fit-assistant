from __future__ import annotations

from typing import TYPE_CHECKING

from pydantic import BaseModel
from pydantic import Field

from data.lib.log import error
from data.lib.log import info
from data.lib.schema import dogma_units_pb2
from data.lib.workspace.generate.static.utils import loc


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


class DogmaUnitDef(BaseModel):
    displayNameID: int | None = Field(default=None)
    name: str

    def to_pb(self, self_id: int) -> dogma_units_pb2.DogmaUnit:
        pb = dogma_units_pb2.DogmaUnit()

        pb.dogma_unit_id = self_id
        if self.displayNameID is not None:
            pb.display_name.CopyFrom(loc(self.displayNameID))
        pb.name = self.name

        return pb


async def generate(data: GeneratorDatasource, collection):
    info("Generating dogma units...")
    dogma_units = await data.resources.fsd.get("dogmaUnits")

    cnt = 0
    for dogma_unit_id, dogma_unit_def in dogma_units.items():
        try:
            validated = DogmaUnitDef.model_validate(dogma_unit_def)
        except Exception as e:
            error(f"Failed to validate dogma unit {dogma_unit_id}: {e}")
            continue

        cnt += 1
        collection.dogma_units.append(validated.to_pb(dogma_unit_id))

    info(f"Generated {cnt} dogma units")
