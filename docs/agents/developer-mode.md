# Developer Mode

The app's `AppSetting` model (`lib/storage/setting/setting.dart`) includes a `developerMode`
boolean field defaulting to `false`. It is intentionally not exposed as a normal settings
toggle.

## Access

On **Settings → Version**, tap the **App Version** value in the version information table
five times within two seconds. A confirmation dialog using
`developerModeEnableConfirmTitle` and `developerModeEnableConfirmDescription` appears;
confirming sets `developerMode` to `true` through `appSettingServiceProvider`. Once enabled,
a **Developer Settings** card appears on the Version page.

## Entry Points

- Version page → Developer Settings (`/setting/developer-settings`): debug-log toggle,
  remote-content settings visibility, account API endpoint override (production or the
  Cloudflare-Access-protected preview origin, with a service-token entry holding the
  `CF-Access-Client-Id`/`CF-Access-Client-Secret` credentials), open remote
  content settings, collect logs, clear cache, and a shortcut to Developer Tools.
- Developer Settings → Developer Tools (`/setting/developer-tools`): channel overview,
  restart init, trigger feedback, and reset all storage.

## Providers

- `developerModeProvider` — reactive read through `ref.watch(developerModeProvider)`.
- `appSettingServiceProvider.select((s) => s.developerMode)` — fine-grained reactive read.
- `ref.read(appSettingServiceProvider).developerMode` — imperative read inside callbacks.

## Localization Rule

UI widgets gated behind `developerMode` (visible only when developer mode is on) **must use
hardcoded English**. Do not add ARB entries or call `context.l10n` for developer-only UI. Only
the enable-confirmation dialog and always-visible Version page elements use localization.
