from __future__ import annotations

import json
import re
import sys

from dataclasses import dataclass
from pathlib import Path

import click
import yaml

from colorama import Fore
from colorama import Style

from bootstrap.color import styled
from bootstrap.constant import PROJECT_ROOT
from bootstrap.log import error
from bootstrap.log import info


__all__ = ["L10nConfig", "L10nViolation", "check_arb_files", "load_l10n_config", "run_l10n_lint"]


L10N_CONFIG_PATH = PROJECT_ROOT / "l10n.yaml"

_PLACEHOLDER_PATTERN = re.compile(r"\{(\w+)\}")


@dataclass(frozen=True)
class L10nConfig:
    arb_dir: Path
    template_arb_file: str

    @property
    def template_locale(self) -> str:
        return Path(self.template_arb_file).stem.removeprefix("app_")


@dataclass(frozen=True)
class L10nViolation:
    file: str
    kind: str
    message: str


def load_l10n_config(config_path: Path = L10N_CONFIG_PATH) -> L10nConfig:
    if not config_path.is_file():
        raise click.ClickException(f"l10n config not found: {config_path}")
    raw = yaml.safe_load(config_path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise click.ClickException(f"l10n config is not a mapping: {config_path}")
    arb_dir = raw.get("arb-dir")
    template_arb_file = raw.get("template-arb-file")
    if not arb_dir or not template_arb_file:
        raise click.ClickException(
            f"l10n config must define 'arb-dir' and 'template-arb-file': {config_path}"
        )
    return L10nConfig(
        arb_dir=(config_path.parent / str(arb_dir)).resolve(),
        template_arb_file=str(template_arb_file),
    )


def _load_arb(path: Path) -> dict[str, object]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise click.ClickException(f"Invalid ARB (JSON) file {path}: {exc}") from exc
    if not isinstance(data, dict):
        raise click.ClickException(f"ARB file is not a JSON object: {path}")
    return data


def _placeholders(value: object) -> set[str]:
    if not isinstance(value, str):
        return set()
    return set(_PLACEHOLDER_PATTERN.findall(value))


def check_arb_files(config: L10nConfig) -> list[L10nViolation]:
    template_path = config.arb_dir / config.template_arb_file
    if not template_path.is_file():
        raise click.ClickException(f"Template ARB file not found: {template_path}")
    template = _load_arb(template_path)
    template_keys = {key for key in template if not key.startswith("@")}

    violations: list[L10nViolation] = []
    locale_files = sorted(
        path for path in config.arb_dir.glob("*.arb") if path.name != config.template_arb_file
    )
    for path in locale_files:
        data = _load_arb(path)
        name = path.name
        message_keys = {key for key in data if not key.startswith("@")}

        for key in sorted(data):
            if key.startswith("@"):
                violations.append(
                    L10nViolation(
                        file=name,
                        kind="unexpected-metadata",
                        message=f'metadata entry "{key}" is only allowed in '
                        f"the template file ({config.template_arb_file})",
                    )
                )

        for key in sorted(template_keys - message_keys):
            violations.append(
                L10nViolation(file=name, kind="missing-key", message=f'missing translation "{key}"')
            )

        for key in sorted(message_keys - template_keys):
            violations.append(
                L10nViolation(
                    file=name,
                    kind="unexpected-key",
                    message=f'key "{key}" is not defined in '
                    f"the template file ({config.template_arb_file})",
                )
            )

        for key in sorted(template_keys & message_keys):
            expected = _placeholders(template[key])
            actual = _placeholders(data[key])
            missing = sorted(expected - actual)
            extra = sorted(actual - expected)
            if missing or extra:
                parts = []
                if missing:
                    parts.append("missing placeholders " + ", ".join(f"{{{p}}}" for p in missing))
                if extra:
                    parts.append("unexpected placeholders " + ", ".join(f"{{{p}}}" for p in extra))
                violations.append(
                    L10nViolation(
                        file=name,
                        kind="placeholder-mismatch",
                        message=f'key "{key}": ' + "; ".join(parts),
                    )
                )

    return violations


def run_l10n_lint(*, dry_run: bool = False, config_path: Path = L10N_CONFIG_PATH) -> None:
    title = " L10N LINT OUTPUT "
    line_width = 30
    click.echo(styled([Style.BRIGHT, Fore.CYAN], title + "-" * max(0, line_width - len(title))))

    if dry_run:
        info("[Dry-Run] L10N LINT: skipped")
        return

    config = load_l10n_config(config_path)
    violations = check_arb_files(config)

    if violations:
        current_file = None
        for violation in violations:
            if violation.file != current_file:
                current_file = violation.file
                error(f"[{current_file}]")
            error(f"  ({violation.kind}) {violation.message}")
        summary = f"l10n lint failed: {len(violations)} violation(s) found."
        error(summary)
        raise click.ClickException(summary)

    click.echo(styled([Style.BRIGHT, Fore.GREEN], "l10n lint passed: no violations found."))
    sys.stdout.flush()
