from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING
from typing import Annotated
from typing import Any

from pydantic import BeforeValidator

from data.lib.constant import PROJECT_ROOT


if TYPE_CHECKING:
    from collections.abc import Callable


def __validate_path(value: Any) -> Path:
    p = Path(value)
    if p.is_absolute():
        return p
    return (PROJECT_ROOT / p).resolve()


ProjectPath = Annotated[Path, BeforeValidator(__validate_path)]


def validate_url_template(value: list[str] | str) -> Callable[[Any], str]:
    if isinstance(value, str):
        value = [value]

    def validator(v: Any) -> str:
        if not isinstance(v, str):
            raise TypeError("URL template must be a string")
        for pattern in value:
            if f"{{{pattern}}}" not in v:
                raise ValueError(f"URL template must contain these template value: {value}")
        return v

    return validator
