---
title: Web App
summary: Use EFA directly in your browser — no installation needed.
---

# Web App

EFA is available as an online web app — the same fitting tool, running entirely in your browser. Nothing to install: open the site, complete the first-run setup, and start fitting.

## Sites

- **Stable** — <https://app.efa-tech.dev>: tracks released versions. Use this one for everyday fitting.
- **Nightly preview** — <https://app-preview.efa-tech.dev>: tracks the development branch. You get new features earlier, but things may break without warning.

## Browser Requirements

The web app relies on two modern browser capabilities:

- **SharedArrayBuffer** (cross-origin isolation) — required for the fitting engine to run in background workers. See [browser compatibility](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/SharedArrayBuffer#browser_compatibility).
- **OPFS** (Origin Private File System) — required for local data and storage. See [browser compatibility](https://developer.mozilla.org/en-US/docs/Web/API/File_System_API/Origin_private_file_system#browser_compatibility).

The site is tested on Chromium-based browsers (Chrome, Edge, and similar) and Firefox. **Safari may not be fully supported.**

## Storage Notes

All data — downloaded game data, fits, characters, and settings — lives in your browser's local storage (OPFS) for the site you are using:

- Clearing the site's data in your browser deletes everything stored by the app.
- The stable site and the nightly preview keep separate storage; fits created on one are not visible on the other.
- Data is not shared with native installs of EFA. To move fits between the web app and a native app, export them and import them on the other side. See [Exporting Fits](efa://manual/sharing/exporting-fits) and [Importing Fits](efa://manual/sharing/importing-fits).

Next: [First-Run Setup](efa://manual/getting-started/first-run-setup).
