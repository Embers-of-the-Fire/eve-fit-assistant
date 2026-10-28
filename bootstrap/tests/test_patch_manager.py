"""Tests for the workspace patches manager."""

from __future__ import annotations

from typing import TYPE_CHECKING

import pytest

from bootstrap.data.resource.patch import PatchesManager


if TYPE_CHECKING:
    from pathlib import Path


class TestGetOptional:
    def test_returns_none_for_missing_file(self, tmp_path: Path) -> None:
        manager = PatchesManager(patches_root_dir=tmp_path)

        assert manager.get_optional("localization", "yaml") is None

    def test_loads_existing_file(self, tmp_path: Path) -> None:
        (tmp_path / "localization.yaml").write_text(
            'zh:\n  "Advanced Carriers": "高级航空母舰"\n', encoding="utf-8"
        )
        manager = PatchesManager(patches_root_dir=tmp_path)

        assert manager.get_optional("localization", "yaml") == {
            "zh": {"Advanced Carriers": "高级航空母舰"}
        }

    def test_empty_file_yields_empty_mapping(self, tmp_path: Path) -> None:
        (tmp_path / "localization.yaml").write_text("", encoding="utf-8")
        manager = PatchesManager(patches_root_dir=tmp_path)

        assert manager.get_optional("localization", "yaml") == {}

    def test_get_still_fails_for_missing_file(self, tmp_path: Path) -> None:
        manager = PatchesManager(patches_root_dir=tmp_path)

        with pytest.raises(SystemExit):
            manager.get("localization", "yaml")
