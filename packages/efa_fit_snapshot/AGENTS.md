# efa_fit_snapshot

Scope: read-only, localization-aware Flutter display of `FitSnapshot` protobuf data.

- Keep this package display-focused; fit editing and persistence belong elsewhere.
- Consumers render snapshot data verbatim; producers resolve names, icons, layout, and
  statistics before creating the snapshot.
- Follow [docs/dev/style.md](../../docs/dev/style.md) and [docs/dev/color.md](../../docs/dev/color.md)
  for UI work.
- Use the package's generated localization flow declared in `pubspec.yaml` when changing
  user-facing strings.

## Docs

- Validation: relevant Dart formatter/analyzer and package tests when present.
