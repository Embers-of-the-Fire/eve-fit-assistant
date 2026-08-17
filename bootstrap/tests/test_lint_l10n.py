from __future__ import annotations

import json

from typing import TYPE_CHECKING

import click
import pytest

from bootstrap.ci.lint_l10n import L10nConfig
from bootstrap.ci.lint_l10n import check_arb_files
from bootstrap.ci.lint_l10n import load_l10n_config
from bootstrap.ci.lint_l10n import run_l10n_lint


if TYPE_CHECKING:
    from pathlib import Path


def _write_arb(directory: Path, name: str, data: dict) -> None:
    (directory / name).write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")


def _make_workspace(tmp_path: Path, template: dict, locales: dict[str, dict]) -> L10nConfig:
    arb_dir = tmp_path / "l10n"
    arb_dir.mkdir()
    _write_arb(arb_dir, "app_zh.arb", template)
    for name, data in locales.items():
        _write_arb(arb_dir, name, data)
    return L10nConfig(arb_dir=arb_dir, template_arb_file="app_zh.arb")


TEMPLATE = {
    "hello": "你好",
    "@_COMMON": {},
    "greeting": "你好 {name}",
    "@greeting": {"placeholders": {"name": {"type": "String"}}},
}


def test_load_l10n_config(tmp_path: Path) -> None:
    config_path = tmp_path / "l10n.yaml"
    config_path.write_text("arb-dir: l10n\ntemplate-arb-file: app_zh.arb\n", encoding="utf-8")
    config = load_l10n_config(config_path)
    assert config.arb_dir == (tmp_path / "l10n").resolve()
    assert config.template_arb_file == "app_zh.arb"
    assert config.template_locale == "zh"


def test_load_l10n_config_missing_file(tmp_path: Path) -> None:
    with pytest.raises(click.ClickException):
        load_l10n_config(tmp_path / "l10n.yaml")


def test_load_l10n_config_missing_keys(tmp_path: Path) -> None:
    config_path = tmp_path / "l10n.yaml"
    config_path.write_text("arb-dir: l10n\n", encoding="utf-8")
    with pytest.raises(click.ClickException):
        load_l10n_config(config_path)


def test_clean_locale_passes(tmp_path: Path) -> None:
    config = _make_workspace(
        tmp_path, TEMPLATE, {"app_en.arb": {"hello": "Hello", "greeting": "Hi, {name}"}}
    )
    assert check_arb_files(config) == []


def test_unexpected_metadata_detected(tmp_path: Path) -> None:
    config = _make_workspace(
        tmp_path,
        TEMPLATE,
        {
            "app_en.arb": {
                "@@locale": "en",
                "hello": "Hello",
                "greeting": "Hi, {name}",
                "@greeting": {"placeholders": {"name": {"type": "String"}}},
                "@@_SECTION": {},
            }
        },
    )
    violations = check_arb_files(config)
    metadata = [v for v in violations if v.kind == "unexpected-metadata"]
    assert {v.message for v in metadata} == {
        'metadata entry "@greeting" is only allowed in the template file (app_zh.arb)',
        'metadata entry "@@_SECTION" is only allowed in the template file (app_zh.arb)',
    }
    assert all(v.file == "app_en.arb" for v in metadata)


def test_missing_translation_detected(tmp_path: Path) -> None:
    config = _make_workspace(tmp_path, TEMPLATE, {"app_en.arb": {"hello": "Hello"}})
    violations = check_arb_files(config)
    assert len(violations) == 1
    assert violations[0].kind == "missing-key"
    assert violations[0].message == 'missing translation "greeting"'


def test_unexpected_key_detected(tmp_path: Path) -> None:
    config = _make_workspace(
        tmp_path,
        TEMPLATE,
        {"app_en.arb": {"hello": "Hello", "greeting": "Hi, {name}", "rogue": "Rogue"}},
    )
    violations = check_arb_files(config)
    assert len(violations) == 1
    assert violations[0].kind == "unexpected-key"
    assert '"rogue"' in violations[0].message


def test_placeholder_mismatch_detected(tmp_path: Path) -> None:
    config = _make_workspace(
        tmp_path, TEMPLATE, {"app_en.arb": {"hello": "Hello", "greeting": "Hi, {title}"}}
    )
    violations = check_arb_files(config)
    assert len(violations) == 1
    assert violations[0].kind == "placeholder-mismatch"
    assert "{name}" in violations[0].message
    assert "{title}" in violations[0].message


def test_multiple_locale_files_checked_independently(tmp_path: Path) -> None:
    config = _make_workspace(
        tmp_path,
        TEMPLATE,
        {
            "app_en.arb": {"hello": "Hello", "greeting": "Hi, {name}"},
            "app_fr.arb": {"hello": "Bonjour"},
        },
    )
    violations = check_arb_files(config)
    assert len(violations) == 1
    assert violations[0].file == "app_fr.arb"
    assert violations[0].kind == "missing-key"


def test_run_l10n_lint_raises_on_violations(tmp_path: Path) -> None:
    _make_workspace(tmp_path, TEMPLATE, {"app_en.arb": {"hello": "Hello"}})
    config_path = tmp_path / "l10n.yaml"
    config_path.write_text("arb-dir: l10n\ntemplate-arb-file: app_zh.arb\n", encoding="utf-8")
    with pytest.raises(click.ClickException):
        run_l10n_lint(config_path=config_path)


def test_run_l10n_lint_passes_on_clean(tmp_path: Path) -> None:
    _make_workspace(
        tmp_path, TEMPLATE, {"app_en.arb": {"hello": "Hello", "greeting": "Hi, {name}"}}
    )
    config_path = tmp_path / "l10n.yaml"
    config_path.write_text("arb-dir: l10n\ntemplate-arb-file: app_zh.arb\n", encoding="utf-8")
    run_l10n_lint(config_path=config_path)


def test_run_l10n_lint_dry_run_skips(tmp_path: Path) -> None:
    run_l10n_lint(dry_run=True, config_path=tmp_path / "nonexistent.yaml")
