---
name: fit-analysis
description: Analyze the attached fit — headline stats, capacitor, tank, damage, weaknesses, and fitting-rule violations
---

# Fit analysis

Use this skill when the user asks how good their fit is, what its weaknesses
are, or why a number looks the way it does. Analysis never modifies the fit;
when the user wants changes, switch to the `fit-edit` skill.

## Procedure

1. `get_current_fit` to see what is actually fitted (hull, modules, drones,
   implants). Pass `include_skills: true` only when skill levels matter for
   the question.
2. `get_fit_stats` for the headline numbers.
3. `validate_fit` for fitting-rule violations (CPU/powergrid overload, slot
   mismatches, missing charges, ...).
4. Drill down with `get_item` / `get_attr` only for the specific items or
   attributes you need to explain; `get_attr` shows the modifier breakdown
   behind a number.

## Reading the stats

- Capacitor: compare peak recharge against peak load. A negative delta with
  no depletion, or a huge depletion time, means the fit is cap-stable; a
  short depletion time means it cannot run its active modules for long.
- Defense: check EHP per layer and the effective resists; a resist hole (one
  damage type far below the others) is the most common weakness.
- Damage: DPS without reload is the sustained number; include drone/fighter
  DPS when judging the total.
- Fitting resources: free CPU and powergrid show upgrade headroom; a fit
  with none free cannot take bigger modules.
- Mobility: velocity and align time gate escapes and repositioning.

## Output contract

- Start with a one-paragraph summary, then list issues by severity
  (validation violations first), then concrete suggestions.
- Ground every claim in tool output; quote the numbers you rely on.
- Do not apply changes here — present suggestions and let the user decide.
