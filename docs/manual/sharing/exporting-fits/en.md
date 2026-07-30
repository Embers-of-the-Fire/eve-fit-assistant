---
title: Exporting Fits
summary: Copy or share a fit as text using the export dialog.
---

# Exporting Fits

Turn a saved fit into text you can paste anywhere.

Open the export dialog from a fit, choose a format, then tap **Copy** to place the text on the clipboard or **Share** to send it through the system share sheet.

Two formats are available:

- **Native format** — a compact `EFA2:` string that preserves the entire fit, including mutated (dynamic) items. Use this when sharing with other EVE Fit Assistant users; they can paste it straight into the [import dialog](efa://manual/sharing/importing-fits).
- **EFT format** — the classic `[Ship Name, Fit Name]` text layout using English type names, understood by the EVE client and most third-party tools.

EFT export is lossy: details the format cannot express are dropped, and the dialog shows a warning when this format is selected. Prefer the native format whenever both sides use this app.

See also [Creating Your First Fit](efa://manual/getting-started/create-first-fit).
