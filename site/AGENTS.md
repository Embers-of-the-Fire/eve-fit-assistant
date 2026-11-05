# Sites

Scope: the brand homepage (`home/`), manual site (`manual/`), and platform app
(`platform/`). The homepage and platform app are members of the root pnpm workspace; the
manual site has its own pnpm workspace.

## Hard Constraints

- Use pnpm, not npm.
- Root `biome.json` governs JS/TS formatting and linting for this area.
- Follow [docs/dev/style.md](../docs/dev/style.md) and [docs/dev/color.md](../docs/dev/color.md)
  for UI work. Brand surfaces use the Brand family; workload surfaces use the Workload family.
- Use the nearest nested `AGENTS.md`: `manual/` and `platform/` have their own local rules.

## Docs

- Style and color: [docs/dev/style.md](../docs/dev/style.md), [docs/dev/color.md](../docs/dev/color.md)
- App links: [docs/dev/app-links.md](../docs/dev/app-links.md)
- Validation: run the relevant package `check` script when the package defines
  one (`home` and `platform` do; `manual` currently does not), then `pnpm biome check --fix site`.
