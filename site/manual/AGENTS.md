# Manual Site

Scope: the Astro-based manual site in `site/manual/` with its own pnpm workspace.

## Hard Constraints

- Invoke the local Astro CLI through pnpm from `site/manual/`: start the dev server in
  background mode with `pnpm astro dev --background`; manage it with `pnpm astro dev stop`,
  `pnpm astro dev status`, and `pnpm astro dev logs`. A bare `astro` command requires a
  global install and can fail in a clean checkout.

## Docs

- Astro documentation: https://docs.astro.build (routing, components, content collections,
  styling, internationalization).
- Site-wide rules: [AGENTS.md](../AGENTS.md)
