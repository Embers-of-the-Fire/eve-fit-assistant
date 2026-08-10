---
title: Checkout Management
summary: Manage your local data versions — activate, update, inspect, delete, and create checkouts.
---

# Checkout Management

A [checkout](efa://manual/data/channels-servers-checkouts) is a data snapshot downloaded to your device. The checkout management page lists all local checkouts and lets you activate, update, inspect, delete, and create them. Get there via Settings → Data → Checkouts, or from the "Datasource management" tile on the [Storage Management](efa://manual/pages/data/storage) page.

When there are no checkouts, the page shows an empty-state hint.

## Checkout Cards

Each checkout is one card, from left to right:

- **Active indicator** — a circular status control. The active checkout shows a checkmark filled with the theme color; inactive checkouts show a hollow circle — tap it to activate that checkout (with confirmation). The active checkout provides all ship, item, and skill data used by the fitter.
- **Name** — the checkout's display name.
- **Channel** — a chip with the checkout's channel.
- **Created time** — when the checkout was recorded.

The action buttons on the right side of the card:

- **Update** — checks for and applies data updates for this checkout, with an update progress dialog. See [Updating Data](efa://manual/data/updating-data).
- **History** — opens the [Checkout History](efa://manual/pages/data/checkout-history) page.
- **Details** — opens a bottom sheet with the channel, server ID, snapshot hash, created time, file count, and total size, plus the downloaded and on-demand counts and sizes; it also offers a direct link to the history page.
- **Delete** — requires confirmation; deleting the active checkout asks for extra confirmation. The only checkout cannot be deleted and its delete button is disabled.

## Manage Data (Create Checkout)

The **Manage Data** floating button at the bottom opens the create-checkout sheet:

- If the current channel has no generation data yet, the sheet asks you to sync first — tap **Sync Now** to fetch the channel's generation metadata.
- Choose a server from the list: each row shows the server name, snapshot hash, server ID, and game build/version. Selecting one loads the snapshot's metadata from the remote — author, description, resource count, created time, region, sync status, and branch.
- Once the metadata is loaded, the bottom **Confirm** button shows the resource count. Tapping it opens a progress dialog that walks through: fetching the index → downloading (with a progress bar) → finalizing. On completion the new checkout becomes the active checkout automatically; if some files failed to download, a "partial" state is shown and the missing files can be re-fetched later via Verify Integrity, then Repair when verification reports missing files on the [Storage Management](efa://manual/pages/data/storage) page; a fatal error shows a failed state.

The active checkout decides which data version the app uses — see [Channels, Servers & Checkouts](efa://manual/data/channels-servers-checkouts) for background.