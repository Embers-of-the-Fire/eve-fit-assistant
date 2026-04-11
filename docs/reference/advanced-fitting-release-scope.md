# Advanced Fitting Release Scope

This document records which advanced fitting workflows are included in the initial tester release and which ones stay deferred until parity work is finished.

## Included in scope

- Charges on high, medium, and low slot modules remain enabled.
- Fighter fitting remains enabled, including squadron sizing resolved from the native engine and ability toggles exposed by the fighter row UI.
- Subsystem fitting remains enabled for ships that expose subsystem slots, including slot validation and slot-layout resizing after install or removal.

## Deferred from scope

- Dynamic item conversion is intentionally deferred for the initial release.
- Existing dynamic items can still be opened and reverted back to their origin type, but the UI no longer offers conversion into a dynamic item.

## Release-safety rationale

- Charges, fighters, and subsystem flows already have end-to-end UI wiring and native fit-engine support in the current workspace.
- Dynamic item support is not complete yet; the native engine still contains TODO-backed attribute handling for dynamic items, so enabling fresh conversions would risk shipping partially applied stats.

## Expected tester impact

- Testers can keep exercising advanced charge, fighter, and subsystem workflows without being pushed into unfinished mutator paths.
- Imported or previously saved fits that already contain dynamic items should remain recoverable because reverting those items is still available.
