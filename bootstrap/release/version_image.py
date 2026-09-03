"""Version banner image generation — stamps the semver onto the brand banner."""

from __future__ import annotations

import os

from typing import TYPE_CHECKING

import click

from PIL import Image
from PIL import ImageDraw
from PIL import ImageFont

from bootstrap.constant import PROJECT_ROOT
from bootstrap.utils import normalize_version_dir


if TYPE_CHECKING:
    from pathlib import Path


CHANGELOG_ROOT = PROJECT_ROOT / "docs" / "changelog"
DEFAULT_BASE_IMAGE = PROJECT_ROOT / "ci" / "assets" / "version-banner.png"
DEFAULT_FONT = PROJECT_ROOT / "ci" / "assets" / "MapleMono-NF-Bold.ttf"

IMAGE_NAME = "image.png"
LATEST_LINK = CHANGELOG_ROOT / "latest.png"

TEXT_POSITION = (1085, 572)
TEXT_ANCHOR = "la"
TEXT_COLOR = "#ffffff"
FONT_SIZE = 40


def create_version_image(
    semver: str,
    *,
    base_image: Path = DEFAULT_BASE_IMAGE,
    font_path: Path = DEFAULT_FONT,
    force: bool = False,
    dry_run: bool = False,
) -> Path:
    """Stamp the version onto the brand banner for a changelog entry.

    Writes docs/changelog/<version-dir>/image.png and points the shared
    docs/changelog/latest.png symlink at it.
    """
    dir_name = normalize_version_dir(semver)
    directory = CHANGELOG_ROOT / dir_name
    if not directory.is_dir():
        raise click.ClickException(
            f"Changelog directory not found: {directory}. Run './x release relnote' first."
        )

    output_path = directory / IMAGE_NAME
    if output_path.exists() and not force:
        raise click.ClickException(
            f"Version image already exists: {output_path}. Use --force to overwrite."
        )

    if not base_image.is_file():
        raise click.ClickException(f"Base banner image not found: {base_image}")
    if not font_path.is_file():
        raise click.ClickException(f"Font file not found: {font_path}")

    if dry_run:
        return output_path

    try:
        image = Image.open(base_image).convert("RGB")
    except OSError as exc:
        raise click.ClickException(f"Invalid base banner image: {base_image}") from exc
    draw = ImageDraw.Draw(image)
    try:
        font = ImageFont.truetype(str(font_path), FONT_SIZE)
    except OSError as exc:
        raise click.ClickException(f"Invalid font file: {font_path}") from exc
    draw.text(TEXT_POSITION, semver, font=font, fill=TEXT_COLOR, anchor=TEXT_ANCHOR)
    image.save(output_path)

    link_target = os.path.relpath(output_path, LATEST_LINK.parent)
    LATEST_LINK.unlink(missing_ok=True)
    LATEST_LINK.symlink_to(link_target)

    return output_path
