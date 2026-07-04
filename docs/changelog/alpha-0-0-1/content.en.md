# Version Alpha 0.0.1

This release includes the changes listed below.

## Added

- A startup announcement dialog with "don't show again" persistence and a detail-link action.
- Local character skill profiles with create, clone, edit, and delete flows.
- A built-in Alpha Max skill profile, with Alpha clone limits highlighted in skill level indicators.
- Skill-group browsing and direct skill-level editing on the Character page.
- Per-fit character profile selection from the Character tab.
- A Dynamic tab in item details for base item, mutaplasmid, reset, reroll, and manual attribute edits.
- Abyssal convert/revert actions on fitting slots, plus improved charge selection, subsystem replacement, and fighter workflows.

## Improved

- Fit pages now show clearer read-only notices, recovery actions, and loading overlays when bundle data is switching, missing, or mismatched.
- Item detail attributes now use Dogma-unit-aware formatting for distance, time, percent, volume, size, sex, and other unit types.
- Item details hide unavailable current attribute values instead of presenting missing calculation output as real data.
- Bundle Manager now explains the Alpha-stage single-active-bundle scope and shows pending load state while switching bundles.
- Startup persistence repair messages now report recovered fits, bundles, selected bundle changes, and unreadable files more clearly.

## Architecture

- Bundle loading now uses safer transactional state so the previous bundle remains usable if the next load fails.
- Bundle import now supports incremental archives, deleted-file manifests, patch history, and manifest hash validation.
- Generated data now includes Alpha clone skill limits and Dogma unit ID constants for profile and unit-formatting features.
- The document system now supports startup announcement state and fixes the Alpha bug-report document `tags` metadata.