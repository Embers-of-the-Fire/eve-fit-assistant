---
name: fit-edit
description: Modify the attached fit — add, swap, or remove modules, drones, fighters, implants, and boosters
---

# Editing a fit

Use this skill when the user wants to change the currently attached fit. If
no fit is attached, list the user's fits with `list_user_fits` and attach one
with `load_fit` (or create one with the `fit-create` skill) first.

## Procedure

1. Call `get_current_fit` to see the current layout; the slot indexes that
   `remove_*` / `set_*` ops need come from this listing.
2. Resolve every item the user names with `search_items`, passing `kind`
   when the item kind is known and `language` matching the name's language.
   For implants and boosters, take the `slot` argument from the hit's
   `slot_index` field.
3. Apply the changes with `apply_fit_edit`. Edits take effect and persist
   immediately — no confirmation step — so double-check type ids and slot
   indexes before calling.
4. Read the tool result: it reports the applied and rejected edits plus the
   fit's stats and validation after the change. Fix or explain every
   rejection, and surface any new validation issues to the user.
5. Summarize what changed and the effect on the headline stats; call
   `get_fit_stats` if you need numbers beyond the returned summary.

## Operation cheat sheet

- Add a module: `add_module` with `slot_type` + `type_id`; optional `state`
  and `charge_type_id`.
- Remove / re-state / re-charge a module: `remove_module`,
  `set_module_state`, `set_module_charge` with `slot_type` + `index` from
  `get_current_fit` (omit `charge_type_id` to unload the charge).
- Drones: `add_drone` (`state` "bay" by default, "space" to launch);
  `remove_drone` / `set_drone_state` apply to every drone of that type.
- Fighters: `add_fighter` with optional `ability` bitmask (1 = attack
  turret, 2 = missiles, 4 = attack missile, 8 = bomb; add the values to
  combine several abilities); `remove_fighter` by type.
- Implants: `set_implant` with `slot` 1-10 (replaces whatever is in that
  slot); `remove_implant` by slot. Boosters: same, with slots 1-3.

## Notes

- Swapping a module is a `remove_module` plus an `add_module` in one
  `apply_fit_edit` call; keep the indexes straight after removals.
- Never invent type ids; if `search_items` finds nothing, tell the user
  instead of guessing.
