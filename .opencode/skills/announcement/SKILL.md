---
name: announcement
description: Write a new bilingual standalone announcement, either as a checked-in persisted entry under docs/announcements or as a pure-remote entry staged with './x remote announce'. Use for general announcements rather than version release notes.
license: MIT
compatibility: opencode
---

## What I do

- Determine whether the announcement is **checked-in/persisted** or **pure-remote**.
- Author equivalent English and Chinese titles, summaries, bodies, and targeting metadata.
- Create persisted source files, or stage a remote entry without creating checked-in content.

## When to use me

Use this for a new general announcement such as maintenance, a feature introduction, or a service
notice. For version release notes, use the `changelog` skill and the existing
`./x remote announce add-release-note` workflow instead of composing a release entry manually.

## Choose the delivery mode first

If the user has not specified a mode, ask. Do not silently create checked-in files for a
pure-remote request or stage a remote entry when persisted content was requested.

| Mode | Source of truth | Result |
| ---- | --------------- | ------ |
| Checked-in/persisted | `docs/announcements/<id>/` | Versioned source bundled into app content and available to site generation |
| Pure-remote | The remote announcement workspace, by default `cache/announce/` | A staged remote delta with no announcement source added to git |

A remote entry is not visible to users merely because it was staged. It becomes visible only after
the user publishes it successfully.

## Inputs

Collect or confirm:

- **Delivery mode** (required): persisted or pure-remote.
- **Entry ID** (required): match `^[a-z0-9][a-z0-9._-]*$`; check that it is not already used.
- **English and Chinese content** (required): title, informative summary, and body.
- **Publication timestamp** (required): ISO-8601 with a timezone, preferably UTC such as
  `2026-11-20T00:00:00Z`.
- **Channels** (required): for example `testing`, `stable`, or both. Do not rely on configuration
  defaults when the audience matters.
- **Optional targeting**: tags, startup display, platforms, `minAppVersion`, and `maxAppVersion`.

Use `--startup` or `startup: true` only when the announcement should interrupt users at startup.
Keep release-specific `appVersion` behavior out of standalone announcements unless explicitly
requested.

## Shared writing rules

- Write for users, not developers. Explain what is happening, when it matters, and any action the
  reader should take. Avoid package names, implementation details, PR numbers, and infra jargon.
- Make the summary useful on its own; it appears in announcement lists and may be used as a
  fallback when a body cannot be loaded.
- Keep en/zh equivalent in meaning, section order, links, dates, and calls to action. Translate for
  Chinese players rather than word-by-word, and use established EVE terminology.
- Verify dates, availability, links, and requested user actions against reliable source material.
  Never invent operational facts.
- Keep the body concise and scannable. Do not append raw commit logs or a changelog section.

## Mode 1: checked-in/persisted announcement

### Layout

Create exactly these source files:

```text
docs/announcements/<id>/
├── spec.yaml
├── en.md
└── zh.md
```

If the directory or any of these files already exists, inspect it and ask before overwriting user
work. The `id` in `spec.yaml` must exactly match the directory name.

Example `spec.yaml`:

```yaml
id: planned-data-maintenance-2026-11
publishedAt: '2026-11-20T00:00:00Z'
tags:
  - announcement
  - maintenance
startup: false
channels:
  - stable
  - testing
```

Add `platforms`, `minAppVersion`, or `maxAppVersion` only when needed. Do not add unknown fields:
metadata validation rejects them.

### Locale documents

`bootstrap/docs/document_parser.py` derives metadata from each Markdown file:

- The **H1** becomes the title and is removed from the stored body.
- The **first plain paragraph after the H1** becomes the summary.
- That paragraph and all following content become the body.

Therefore each locale file needs exactly one H1 followed immediately by an informative plain
paragraph. A heading, list, or code block is not a usable summary paragraph.

Example `en.md`:

```markdown
# Planned Data Maintenance

Game data updates will pause on November 21 while maintenance is performed.

Installed game data remains available. No action is required; updates resume automatically after
maintenance is complete.
```

Example `zh.md`:

```markdown
# 游戏数据维护通知

11 月 21 日维护期间，游戏数据更新将暂停。

已安装的游戏数据仍可正常使用。你无需进行任何操作；维护完成后，更新将自动恢复。
```

Do not repeat the H1 in the body or add a second title heading.

### Validation

Run:

```sh
./x build docs
```

This parses both locales, validates metadata and IDs, and regenerates bundled assets. Do not manually
edit anything under `apps/eve-fit-assistant/assets/content/announcements/generated/`.
Run `./x build site-manual` as an additional check when the change also needs the generated manual
site content.

Only the source entry under `docs/announcements/<id>/` is the authored, persisted announcement.

## Mode 2: pure-remote announcement

### Workspace and authoring files

Use `./x remote announce`; do not create an entry under `docs/announcements/` and do not manually
edit remote JSON or content-addressed document files.

The default workspace is `cache/announce/`:

```text
cache/announce/
├── remote/        # Last-synced remote state
├── staging.json   # Delta overlay managed by the CLI
└── documents/     # Content-addressed bodies managed by the CLI
```

The workspace is gitignored. If body files are useful for authoring, put temporary drafts under
`cache/announce/drafts/<id>/en.md` and `zh.md`, not in checked-in documentation.

Unlike persisted locale documents, `remote announce add` does **not** parse a title or summary out
of body files. Supply `--en-title`, `--en-summary`, `--zh-title`, and `--zh-summary` separately.
Write remote body drafts without an H1 because the app already displays the localization title.
Do not pass persisted `en.md`/`zh.md` files directly without first removing their H1.

Example body-only `en.md` draft:

```markdown
Game data updates will pause on November 21 while maintenance is performed.

Installed game data remains available. No action is required; updates resume automatically after
maintenance is complete.
```

Use the corresponding Chinese body from the persisted example above, also without its H1.

### Stage and validate

Select the target with the user: `mock` for the local remote mock or `s3` for configured remote
storage. The examples use `mock`; do not silently substitute a production target.

```sh
./x remote announce sync --target mock

./x remote announce add \
  --id planned-data-maintenance-2026-11 \
  --en-title "Planned Data Maintenance" \
  --en-summary "Game data updates will pause on November 21 while maintenance is performed." \
  --en-body-file cache/announce/drafts/planned-data-maintenance-2026-11/en.md \
  --zh-title "游戏数据维护通知" \
  --zh-summary "11 月 21 日维护期间，游戏数据更新将暂停。" \
  --zh-body-file cache/announce/drafts/planned-data-maintenance-2026-11/zh.md \
  --published-at "2026-11-20T00:00:00Z" \
  --tags "announcement,maintenance" \
  --channels "stable,testing"

./x remote announce status
./x remote announce publish --target mock --dry-run
```

Add `--startup` only when requested, and add `--platforms`, `--min-app-version`, or
`--max-app-version` only for intentional targeting. `status` exits nonzero when it finds pending
differences; inspect the reported diff rather than treating that exit code alone as a failure.

- `sync` downloads the current remote state.
- `add` writes only the local staging overlay and content-addressed bodies.
- `status` shows the effective remote diff.
- `publish --dry-run` performs the normal sync, assembly, and preflight checks without uploading.

If `sync` reports that the remote has no announcement catalog, stop and ask the user how to proceed.
Do not initialize or overwrite remote state yourself. If the ID already exists, do not replace it
with `add`; ask whether an edit was intended.

### Publishing boundary

Never run the real `./x remote announce publish` command: it uploads content, changes remote state,
and clears the local staging overlay on success. Never run `remote announce init`, especially with
`--force`.

After a successful dry run, leave the entry staged and give the user the publication command with
the confirmed target:

```sh
./x remote announce publish --target <mock-or-s3>
```

Report clearly that the announcement is **staged and dry-run validated, but not published**.

## Final checklist

- The requested delivery mode was followed, with no files from the other mode created.
- The ID is valid, unique, and consistent across metadata and commands.
- English and Chinese titles, summaries, bodies, links, dates, and calls to action agree.
- Publication time, channels, startup behavior, and optional targeting match the request.
- Persisted entries pass `./x build docs`; generated assets were not hand-edited.
- Pure-remote entries show the intended `status` diff and pass `publish --dry-run`; no checked-in
  announcement source was created and no real publication was performed.
