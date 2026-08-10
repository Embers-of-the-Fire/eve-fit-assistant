---
title: Item Detail
summary: The full reference for a single item — classification, description, traits, fitting info, attributes, and skill requirements, plus editing dynamic items.
---

# Item Detail

The item detail page shows the complete reference for a single item — a ship, module, charge, drone, skill, and so on. You open it by tapping or long-pressing an item row on the [Fitting Page](efa://manual/pages/fitting/fit), long-pressing a ship in the ship browser, long-pressing a fit in the [Fit List](efa://manual/pages/home/fit-list), or long-pressing a skill node in the skill tree.

The page title is the item's name. The body uses a responsive multi-column layout: one column on phones with tabs to switch between sections, two columns on tablets, and three on wide screens, each column starting on the tab at its position.

## Tabs

### Info

The Info tab runs top to bottom:

- **Header card** — the item icon (with a meta-group badge), its name, and chips for the meta group and item group.
- **Classification card** — the type ID, category, group, and market group.
- **Description** — the item's official description, when one exists.
- **Traits** — ship traits, listed per-skill with their bonuses.
- **Fitting** — for ships and subsystems, the high/medium/low, rig, subsystem, and service slot counts; for modules, the slot type the item belongs to.

### Dynamic

This tab appears only when the item is a dynamic (mutated) item inside a fit. It edits the mutation:

- The top shows two chips: the **base item** and the **mutator** (mutaplasmid).
- **Reset** restores every attribute to its base value; **Reroll** randomizes all attributes within the mutator's allowed range.
- Each mutable attribute is one row: the attribute name, a value field, a min / current / max comparison, and a ratio bar showing where the current value sits in the allowed range. Type a new value and press Enter (or leave the field) to apply it; out-of-range values are clamped to the edge.

See [Mutaplasmids & Dynamic Items](efa://manual/fitting/advanced/mutaplasmids-dynamic-items).

### Attributes

The Attributes tab lists every attribute of the item with its value. When the item comes from a fit, values show the computed current values (which change with the character, tactical mode, and module states) tinted by how they compare to the base values. Long-press an attribute to open its [Attribute Detail](efa://manual/pages/fitting/attribute-detail) page.

### Skills

The Skills tab shows the skill requirements as a tree: each node lists a skill name and the required level (as five squares) and can be expanded to reveal its prerequisites. Long-press a skill node to view that skill's own details.