# Sites

Scope: the brand homepage (`home/`), manual site (`manual/`), and platform app
(`platform/`). The homepage and platform app are members of the root pnpm workspace; the
manual site has its own pnpm workspace.

## Local Rules

- Use pnpm, not npm.
- Root `biome.json` governs JS/TS formatting and linting for this area.
- Follow @docs/agents/style and @docs/agents/color for UI work. Brand surfaces use the Brand
  family; workload surfaces use the Workload family.
- Use the nearest nested `AGENTS.md`: `manual/` has its own local instructions and
  `platform/` has platform-specific architecture rules.
- Keep package scripts and `package.json` as the source of truth for local commands.

## Validation

Run the relevant package check, then Biome:

```sh
pnpm --filter efa-tech check
pnpm --filter efa-platform check
pnpm dlx biome check --fix site
```
