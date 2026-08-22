# App Links And Fit Sharing

Fit deep links use the custom URI `efa://fit/raw?payload=...` and HTTPS links. The canonical
HTTPS host/path is `https://platform.efa-tech.dev/share/fit/raw`. Legacy hosts
`share.platform.efa-tech.dev`, `app.efa-tech.dev`, and `app-preview.efa-tech.dev` use
`/fit/raw`.

## App Implementation

The app-side feature lives in `apps/eve-fit-assistant/lib/features/fit_link/`:

- Payload codec and URI grammar come from `package:efa_fit/efa_fit.dart`: base64url+gzip over
  the versioned envelope produced by `encodeNativeFitPayload` in
  `lib/storage/fit/persistence.dart`.
- `importer.dart` imports through `FitManager.importFit`.
- `share_link.dart` builds share URLs for the export dialog's Copy link action.
- `boot_probe*.dart` is the web boot probe and scrubs the payload from the address bar.
- `native_intake.dart` receives OS links through `app_links`.
- `intake_gate.dart` is wired in `main.dart` with the other gates; it awaits repository
  readiness, imports the fit, then pushes `FitRoute`.

Web keeps the hash URL strategy. `web/_redirects` serves the SPA at `/fit/*`, and the boot
probe reads `Uri.base`.

## Platform Registration

- Android intent filters, including the custom scheme and one autoVerify App Links filter per
  host, are in `apps/eve-fit-assistant/android/app/src/main/AndroidManifest.xml`.
- Windows registers `efa://` per user in `distro/windows/installer/Package.wxs`.
- Linux declares `x-scheme-handler/efa` in `distro/linux/appimage/efa.desktop` on a
  best-effort basis.

`assetlinks.json` is rendered from `site/platform/assetlinks.template.json` by
`site/platform/render_assetlinks.py` (stdlib-only, reading `APP_KEY_SHA256`). `x build web`
renders it for the app hosts; `site/platform/build.sh` renders it into `public/.well-known/`
so the platform Worker serves it on both `platform.efa-tech.dev` and
`share.platform.efa-tech.dev`.

## Share Landing Page

The share landing page is part of `site/platform/` at `/share/fit/raw`. It consists of the SSR
route `src/pages/share/fit/raw.astro` plus the `FitShareLanding` Svelte island. The route is
kept on-demand rather than prerendered so response headers apply. It is marked `no-store`,
uses `Referrer-Policy: no-referrer`, and sends `frame-ancestors 'none'`.

The island never decodes the payload. It validates only the `EFA2:` envelope shape and then
forwards the payload to `efa://fit/raw` or the web apps' `/fit/raw` route.

The legacy share host remains attached to the same Worker solely to keep serving
`/.well-known/assetlinks.json` for App Links verification by older app versions. An
account-level Cloudflare Bulk Redirect managed outside this repository permanently redirects
`share.platform.efa-tech.dev/fit/raw` to `https://platform.efa-tech.dev/share/fit/raw` while
preserving the query string.
