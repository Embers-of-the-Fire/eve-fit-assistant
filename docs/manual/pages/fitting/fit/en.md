---
title: The Fitting Page
summary: The full fit editor — slots and modules, module states, charges, drones and fighters, the character and its implants, and the attribute panels.
---

# The Fitting Page

The fitting page is the app's core editor. It is where you view and modify every part of a fit. The title bar shows "fit name — ship name", and the body uses a responsive multi-column layout that adapts to your screen width.

You get here by tapping a fit in the [Fit List](efa://manual/pages/home/fit-list), by creating a new one in the [Creating a Fit](efa://manual/pages/fitting/create-fit) dialog, or straight from a [Deep Link](efa://manual/sharing/deep-links).

## Status Banners

Banners can appear at the top of the page for several conditions:

- **Data mismatch** — the fit was saved against data that no longer matches the active checkout; a banner offers to open the branch manager. See [Channels, Servers & Checkouts](efa://manual/data/channels-servers-checkouts).
- **Changes not saved** — a save failed and the reason is shown.
- **Stats unavailable** — the attribute engine hit an error; a **Retry** button recomputes the fit.

While loading, the page shows a skeleton or a spinner. If the fit or its ship data cannot be loaded, an error screen appears with **Retry** or **Back** actions.

## Responsive Multi-Column Layout

The page shows one to three columns depending on your screen width. Each column is a pane that contains every tab and starts on the tab at its position:

- **Phone (1 column)** — a single pane, starting on the **Equip** tab.
- **Tablet (2 columns)** — Equip and Attrib panes side by side.
- **Wide (3 columns)** — Equip, Attrib, and Drone/Fighter panes side by side.

You can switch tabs by tapping the tab bar at the top of any pane, or by swiping the pane left or right. The swipe gesture is edge-aware so it never fights with the swipe actions on slot rows.

## Tabs

### Character

Pick the [character](efa://manual/characters/assign-character-to-fit) (skill profile) this fit uses. Tap the character row at the top to open a picker with the built-in All-V, Alpha-All-V, and All-0 profiles plus any custom characters you have created.

Below the picker, the character tab has two sub-tabs:

- **Implant Slots** — up to 10 implant slots. Use the plus button to add an implant; **Apply Implant Set** (the grid icon) applies a whole set of implants in one step, grouped by set family; each installed implant can be swiped to **Set** (replace) or **Delete**. See [Implants & Boosters](efa://manual/fitting/advanced/implants-boosters).
- **Booster Slots** — the equipped boosters. Use the plus button to add one; swipe a booster to replace or delete it.

### Equip

The Equip tab lists the ship's modules grouped by slot:

- **Tactical mode** (mode-capable ships) — a special row you tap to cycle between target, speed, defense, and other modes. See [Tactical Modes](efa://manual/fitting/tactical-modes).
- **High slots** — weapons and offensive modules; the section header shows turret/launcher hardpoint counters (used/available).
- **Medium and low slots** — propulsion, electronic warfare, and shield/armor modules.
- **Rig slots** — permanent ship modifications.
- **Subsystems** (T3 cruisers) — four subsystem slots; swapping a subsystem resizes the high/medium/low slot counts to match.
- **Service slots** (structures and capital ships) — cloning, manufacturing, and other services.

Each section header offers **Clear All** for that section; the high/medium/low sections also have a **Clear Charges** button.

Each slot takes one row:

- **Empty slot** — shows the slot icon and its number; tap it to open the add-item picker, which only lists items that fit in that slot.
- **Filled slot** — the leading state icon (tap to toggle the module's state) carries the item icon with a meta-group badge; the middle shows the item name with the charge row (if any) and key values (such as weapon DPS) below; the trailing shows the slot number and an issue indicator.

**Module states:** modules cycle through **Offline**, **Online**, and **Active**, wrapping back to Offline after the highest state the module supports; modules that can be overloaded (such as weapons) also reach **Overload**. The state icon's border color reflects the state. See [Fit States](efa://manual/fitting/advanced/fit-states) and [Overloading Modules](efa://manual/fitting/advanced/overloading).

**Charges:** modules that take charges show a charge row (amount × charge name) under the item name. Swipe the row to **Set Charge** or remove the charge; the charge picker only lists charges the module accepts. See [Modules and Slots](efa://manual/fitting/modules).

**Swipe actions:** swipe a filled slot row to reveal action panes — on the leading side **Copy** (copies the module to the next empty slot), convert to or revert from a **dynamic** item (mutated modules), and **Set Charge**; on the trailing side remove the charge and **Delete**. See [Mutaplasmids & Dynamic Items](efa://manual/fitting/advanced/mutaplasmids-dynamic-items).

**Inspect:** tap (or long-press) an item row to open its [Item Detail](efa://manual/pages/fitting/item-detail) page; the charge row can be tapped to inspect the charge the same way.

### Attrib

The Attrib tab shows every number computed for the current character and tactical mode:

- **Ship info** — the ship's name; long-press to open item detail.
- **Capacitor** — capacity, peak draw, whether the fit is cap-stable (with the stable percentage), and the rate of change.
- **Weapon** — total DPS (with reload), DPS including drones/fighters, and alpha strike.
- **Resource** — CPU, power grid, rig calibration, and drone bandwidth usage bars.
- **Defense (HP)** — shield/armor/hull HP and resistances in a table, switchable to an EHP view; active and passive repair rates below; tap the settings icon to change the [Damage Profile](efa://manual/fitting/damage-profiles).
- **Misc** — velocity/warp speed, targeting range/scan resolution, max locked targets/sensor strength, align time/signature radius, and max drones/drone control range.
- **Cargo** — total mass, cargo capacity, and any special holds (fleet hangar, fuel bay, and so on).
- **Market price** (native platforms) — an estimate for the whole fit.

See [Attributes and Statistics](efa://manual/fitting/attributes-stats) for how to read these panels.

### Drone / Fighter

Ships with fighter tubes get a **Fighter** tab; all others get a **Drone** tab.

- **Drones** — add and clear buttons at the top; each drone row offers quantity controls (x1 / x5, +1 / -1, delete).
- **Fighters** — the header shows light/support/heavy fighter counts against their limits (H/L/S) plus used launcher tubes; each row toggles the abilities that fighter type supports (turret, missiles, volley, bomb) and shows the quantity against the squadron maximum.

See [Drones and Fighters](efa://manual/fitting/drones-fighters).

### Utils

The Utils tab provides:

- **Export fit** — opens the export dialog to produce EFA-format text or an image. See [Exporting Fits](efa://manual/sharing/exporting-fits).
- **Export image** — opens the [Fit Screenshot](efa://manual/pages/fitting/fit-screenshot) page.
- **Fit name and description** — tap **Edit** to rename the fit and add a note; the changes are saved with the fit.

## Issue Indicators

The issue icon on slot rows and section headers flags problems in the fit: orange for warnings (such as a missing charge), red for errors (such as an incompatible charge, too many turrets, or conflicting items). Tap the icon to see the list of issues. See [Fit Validation](efa://manual/fitting/validation).

## Working with the AI Assistant

While the fitting page is open, the fit is automatically provided to the AI chat as its attached context, so the chatbot can read and modify this fit. See [AI Hub](efa://manual/pages/ai/ai-hub).