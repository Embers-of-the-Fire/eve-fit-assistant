---
title: Updating Data
summary: How the app detects and applies new game data releases.
---

# Updating Data

The app periodically checks your channel for newer data. When a new snapshot is available, a banner appears on the [workspace](efa://manual/getting-started/workspace) and an update entry shows up in Settings → Data.

Applying an update downloads only the files that changed — identical files already on your device are reused, so updates are usually small and fast.

Updates are atomic: the new data version only becomes visible once every file has been downloaded and verified. If a download is interrupted (network loss, app closed), nothing breaks — leftover partial files are cleaned up automatically on the next launch, and you can simply retry the update.

After the download finishes, the updated checkout becomes your active data version. Your fits and characters are not affected.

- Update banner on the workspace → tap Update to start.
- Settings → Data → Checkouts → update an individual checkout.
- Interrupted downloads: partial files are cleaned up on the next launch, then you can retry the update.
