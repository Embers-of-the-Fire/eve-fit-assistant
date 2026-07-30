---
title: Importing Fits
summary: Import a fit from text using the import dialog.
---

# Importing Fits

Bring a fit from text into the app with the import dialog.

Open the import dialog and paste a fit string into the text field, or tap the paste button to fill it from the clipboard. Tap import to confirm; on success the fit is saved and opened directly.

Two text formats are supported:

- **Native format** — strings starting with `EFA:` or `EFA2:`, produced by this app's [export dialog](efa://manual/sharing/exporting-fits). They preserve the full fit losslessly.
- **EFT format** — the classic text layout starting with `[Ship Name, Fit Name]`, as exported by the EVE client and many third-party tools.

In-game `fitting:` links are not supported and will be rejected.

If the text cannot be parsed, an error message appears in the dialog and nothing is imported. Common causes include empty input, an unrecognized format, an unknown item or ship name, or a ship that is unavailable in the current game data. Fix the text and try again.

New to fitting? See [Creating Your First Fit](efa://manual/getting-started/create-first-fit).
