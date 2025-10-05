from __future__ import annotations

from typing import Annotated
from typing import Literal
from typing import TypeGuard


LocalizationType = Literal["en", "zh"]
NativeLocalizationType = Literal["en-us", "zh"]


def is_valid_localization(loc: str) -> TypeGuard[LocalizationType]:
    return loc in ("en", "zh")


LocalizationModel = Annotated[LocalizationType, is_valid_localization]


def to_native_localization(loc: LocalizationType) -> NativeLocalizationType:
    match loc:
        case "en":
            return "en-us"
        case "zh":
            return "zh"
    raise ValueError(f"Unsupported localization type: {loc}")
