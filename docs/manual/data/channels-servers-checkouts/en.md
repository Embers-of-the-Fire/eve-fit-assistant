---
title: Channels, Servers & Checkouts
summary: How game data is organized — channels, servers, snapshots, and your local data versions.
---

# Channels, Servers & Checkouts

EVE Fit Assistant does not bundle game data in the app itself. Instead, it downloads data from a remote **channel** (for example, `testing`). If you just installed the app, you picked one during [first-run setup](efa://manual/getting-started/first-run-setup).

Each channel contains one or more **servers** (TQ/SISI-style environments). Every server publishes **generations** — immutable snapshots of the full game data set (ships, items, skills, icons) at a point in time.

On your device, a downloaded snapshot becomes a **checkout** — a local data version. You can keep several checkouts side by side, but exactly one is **active**: it provides all ship, item, and skill data used by the fitter.

You can inspect the channel and its servers under Settings → Data → Channel Metadata, and manage your local checkouts under Settings → Data → Checkouts — including switching which one is active.

- Channel: the remote source you sync from.
- Server: a game environment inside a channel.
- Snapshot: one published data generation on a server.
- Checkout: a snapshot downloaded to your device; the active one powers the app.
