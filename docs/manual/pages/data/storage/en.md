---
title: Storage Management
summary: View data usage, verify integrity, and run storage maintenance operations.
---

# Storage Management

The storage management page summarizes how much local game data the app holds and provides integrity checks and storage maintenance operations. Get there via Settings → Data → Storage.

## Overview

The overview card lists the data shared by all your installed [checkouts](efa://manual/data/channels-servers-checkouts):

- **File count** — the total number of index entries.
- **Total size** — the logical size of all entries combined.
- **Downloaded** — the count and size of files actually present on disk.
- **On-demand** — the count and size of files not yet downloaded, fetched lazily on first access.
- **Datasource** — the current channel name and the local generation hash (truncated).
- **Last updated** — when the channel head metadata was last synced; a channel that has never synced shows "Never synced".

When some files are not yet downloaded, an on-demand hint is shown; a cache hint explains which files are shared by which checkouts. Pull the list down to refresh — this recomputes the overview and runs one update check.

## Data Management

- **Game data (update)** — the status changes as updates are checked: tap to check all checkouts, "Checking for updates…", "Up to date", "New game data ready" (tap to update all), "Updating game data…", or failed (retryable). See [Updating Data](efa://manual/data/updating-data).
- **Datasource management** — opens [Checkout Management](efa://manual/pages/data/checkouts) to manage your local data versions.

## Storage Operations

- **Verify Integrity** — scans the local data and checks whether every file is in place. The result lists checkouts with missing files, a missing manifest, or partial downloads; when everything is fine it reports that verification passed. Verification shows progress.
- **Repair** — appears after verification finds issues. Downloads the missing files and fixes incomplete data, then reports whether everything could be repaired.
- **Prune Unreferenced** — requires confirmation. Scans the local data store, deletes orphaned files that no checkout references anymore, and reports how many were removed.
- **Force Sync Remote Storage** — forces a re-sync of the current channel's generation metadata, then shows the outcome.
- **Clear All Storage** — requires confirmation. Deletes all downloaded data and the HTTP cache, then re-initializes the app. The next sync re-downloads everything, so only use this as a last resort when data seems corrupted.

While any operation runs, a progress bar appears and the other operations are disabled. Verification, repair, and pruning never touch your fits, characters, or settings. See also [Storage Management](efa://manual/data/storage-management).