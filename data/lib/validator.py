from __future__ import annotations

from pathlib import Path
from typing import Annotated
from typing import Any

from pydantic import BeforeValidator

from data.lib.constant import PROJECT_ROOT


def __validate_path(value: Any) -> Path:
    p = Path(value)
    if p.is_absolute():
        return p
    return (PROJECT_ROOT / p).resolve()


ProjectPath = Annotated[Path, BeforeValidator(__validate_path)]
