# Web App

EFA ships as an online web app in addition to the native builds. The web app
is a WebAssembly build of the same Flutter codebase (`./x build web`),
served from Cloudflare Pages.

## Sites

| Site | URL | Content |
| ------ | ----- | --------- |
| Production | <https://app.efa-tech.dev> | Cloudflare Pages project `efa-app`; deployed by real releases only. |
| Nightly preview | <https://app-preview.efa-tech.dev> | Cloudflare Pages project `efa-app-nightly`; branch previews for PRs and nightly builds of `dev`. May be unstable. |

## Deployment Pipeline

- `web-preview.yml` — PRs to `dev` that touch web bundle inputs get a branch
  preview on `efa-app-nightly`; closing the PR deletes the preview.
- `site-nightly.yml` — daily cron that rebuilds and deploys `dev` to
  `efa-app-nightly` when the bundle changed.
- `_release.yml` — real releases deploy to `efa-app` (test mode deploys to
  `efa-app-nightly` instead).

See `AGENTS.md` (CI / Release Automation) and `RELEASING.md` for the full
pipeline, required secrets, and one-time dashboard setup.

## Runtime Requirements

The web engine is built with atomics and shared memory, so the hosting origin
must be cross-origin isolated (`web/_headers` ships the COOP/COEP headers for
Cloudflare Pages). Without isolation the app boots without the native engine.
Localized names on web additionally require the SQLite web worker shipped
under `web/sqlite/`.
