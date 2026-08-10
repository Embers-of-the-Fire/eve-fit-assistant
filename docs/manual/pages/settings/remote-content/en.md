---
title: Remote Content
summary: Manage remote content panel visibility, enablement, and the data endpoint with its channel.
---

# Remote Content

The Remote Content settings page (Settings → Remote Content) configures the remote content data source. It is an advanced/developer setting: by default the Remote Content entry is hidden in Settings, so you must first enable [Developer Mode](efa://manual/settings/developer-mode), then open the remote content settings from Developer Settings, or turn on "Show remote content panel in settings". The page has three items:

- **Show remote content panel in settings** — controls whether the Remote Content entry appears on the Settings tab. Turning it off returns to the previous page.
- **Enable remote content** — turns remote content fetching on or off.
- **Endpoint** — shows the current origin URL and channel. Tap it to open an edit dialog where you can change the origin URL or switch the channel between **testing** and **stable**.

Changing the origin URL or channel affects where the app gets its data and updates, so be careful. See [Updating Data](efa://manual/data/updating-data) for channels and updates, and [Developer Settings](efa://manual/pages/settings/developer-settings) for the settings entry point.