---
title: Storage Management
summary: View data usage, delete unused checkouts, and reclaim disk space.
---

# Storage Management

Game data files are shared between checkouts, so keeping several data versions usually costs less space than you might expect. Settings → Data → Storage shows the total size and file count of everything your installed checkouts use.

To free up space you can:

- **Delete unused checkouts** — remove old data versions you no longer need from Settings → Data → Checkouts. Files still used by other checkouts are kept.
- **Prune** — the prune action in Settings → Data → Storage scans the local data store and deletes orphaned files that no checkout references anymore.
- **Clear all storage** — wipes all downloaded data and the HTTP cache. The app will need to re-download data on the next sync, so only use this as a last resort when data seems corrupted.

Pruning and deleting checkouts never touch your fits, characters, or settings — those are stored separately from game data.
