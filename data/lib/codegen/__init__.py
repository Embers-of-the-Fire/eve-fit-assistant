from __future__ import annotations

from data.lib.codegen import asset
from data.lib.codegen import attr_id
from data.lib.codegen import localization


CODEGEN_DART = [asset.codegen_dart, localization.codegen_dart, attr_id.codegen_dart]
