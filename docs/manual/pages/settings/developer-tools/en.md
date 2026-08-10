---
title: Developer Tools
summary: Developer-only utilities including channel overview, restart initialization, trigger feedback, and a full storage reset.
---

# Developer Tools

The Developer Tools page (Developer Settings → Developer Tools) is accessible only while [Developer Mode](efa://manual/settings/developer-mode) is enabled; visiting it without developer mode redirects back to the home screen. It is developer-facing and English-only. The page offers:

- **Channel Overview** — opens the remote channel metadata and sync status page. See [Channel Overview](efa://manual/pages/data/channel-overview).
- **Restart Initialization** — resets the welcome state and re-runs the app initialization flow.
- **Trigger Feedback Dialog** — resets the feedback state and shows the feedback prompt immediately.
- **Reset All Storage** — deletes all local data and returns to the first-run setup flow.

> **Warning:** **Reset All Storage** permanently deletes every setting, fit, character, checkout, cached remote data, and log — there is no undo. On native platforms it wipes the app directories and restarts the app; on the web it clears the browser data and reloads the page. For everyday cache and data cleanup, use [Storage Management](efa://manual/pages/data/storage).

To attach logs to a report, open **Collect Logs** from [Developer Settings](efa://manual/pages/settings/developer-settings). See [Developer Mode](efa://manual/settings/developer-mode) for how to enable it.