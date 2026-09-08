from __future__ import annotations

from bootstrap.data.codegen import asset
from bootstrap.data.codegen import attr_id
from bootstrap.data.codegen import localization
from bootstrap.data.codegen import resource_vocabulary
from bootstrap.data.codegen import schema_version


CODEGEN_DART = [
    asset.codegen_dart,
    schema_version.codegen_dart,
    localization.codegen_dart,
    resource_vocabulary.codegen_dart,
    attr_id.codegen_dart,
]
