from __future__ import annotations

import asyncio
import pickle

from typing import TYPE_CHECKING

import aiofiles

import bootstrap.config

from bootstrap.data.schema import localizations_pb2
from bootstrap.localization import to_native_localization
from bootstrap.log import info


if TYPE_CHECKING:
    from bootstrap.data.workspace.generate import GeneratorDatasource
    from bootstrap.localization import LocalizationType


def __to_proto_loc_type(loc_type: LocalizationType) -> localizations_pb2.LocalizationLanguage:
    match loc_type:
        case "en":
            return localizations_pb2.LocalizationLanguage.EN
        case "zh":
            return localizations_pb2.LocalizationLanguage.ZH

    raise ValueError(f"Unknown localization type: {loc_type}")


async def generate(ws_data: GeneratorDatasource):
    info("Generating localizations...")

    target_languages = bootstrap.config.CONFIGURATION.localizations.supported

    await asyncio.gather(*(__generate(ws_data, lang) for lang in target_languages))

    info(f"Generated {len(target_languages)} localizations.")


async def __generate(ws_data: GeneratorDatasource, lang: LocalizationType):
    file = ws_data.resources.res.get_resource(
        f"res:/localizationfsd/localization_fsd_{to_native_localization(lang)}.pickle"
    )

    async with file.open() as f:
        _lang_code, loc = pickle.loads(await f.read())

    pb = localizations_pb2.Localization()
    pb.language = __to_proto_loc_type(lang)
    for key, value in loc.items():
        pb.localized_strings[key] = value[0]

    async with aiofiles.open(ws_data.paths.get_localization_path(lang), "wb") as f:
        await f.write(pb.SerializeToString())

    info(f"Generated localization for {lang}.")
