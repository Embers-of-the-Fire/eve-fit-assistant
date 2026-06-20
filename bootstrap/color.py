from __future__ import annotations

from colorama.ansi import Style


def styled(styles: str | list[str], text: str) -> str:
    out = ""
    if isinstance(styles, list):
        for style in styles:
            out += style
    elif isinstance(styles, str):
        out += styles
    else:
        raise ValueError(f"Invalid style type: {type(styles)}")

    out += text
    out += Style.RESET_ALL

    return out
