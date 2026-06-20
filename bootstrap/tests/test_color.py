from __future__ import annotations

import pytest

from colorama.ansi import Fore
from colorama.ansi import Style

from bootstrap.color import styled


def test_styled_single_foreground():
    result = styled(Fore.RED, "error")
    assert result == f"{Fore.RED}error{Style.RESET_ALL}"


def test_styled_list_of_styles():
    result = styled([Style.BRIGHT, Fore.GREEN], "ok")
    assert result == f"{Style.BRIGHT}{Fore.GREEN}ok{Style.RESET_ALL}"


def test_styled_invalid_type_raises():
    with pytest.raises(ValueError, match="Invalid style type"):
        styled(42, "text")


def test_styled_empty_text():
    result = styled(Fore.BLUE, "")
    assert result == f"{Fore.BLUE}{Style.RESET_ALL}"
