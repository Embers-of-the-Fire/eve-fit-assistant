from __future__ import annotations

from data.lib.schema import utils_pb2


def loc(loc_id: int) -> utils_pb2.LocalizationID:
    pb = utils_pb2.LocalizationID()
    pb.id = loc_id
    return pb


def icon(icon_id: int | None = None, graphic_id: int | None = None) -> utils_pb2.Icon:
    pb = utils_pb2.Icon()
    if icon_id is not None:
        pb.icon_id = icon_id
    if graphic_id is not None:
        pb.graphic_id = graphic_id
    return pb
