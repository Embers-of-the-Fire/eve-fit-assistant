---
title: Checkout History
summary: View a checkout's history and roll back to an earlier snapshot.
---

# Checkout History

The checkout history page shows the full history (reflog) of a single checkout and lets you roll back to an earlier snapshot. Get there via Settings → Data → Checkouts → tap the history button on a checkout card, or from the checkout's details sheet.

If the checkout's record no longer exists (for example, it was deleted), the page says the checkout was not found and offers a back button.

## Header

The top of the page shows:

- **Server** — the server ID the checkout belongs to.
- **Channel** — the channel the checkout belongs to.
- **Current hash** — the snapshot hash the checkout points to now (truncated).
- **Transition count** — the total number of transitions recorded in the history.

Below that it shows the checkout's game build/version, plus region, sync, and branch when present.

## History Entries

The history is listed in reverse chronological order (newest first). Each entry shows:

- **Ordinal** — the transition number (#1, #2, …).
- **Transition** — the change as `from → to` hashes (truncated). The initial transition shows a dash for its from-hash.
- **Timestamp** — when the transition happened.

Each entry carries badges: the entry whose target is the snapshot the checkout currently points to shows **Current** (green), and the initial transition shows **Initial**.

Tap an entry to expand its details: the from and to hashes, plus game build, version, author, description, resource count, and created time when the snapshot metadata is available.

## Rolling Back

Every entry that is not the current one has an **undo** button on the right. Tapping it asks for confirmation; once confirmed, the checkout reverts to the snapshot that entry points to. If the checkout is the active data version, the app immediately switches to the reverted data. Rollback is safe and reversible, and you can update again afterwards. See [Checkout History & Rollback](efa://manual/data/checkout-history-rollback).