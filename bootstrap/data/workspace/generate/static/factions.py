"""Faction table: the official faction → member-races mapping.

Copies ``memberRaces`` from FSD ``factions.msgpack`` verbatim into
``Collection.faction_races`` so the app can resolve a type's ``faction_id``
to its parent race (pirate hulls follow their parent race's skybox default)
without shipping the factions table itself.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from bootstrap.log import info


if TYPE_CHECKING:
    from bootstrap.data.schema import collections_pb2
    from bootstrap.data.workspace.generate import GeneratorDatasource


async def generate(data: GeneratorDatasource, collection: collections_pb2.Collection) -> None:
    info("Generating faction races...")
    factions = await data.resources.fsd.get("factions")
    count = 0
    for faction_id, faction_def in factions.items():
        member_races = faction_def.get("memberRaces") or []
        if not member_races:
            continue
        collection.faction_races[int(faction_id)].member_races.extend(int(r) for r in member_races)
        count += 1
    info(f"Generated {count} faction race entries.")
