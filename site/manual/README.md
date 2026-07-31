# EVE Fit Assistant Manual Site

Astro + Starlight documentation site for EVE Fit Assistant. Content is **generated at build
time** from the raw sources in the repository:

- `docs/manual/` — user manual (per-locale `en.md` / `zh.md` with `folder.yaml` ordering)
- `docs/changelog/` — release notes (`spec.yaml` + `content.en.md` / `content.zh.md`)
- `docs/announcements/` — announcements (`spec.yaml` + `en.md` / `zh.md`)

Generated output (`src/content/docs/`, `src/generated/sidebar.json`) is git-ignored.

## Commands

Run from the repository root unless noted otherwise:

| Command                        | Action                                                  |
| :----------------------------- | :------------------------------------------------------ |
| `./x build site-manual`        | Generate site content from `docs/` raw sources          |
| `pnpm --filter manual build`   | Build the production site to `site/manual/dist/`        |
| `pnpm --filter manual dev`     | Start the local dev server at `localhost:4321`          |

Always run `./x build site-manual` before `pnpm build` — the site will not build without the
generated content.
