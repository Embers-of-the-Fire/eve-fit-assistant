from __future__ import annotations

import io

from dotenv import dotenv_values

from bootstrap.cli.dev import _quote_dotenv_value


def _round_trip(value: object) -> str:
    rendered = f"KEY={_quote_dotenv_value(value)}\n"
    parsed = dotenv_values(stream=io.StringIO(rendered))["KEY"]
    assert parsed is not None
    return parsed


def test_windows_path_with_backslashes():
    path = r"D:\a\eve-fit-assistant\eve-fit-assistant\ci-native"
    assert _round_trip(path) == path


def test_windows_path_with_newline_like_segment():
    path = r"D:\nonexistent"
    assert _round_trip(path) == path


def test_windows_path_with_spaces():
    path = r"C:\Users\John Doe\eve fit\cache\native"
    assert _round_trip(path) == path


def test_plain_value():
    assert _round_trip("msgpack") == "msgpack"


def test_unc_path():
    path = r"\\server\share\dir"
    assert _round_trip(path) == path


def test_trailing_backslash():
    path = "trailing\\"
    assert _round_trip(path) == path


def test_single_quote():
    value = "it's"
    assert _round_trip(value) == value


def test_backslash_and_single_quote():
    path = r"C:\O'Brien\dir"
    assert _round_trip(path) == path


def test_double_quote_and_dollar():
    value = 'say "hi" \\ $HOME'
    assert _round_trip(value) == value


def test_dollar_not_substituted():
    value = r"\$HOME\dir"
    assert _round_trip(value) == value


def test_single_quote_and_dollar():
    value = "it's $HOME"
    assert _round_trip(value) == value
