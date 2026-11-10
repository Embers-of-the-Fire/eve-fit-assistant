# Sites

Scope: the brand homepage (`home/`), manual site (`manual/`), and platform app
(`platform/`). The homepage and platform app are members of the root pnpm workspace; the
manual site has its own pnpm workspace.

## Hard Constraints

- Use pnpm, not npm.
- Root `biome.json` governs JS/TS formatting and linting for this area.
- Use the nearest nested `AGENTS.md`: `manual/` and `platform/` have their own local rules.

## Design

- Start at [docs/dev/style/index.md](../docs/dev/style/index.md) for UI work; the color
  authority is [docs/dev/color.md](../docs/dev/color.md). Brand surfaces use the Brand
  family; workload surfaces use the Workload family.

## Docs

- App links: [docs/dev/app-links.md](../docs/dev/app-links.md)
- Validation: run the relevant package `check` script when the package defines
  one (`home` and `platform` do; `manual` currently does not), then `pnpm biome check --fix site`.
