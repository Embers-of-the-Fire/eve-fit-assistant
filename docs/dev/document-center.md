# Document Center

This document explains how bundled document content is authored, generated, and surfaced in the app.

## Source of Truth

- Authored Markdown lives under `assets/content/documents/zh/` and `assets/content/documents/en/`.
- The zh file is the metadata source of truth for each document id.
- The en file only needs the matching `id` in front matter; all shared metadata comes from the zh entry.
- Generated app assets are built by `./x build docs`, which runs `data/lib/docs/build.py`.

## Document Kinds

Three bundled document kinds are currently supported:

- `announcement`: short release-style notes meant to call attention to something new or time-sensitive.
- `information`: durable guidance that helps testers understand expected alpha behavior, supported workflows, and recovery paths.
- `version`: app-version changelog entries that stay visible from Settings.

## Feed Behavior

- The Workspace shortcut opens the mixed Updates feed.
- The mixed Updates feed intentionally shows `announcement`, `information`, and `version` entries together.
- Each card shows a kind badge so testers can distinguish announcements from durable guidance and version notes.
- The Settings Version route stays filtered to `version` entries only.
- Mixed-feed selection is still stored under the legacy storage key `mixed`; do not rename that key without a migration.

## Metadata Rules

Zh front matter must always include:

- `id`
- `kind`
- `publishedAt`
- optional `tags`

Kind-specific rules:

- `announcement`: may include `minAppVer`, must not include `appVer`
- `information`: may include `minAppVer`, must not include `appVer`
- `version`: must include `appVer`, must not include `minAppVer`

The Markdown body must start with a level-1 heading, followed by a paragraph that can be extracted as the summary.

## Writing Guidance

- Put developer-facing implementation details in docs under `docs/`, not in bundled tester content.
- Keep announcements brief and timely.
- Use information entries for tester expectations, known limitations, and recovery guidance that should remain discoverable after the initial announcement scrolls away.
- Add notable information-surface changes to the relevant version changelog so testers can discover them from Settings as well.

## Validation

After changing authored document content or document metadata rules, run:

```bash
./x build docs
./x generate dart
./x generate l10n
./x lint
```
