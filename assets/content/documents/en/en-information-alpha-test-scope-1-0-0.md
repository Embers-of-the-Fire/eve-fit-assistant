---
id: information-alpha-test-scope-1-0-0
---

# Alpha tester guide

This note explains what the current alpha build is ready for, where the main limits still are, and how to recover when data context gets out of sync.

## What to focus on

- Import or install a data bundle and switch bundles intentionally.
- Create fits, inspect stats, and export or share fits.
- Exercise advanced fitting that remains in alpha scope: charges, fighters, and subsystems.

## Current limits

- The Workspace Updates feed mixes announcements, information notes, and version changelogs; use the badge on each card to tell them apart.
- Only one bundle is active at a time. Fits saved against another bundle stay readable but become read-only until you switch back or re-import the required bundle.
- Dynamic item conversion stays out of alpha scope. Existing dynamic items can still be opened and reverted.
- Native text import accepts `EFA:` and `EFA1:` payloads. Newer explicit prefixes are rejected until that payload version is supported.

## Recovery hints

- If a fit becomes read-only after changing bundles, switch back to its saved bundle from Bundle Manager when available.
- If the saved bundle is missing, import that bundle again before editing the fit.
- If you want to move a fit onto the current bundle on purpose, export it, review the target data set, and import it again as a new copy.
