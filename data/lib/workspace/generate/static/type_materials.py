from __future__ import annotations

from typing import TYPE_CHECKING

from pydantic import BaseModel

from data.lib.log import error
from data.lib.log import info
from data.lib.schema import type_materials_pb2


if TYPE_CHECKING:
    from data.lib.workspace.generate import GeneratorDatasource


class TypeMaterialDef(BaseModel):
    class TypeMaterialItem(BaseModel):
        materialTypeID: int
        quantity: int

    materials: list[TypeMaterialItem]

    def to_pb(self, self_id: int) -> type_materials_pb2.TypeMaterial:
        pb = type_materials_pb2.TypeMaterial()

        pb.type_id = self_id
        for material in self.materials:
            mat = pb.materials.add()
            mat.material_type_id = material.materialTypeID
            mat.quantity = material.quantity

        return pb


async def generate(data: GeneratorDatasource, collection):
    info("Generating type materials...")
    type_materials = await data.resources.fsd.get("typeMaterials")

    cnt = 0
    for type_material_id, type_material_def in type_materials.items():
        try:
            validated = TypeMaterialDef.model_validate(type_material_def)
        except Exception as e:
            error(f"Failed to validate type material {type_material_id}: {e}")
            continue

        cnt += 1
        collection.type_materials.append(validated.to_pb(type_material_id))

    info(f"Generated {cnt} type materials")
