---
name: fit-create
description: Create a new fit for a ship hull from scratch — requirements, hull resolution, module selection, validation
---

# Creating a fit

Use this skill when the user wants a brand-new fit. For changing an existing
fit, use the `fit-edit` skill instead.

## Procedure

1. Nail down the requirements before creating anything: ship hull, purpose
   (PvE/PvP, and what kind), and budget or preferred item tier. Ask the user
   when these are missing and cannot be inferred from the request.
2. Resolve the hull with `search_items` (kind "ship"), then call
   `create_fit` with the hull's type id. The new fit is saved and becomes
   the attached fit.
3. Build the fit in this order, resolving every item name with
   `search_items` (pass `kind` whenever the item kind is known) and adding
   items with `apply_fit_edit`:
   - High slots: weapons matching the hull's bonuses, with charges.
   - Mid slots: a propulsion module, then tank or utility.
   - Low slots: damage and tank modules.
   - Rigs: patch the fit's biggest weakness.
   - Drones (and fighters on carriers): match the hull's bandwidth.
   Prefer well-known T1/meta/T2 items unless the user asked for something
   specific.
4. Run `validate_fit` and `get_fit_stats`, then iterate: fix violations,
   keep free CPU and powergrid at or above zero, and sanity-check capacitor
   and tank against the stated purpose (see the `fit-analysis` skill for how
   to read the numbers).
5. Report the final fit: what each slot group does, the headline stats, and
   any trade-offs you accepted.

## Notes

- `apply_fit_edit` applies and persists immediately — there is no draft
  stage. Read the returned `rejected` list after every call and fix or
  explain every rejection.
- Empty slots are fine during construction; only the final result must
  validate.
