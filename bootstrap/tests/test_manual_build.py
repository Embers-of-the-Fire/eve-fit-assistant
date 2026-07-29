from __future__ import annotations

import hashlib

from typing import TYPE_CHECKING
from unittest.mock import patch

import pytest

from bootstrap.data.schema import manual_pb2
from bootstrap.docs import manual as manual_builder
from bootstrap.docs.manual import build_manual
from bootstrap.docs.manual import content_file_hash
from bootstrap.docs.manual import load_manual_tree


if TYPE_CHECKING:
    from pathlib import Path


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _make_doc(
    directory: Path,
    *,
    zh: str | None = None,
    en: str | None = None,
    zh_frontmatter: str = "",
    en_frontmatter: str = "",
) -> None:
    doc_id = directory.name
    zh_body = zh if zh is not None else f"# {doc_id} 标题\n\n这是 {doc_id} 的摘要段落。\n\n正文。\n"
    en_body = (
        en if en is not None else f"# {doc_id} Title\n\nSummary paragraph for {doc_id}.\n\nBody.\n"
    )
    _write(
        directory / "zh.md", f"---\n{zh_frontmatter}---\n\n{zh_body}" if zh_frontmatter else zh_body
    )
    _write(
        directory / "en.md", f"---\n{en_frontmatter}---\n\n{en_body}" if en_frontmatter else en_body
    )


def _make_folder(
    directory: Path, *, children: list[str] | None = None, zh_name: str | None = None
) -> None:
    folder_id = directory.name
    zh_line = f"  zh: {zh_name}\n" if zh_name is not None else f"  zh: {folder_id} 名称\n"
    children_block = ""
    if children is not None:
        children_block = "children:\n" + "".join(f"  - {child}\n" for child in children)
    _write(
        directory / "folder.yaml",
        f"id: {folder_id}\nname:\n{zh_line}  en: {folder_id} Name\n{children_block}",
    )


def _make_sample_tree(root: Path) -> None:
    _write(root / "folder.yaml", "children:\n  - getting-started\n  - fitting\n")
    _make_folder(root / "getting-started", children=["create-first-fit", "browse-ships"])
    _make_doc(root / "getting-started" / "create-first-fit")
    _make_doc(root / "getting-started" / "browse-ships")
    _make_folder(root / "fitting", children=["modules"])
    _make_doc(root / "fitting" / "modules")


@pytest.fixture
def manual_paths(tmp_path: Path):
    source_root = tmp_path / "docs" / "manual"
    generated_root = tmp_path / "assets" / "content" / "manual" / "generated"
    with (
        patch.object(manual_builder, "MANUAL_SOURCE_ROOT", source_root),
        patch.object(manual_builder, "GENERATED_ROOT", generated_root),
        patch.object(manual_builder, "GENERATED_REGISTRY_PATH", generated_root / "manual.pb"),
        patch.object(manual_builder, "GENERATED_CONTENT_ROOT", generated_root / "content"),
        patch.object(manual_builder, "GENERATED_GITIGNORE_PATH", generated_root / ".gitignore"),
        patch.object(
            manual_builder, "CONTENT_GITKEEP_PATH", generated_root / "content" / ".gitkeep"
        ),
    ):
        yield source_root, generated_root


class TestContentFileHash:
    def test_matches_sha256_id_locale_convention(self) -> None:
        expected = hashlib.sha256(b"fitting/modules:zh").hexdigest()
        assert content_file_hash("fitting/modules", "zh") == expected

    def test_full_lowercase_hex_untruncated(self) -> None:
        digest = content_file_hash("a", "en")
        assert len(digest) == 64
        assert digest == digest.lower()


class TestLoadManualTree:
    def test_nested_tree_with_path_joined_ids(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _make_sample_tree(source_root)

        root = load_manual_tree()

        assert [f.id for f in root.folders] == ["getting-started", "fitting"]
        getting_started = root.folders[0]
        assert getting_started.name == {
            "zh": "getting-started 名称",
            "en": "getting-started Name",
        }
        assert [d.id for d in getting_started.docs] == [
            "getting-started/create-first-fit",
            "getting-started/browse-ships",
        ]
        assert [d.id for d in root.folders[1].docs] == ["fitting/modules"]

    def test_children_order_from_parent_folder_yaml(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _make_folder(source_root / "f", children=["b-doc", "z-doc", "a-doc"])
        _make_doc(source_root / "f" / "a-doc")
        _make_doc(source_root / "f" / "b-doc")
        _make_doc(source_root / "f" / "z-doc")

        root = load_manual_tree()

        assert [d.id for d in root.folders[0].docs] == ["f/b-doc", "f/z-doc", "f/a-doc"]
        assert [d.order for d in root.folders[0].docs] == [0, 1, 2]

    def test_children_default_is_alphabetical(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _make_folder(source_root / "f")
        _make_doc(source_root / "f" / "b-doc")
        _make_doc(source_root / "f" / "a-doc")

        root = load_manual_tree()

        assert [d.id for d in root.folders[0].docs] == ["f/a-doc", "f/b-doc"]

    def test_root_folder_yaml_orders_top_level(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _make_folder(source_root / "b-folder")
        _make_folder(source_root / "a-folder")
        _write(source_root / "folder.yaml", "children:\n  - b-folder\n  - a-folder\n")

        root = load_manual_tree()

        assert [f.id for f in root.folders] == ["b-folder", "a-folder"]

    def test_children_unknown_entry_raises(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _make_folder(source_root / "f", children=["a-doc", "ghost"])
        _make_doc(source_root / "f" / "a-doc")

        with pytest.raises(ValueError, match="unknown: ghost"):
            load_manual_tree()

    def test_children_missing_entry_raises(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _make_folder(source_root / "f", children=["a-doc"])
        _make_doc(source_root / "f" / "a-doc")
        _make_doc(source_root / "f" / "b-doc")

        with pytest.raises(ValueError, match="missing: b-doc"):
            load_manual_tree()

    def test_children_duplicate_entry_raises(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _make_folder(source_root / "f", children=["a-doc", "a-doc"])
        _make_doc(source_root / "f" / "a-doc")

        with pytest.raises(ValueError, match="Duplicate entries"):
            load_manual_tree()

    def test_missing_source_root_yields_empty_tree(self, manual_paths) -> None:
        root = load_manual_tree()
        assert root.folders == []
        assert root.docs == []

    def test_missing_locale_file_raises(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _make_folder(source_root / "f")
        _make_doc(source_root / "f" / "doc")
        (source_root / "f" / "doc" / "en.md").unlink()

        with pytest.raises(ValueError, match=r"en\.md"):
            load_manual_tree()

    def test_folder_id_must_match_directory(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _make_folder(source_root / "f")
        _write(source_root / "f" / "folder.yaml", "id: other\nname:\n  zh: a\n  en: b\n")

        with pytest.raises(ValueError, match="does not match"):
            load_manual_tree()

    def test_directory_without_spec_raises(self, manual_paths) -> None:
        source_root, _ = manual_paths
        (source_root / "stray").mkdir(parents=True)

        with pytest.raises(ValueError, match="neither a folder"):
            load_manual_tree()

    def test_folder_name_requires_all_locales(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _write(source_root / "f" / "folder.yaml", "id: f\nname:\n  zh: 名称\n")

        with pytest.raises(ValueError, match="locale"):
            load_manual_tree()

    def test_invalid_id_pattern_raises(self, manual_paths) -> None:
        source_root, _ = manual_paths
        (source_root / "Bad_Id").mkdir(parents=True)
        _write(source_root / "Bad_Id" / "folder.yaml", "id: Bad_Id\nname:\n  zh: a\n  en: b\n")

        with pytest.raises(ValueError, match="Invalid manual entry id"):
            load_manual_tree()


class TestFrontmatter:
    def test_title_summary_override(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _make_folder(source_root / "f")
        _make_doc(
            source_root / "f" / "doc",
            zh_frontmatter="title: 覆盖标题\n",
            en_frontmatter="summary: Overridden summary.\n",
        )

        root = load_manual_tree()

        locs = root.folders[0].docs[0].localizations
        assert locs["zh"].title == "覆盖标题"
        assert locs["zh"].summary == "这是 doc 的摘要段落。"
        assert locs["en"].title == "doc Title"
        assert locs["en"].summary == "Overridden summary."

    def test_frontmatter_not_leaked_into_body(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _make_folder(source_root / "f")
        _make_doc(source_root / "f" / "doc", en_frontmatter="title: T\n")

        root = load_manual_tree()

        body = root.folders[0].docs[0].localizations["en"].body_markdown
        assert "---" not in body
        assert body.startswith("Summary paragraph")

    def test_unknown_frontmatter_key_raises(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _make_folder(source_root / "f")
        _make_doc(source_root / "f" / "doc", en_frontmatter="tags: [a]\n")

        with pytest.raises(ValueError, match="Unknown frontmatter keys"):
            load_manual_tree()

    def test_non_string_frontmatter_value_raises(self, manual_paths) -> None:
        source_root, _ = manual_paths
        _make_folder(source_root / "f")
        _make_doc(source_root / "f" / "doc", en_frontmatter="title: 42\n")

        # 42 is valid YAML for an int; frontmatter title must be a string.
        with pytest.raises(TypeError, match="must be strings"):
            load_manual_tree()


class TestBuildManual:
    def test_build_outputs_registry_and_content(self, manual_paths) -> None:
        source_root, generated_root = manual_paths
        _make_sample_tree(source_root)

        build_manual()

        registry_path = generated_root / "manual.pb"
        assert registry_path.exists()

        registry = manual_pb2.ManualRegistry()
        registry.ParseFromString(registry_path.read_bytes())
        assert registry.schema_version == 1
        assert [f.id for f in registry.folders] == ["getting-started", "fitting"]

        doc = registry.folders[0].docs[0]
        assert doc.id == "getting-started/create-first-fit"
        assert set(doc.localizations.keys()) == {"zh", "en"}

        content_root = generated_root / "content"
        for locale, loc in doc.localizations.items():
            expected = f"{hashlib.sha256(f'{doc.id}:{locale}'.encode()).hexdigest()}.md"
            assert loc.content_file == expected
            body = (content_root / loc.content_file).read_text(encoding="utf-8")
            assert "摘要段落" in body or "Summary paragraph" in body

        # 3 docs x 2 locales content files.
        content_files = [p for p in content_root.iterdir() if p.suffix == ".md"]
        assert len(content_files) == 6

    def test_build_is_idempotent_and_cleans_stale_files(self, manual_paths) -> None:
        source_root, generated_root = manual_paths
        _make_sample_tree(source_root)

        build_manual()
        stale = generated_root / "content" / "stale.md"
        stale.write_text("stale", encoding="utf-8")

        build_manual()

        assert not stale.exists()
        registry = manual_pb2.ManualRegistry()
        registry.ParseFromString((generated_root / "manual.pb").read_bytes())
        assert [f.id for f in registry.folders] == ["getting-started", "fitting"]

    def test_build_empty_source_produces_empty_registry(self, manual_paths) -> None:
        _, generated_root = manual_paths

        build_manual()

        registry = manual_pb2.ManualRegistry()
        registry.ParseFromString((generated_root / "manual.pb").read_bytes())
        assert len(registry.folders) == 0
