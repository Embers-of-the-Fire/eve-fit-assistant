---
title: Channel Overview
summary: A developer-facing diagnostic page for channel, server, and generation metadata with remote refresh.
---

# Channel Overview

Channel Overview is a developer-facing diagnostic page for inspecting a channel's metadata and sync status. The page itself is English only and is not localized. It is reached through Developer Tools: first enable [Developer Mode](efa://manual/settings/developer-mode), then go to Settings → Version → Developer Settings → Developer Tools → Channel Overview.

The page is organized into sections:

- **Channel** — the active channel, generation hash, synced time, label, and all channel names. A placeholder is shown when nothing has been synced.
- **Servers** — the server catalog: server ID, name, game build and version, plus region, sync, and branch; the section title shows the server count. When no catalog exists, it prompts to run a sync or create a checkout first.
- **Generation Resources** — the generation resource list (`serverId → snapshot hash`) and the total entry count.
- **Release Info** — the release pointer hash; tap **Load Release Index** to fetch the release catalog from the remote (release version and Android artifact identifiers), with an error message if it fails to load.
- **Actions** — **Refresh from Remote** re-discovers channels and syncs the active channel's generation metadata, then refreshes the page data.

Regular users should use the [Channel Metadata](efa://manual/pages/data/channel-metadata) page to inspect channel information; this page exists for diagnostics and troubleshooting and is not meant for everyday use.