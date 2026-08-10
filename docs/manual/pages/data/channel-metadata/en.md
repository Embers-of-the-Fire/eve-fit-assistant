---
title: Channel Metadata
summary: Inspect metadata for channels, servers, generation resources, and app releases.
---

# Channel Metadata

The channel metadata page shows the metadata of the current data channel — its channel, servers, generation resources, and app release catalog. Get there via Settings → Data → Channel Metadata.

The page is organized into four tabs: **Overview**, **Servers**, **Resources**, and **Releases**. When no channel data exists locally, the page shows a "no data" message. If the app is configured with more than one channel, a **Switch channel** button (swap icon) appears in the top bar to view another channel's metadata.

## Overview

- **Active channel** — the channel you are viewing.
- **Generation** — the local generation hash (truncated).
- **Synced** — when the channel head metadata was last synced.
- **Label** — the channel label (with its language code).
- **Channels** — the names of all available channels.

If the channel has never synced, a "not synced" note is shown.

## Servers

Lists the servers in the channel. Each row shows the server ID, name, game build and version, plus region, sync status, and branch when present. Servers are the individual game environments (TQ/SISI-style) inside the channel.

## Resources

Lists the generation resources: each row shows `serverId → snapshot hash` (truncated), with the total entry count below. Each entry maps a server to the resource snapshot it publishes in that generation.

## Releases

Shows the release pointer hash. Tap **Load release index** to fetch the app release catalog from the remote; once loaded it shows the release version and the Android artifact identifiers (General, Armv7, Arm64, x64), and offers a **reload** action. When the channel has no release data or nothing is synced, the page indicates so.

For background on channels, servers, and generations, see [Channels, Servers & Checkouts](efa://manual/data/channels-servers-checkouts).