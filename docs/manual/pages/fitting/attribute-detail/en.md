---
title: Attribute Detail
summary: The base and current value of a single attribute, plus every effect that contributes to the current value.
---

# Attribute Detail

The attribute detail page shows everything about a single attribute. Open it by long-pressing an attribute on the [Item Detail](efa://manual/pages/fitting/item-detail) page's Attributes tab.

## Attribute Overview

The overview runs top to bottom:

- **Item type** — the item this attribute belongs to.
- **Description** — the attribute's official description, when one exists.
- **Base value** — the value from the item's static data.
- **Current value** — when opened from a fit, the computed current value after skills, modules, implants, boosters, and everything else, tinted by how it compares to the base (green for an improvement, red for a cut).
- **Delta** — the difference between the current and base values, when the unit can be converted.

## Effect Chain

When the attribute comes from an item in a fit, the effect chain lists every source that contributes to the current value, one per row:

- **Source** — where the effect comes from (the ship, a specific module, an implant, a booster, a skill, a charge, and so on).
- **Effect detail** — the effect's category, its operator (multiplication, division, percentage bonus, direct assignment, and so on), and the source attribute.
- **Value stages** — expand a row to see the original value, the transformed value, and the final value after stacking penalties; sources subject to stacking penalties are marked with a **Penalty** tag plus a hint about the rule.

Each source's arithmetic and resulting change is tinted to show whether it is favorable or not. For what these numbers mean on the fit, see [Attributes and Statistics](efa://manual/fitting/attributes-stats).

## Layout

Like item detail, the attribute detail page shows two tabs (**Attribute Overview** and **Effect Chain**) on narrow screens, and shows both panes side by side on wide screens.