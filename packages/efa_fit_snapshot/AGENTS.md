# efa_fit_snapshot

Scope: read-only, localization-aware Flutter display of `FitSnapshot` protobuf data.

- Consumers render snapshot data verbatim; producers resolve names, icons, layout, and
  statistics before creating the snapshot.
- Keep this package display-focused; fit editing and persistence belong elsewhere.
- Follow @docs/agents/style and @docs/agents/color for UI work.
- Use the package's generated localization flow declared in `pubspec.yaml` when changing
  user-facing strings.

Validation: run the relevant Dart formatter/analyzer and package tests when present.
