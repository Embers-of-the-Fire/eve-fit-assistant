# v0.13.0 Release Notes

This release makes fit sharing smoother: when the platform has not ingested your current data version yet, you can now publish the fit computed with the server's latest data instead of hitting an error. It also fixes a phantom subsystems section in fit views and missing stats for fighter squadrons beyond the first.

## Fit Sharing

- Share fits even when the platform has not ingested your current data version yet: with your confirmation, the fit is reproduced and published with the server's latest data (stats may differ slightly; share again later to recompute it with your own data)
- Fits shared this way are marked as computed with the platform's latest data
- Sharing a fit no longer automatically opens the post page in your browser — after sharing, you can choose to view the post, copy its link, or simply dismiss the dialog

## Fixes

- Fix an empty subsystems section appearing in fit views for ships with no subsystems equipped
- Fix stats such as damage output not being calculated for fighter squadrons beyond the first
