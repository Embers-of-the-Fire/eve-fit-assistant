"""Generate Astro Starlight content for site/manual from docs/ raw sources.

Sources:
  - docs/manual/**          -> manual pages (folder tree, per-locale zh/en markdown)
  - docs/changelog/**       -> release-note pages (spec.yaml + content.{en,zh}.md + changelog.md)
  - docs/announcements/**   -> announcement pages (spec.yaml + {en,zh}.md)

Outputs (all generated, git-ignored):
  - site/manual/src/content/docs/**        root-locale (English) pages
  - site/manual/src/content/docs/zh/**     Chinese pages
  - site/manual/src/generated/sidebar.json sidebar tree consumed by astro.config.mjs
"""

from __future__ import annotations

import json
import re
import shutil

from dataclasses import dataclass

import yaml

from bootstrap.constant import PROJECT_ROOT
from bootstrap.docs import bundled_docs
from bootstrap.docs.manual import ManualDocNode
from bootstrap.docs.manual import ManualFolderNode
from bootstrap.docs.manual import load_manual_tree
from bootstrap.log import info


SITE_ROOT = PROJECT_ROOT / "site" / "manual"
GENERATED_DOCS_ROOT = SITE_ROOT / "src" / "content" / "docs"
GENERATED_DATA_ROOT = SITE_ROOT / "src" / "generated"
SIDEBAR_PATH = GENERATED_DATA_ROOT / "sidebar.json"

ROOT_LOCALE = "en"
LOCALES = ("en", "zh")

# Starlight resolves sidebar label translations by BCP-47 lang tag, not locale key.
# Keep in sync with the `zh` locale `lang` in site/manual/astro.config.mjs.
ZH_LANG_TAG = "zh-CN"

EFA_LINK_PATTERN = re.compile(r"\]\(efa://manual/([a-z0-9][a-z0-9/-]*)\)")

CHANGELOG_GROUP_LABEL = {"en": "Changelog", "zh": "更新日志"}
ANNOUNCEMENTS_GROUP_LABEL = {"en": "Announcements", "zh": "公告"}

HERO_TITLE = "EVE Fit Assistant"
HERO_TAGLINE = {
    "en": "Fitting assistant for EVE Online — browse ships, plan fits, and share them anywhere.",
    "zh": "EVE Online 配装助手 —— 浏览舰船、规划配置，并与任何人分享。",  # noqa: RUF001
}
HERO_ACTION_MANUAL = {"en": "Read the Manual", "zh": "阅读手册"}
HERO_ACTION_CHANGELOG = {"en": "Changelog", "zh": "更新日志"}


@dataclass(frozen=True)
class ManualTargets:
    doc_slugs: set[str]
    folder_first_doc: dict[str, str]


def _locale_prefix(locale: str) -> str:
    return "" if locale == ROOT_LOCALE else f"/{locale}"


def _collect_manual_targets(node: ManualFolderNode, targets: ManualTargets) -> None:
    for doc in node.docs:
        targets.doc_slugs.add(doc.id)
    first = _first_doc_id(node)
    if first is not None and node.id:
        targets.folder_first_doc[node.id] = first
    for folder in node.folders:
        _collect_manual_targets(folder, targets)


def _first_doc_id(node: ManualFolderNode) -> str | None:
    children = sorted([*node.folders, *node.docs], key=lambda child: child.order)
    for child in children:
        if isinstance(child, ManualDocNode):
            return child.id
        nested = _first_doc_id(child)
        if nested is not None:
            return nested
    return None


def _rewrite_links(body: str, locale: str, targets: ManualTargets) -> str:
    prefix = _locale_prefix(locale)

    def _replace(match: re.Match[str]) -> str:
        target = match.group(1)
        if target in targets.doc_slugs:
            return f"]({prefix}/{target}/)"
        first_doc = targets.folder_first_doc.get(target)
        if first_doc is not None:
            return f"]({prefix}/{first_doc}/)"
        raise ValueError(f"Unresolved manual link target: efa://manual/{target}")

    return EFA_LINK_PATTERN.sub(_replace, body)


def _render_frontmatter(fields: dict) -> str:
    rendered = yaml.safe_dump(fields, allow_unicode=True, sort_keys=False).strip()
    return f"---\n{rendered}\n---\n"


def _write_page(slug: str, locale: str, frontmatter_fields: dict, body: str) -> None:
    base = GENERATED_DOCS_ROOT if locale == ROOT_LOCALE else GENERATED_DOCS_ROOT / locale
    path = base / f"{slug}.md"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(_render_frontmatter(frontmatter_fields) + "\n" + body, encoding="utf-8")


def _folder_sidebar(node: ManualFolderNode) -> dict:
    children = sorted([*node.folders, *node.docs], key=lambda child: child.order)
    items: list[dict] = []
    for child in children:
        if isinstance(child, ManualFolderNode):
            items.append(_folder_sidebar(child))
        else:
            items.append(
                {
                    "label": child.localizations[ROOT_LOCALE].title,
                    "translations": {ZH_LANG_TAG: child.localizations["zh"].title},
                    "slug": child.id,
                }
            )
    return {
        "label": node.name[ROOT_LOCALE],
        "translations": {ZH_LANG_TAG: node.name["zh"]},
        "collapsed": True,
        "items": items,
    }


def _generate_manual(root: ManualFolderNode, targets: ManualTargets) -> list[dict]:
    for doc in _iter_docs(root):
        for locale in LOCALES:
            localization = doc.localizations[locale]
            body = _rewrite_links(localization.body_markdown, locale, targets)
            _write_page(
                doc.id,
                locale,
                {"title": localization.title, "description": localization.summary},
                body,
            )
    return [_folder_sidebar(folder) for folder in root.folders]


def _iter_docs(node: ManualFolderNode):
    yield from node.docs
    for folder in node.folders:
        yield from _iter_docs(folder)


def _load_changelog_entries() -> list[bundled_docs.BundledEntry]:
    entries = [
        bundled_docs._load_release_note(version_dir, directory)
        for version_dir, directory in bundled_docs._iter_changelog_dirs()
    ]
    entries.sort(key=lambda entry: entry.metadata.published_at, reverse=True)
    return entries


def _load_announcement_entries() -> list[bundled_docs.BundledEntry]:
    entries = [
        bundled_docs._load_general_announcement(entry_id, directory)
        for entry_id, directory in bundled_docs._iter_announcement_dirs()
    ]
    entries.sort(key=lambda entry: entry.metadata.published_at, reverse=True)
    return entries


def _generate_changelog(
    entries: list[bundled_docs.BundledEntry], targets: ManualTargets
) -> tuple[dict, str | None]:
    items: list[dict] = []
    newest_slug: str | None = None
    for entry in entries:
        slug = f"changelog/{entry.id.removeprefix('version-')}"
        if newest_slug is None:
            newest_slug = slug
        for locale in LOCALES:
            document = entry.localizations[locale]
            body = _rewrite_links(document.body_markdown, locale, targets)
            _write_page(
                slug,
                locale,
                {"title": document.title, "description": document.summary},
                body,
            )
        label = f"v{entry.metadata.app_version}"
        items.append({"label": label, "translations": {ZH_LANG_TAG: label}, "slug": slug})

    group = {
        "label": CHANGELOG_GROUP_LABEL[ROOT_LOCALE],
        "translations": {ZH_LANG_TAG: CHANGELOG_GROUP_LABEL["zh"]},
        "collapsed": True,
        "items": items,
    }
    return group, newest_slug


def _generate_announcements(
    entries: list[bundled_docs.BundledEntry], targets: ManualTargets
) -> dict:
    items: list[dict] = []
    for entry in entries:
        slug = f"announcements/{entry.id}"
        for locale in LOCALES:
            document = entry.localizations[locale]
            body = _rewrite_links(document.body_markdown, locale, targets)
            _write_page(
                slug,
                locale,
                {"title": document.title, "description": document.summary},
                body,
            )
        items.append(
            {
                "label": entry.localizations[ROOT_LOCALE].title,
                "translations": {ZH_LANG_TAG: entry.localizations["zh"].title},
                "slug": slug,
            }
        )
    return {
        "label": ANNOUNCEMENTS_GROUP_LABEL[ROOT_LOCALE],
        "translations": {ZH_LANG_TAG: ANNOUNCEMENTS_GROUP_LABEL["zh"]},
        "collapsed": True,
        "items": items,
    }


def _generate_index(first_doc_slug: str | None, newest_changelog_slug: str | None) -> None:
    for locale in LOCALES:
        prefix = _locale_prefix(locale)
        actions = []
        if first_doc_slug is not None:
            actions.append(
                {
                    "text": HERO_ACTION_MANUAL[locale],
                    "link": f"{prefix}/{first_doc_slug}/",
                    "icon": "right-arrow",
                }
            )
        if newest_changelog_slug is not None:
            actions.append(
                {
                    "text": HERO_ACTION_CHANGELOG[locale],
                    "link": f"{prefix}/{newest_changelog_slug}/",
                    "variant": "minimal",
                }
            )
        frontmatter_fields = {
            "title": HERO_TITLE,
            "description": HERO_TAGLINE[locale],
            "template": "splash",
            "hero": {"tagline": HERO_TAGLINE[locale], "actions": actions},
        }
        base = GENERATED_DOCS_ROOT if locale == ROOT_LOCALE else GENERATED_DOCS_ROOT / locale
        path = base / "index.mdx"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(_render_frontmatter(frontmatter_fields) + "\n", encoding="utf-8")


def _prepare_generated_roots() -> None:
    for root in (GENERATED_DOCS_ROOT, GENERATED_DATA_ROOT):
        if root.exists():
            shutil.rmtree(root)
        root.mkdir(parents=True, exist_ok=True)


def build_site_manual() -> None:
    """Generate Starlight content for site/manual from docs/ raw sources."""
    info("Building site manual content...")

    manual_root = load_manual_tree()
    targets = ManualTargets(doc_slugs=set(), folder_first_doc={})
    _collect_manual_targets(manual_root, targets)

    changelog_entries = _load_changelog_entries()
    announcement_entries = _load_announcement_entries()

    _prepare_generated_roots()

    sidebar = _generate_manual(manual_root, targets)
    changelog_group, newest_changelog_slug = _generate_changelog(changelog_entries, targets)
    if changelog_group["items"]:
        sidebar.append(changelog_group)
    announcements_group = _generate_announcements(announcement_entries, targets)
    if announcements_group["items"]:
        sidebar.append(announcements_group)

    _generate_index(_first_doc_id(manual_root), newest_changelog_slug)

    SIDEBAR_PATH.write_text(
        json.dumps(sidebar, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    doc_count = sum(1 for _ in _iter_docs(manual_root))
    info(
        f"Generated site manual content "
        f"({doc_count} manual docs, {len(changelog_entries)} changelog entries, "
        f"{len(announcement_entries)} announcements): {GENERATED_DOCS_ROOT}"
    )
