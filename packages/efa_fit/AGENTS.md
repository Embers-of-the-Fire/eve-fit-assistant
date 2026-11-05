# efa_fit

Scope: shared fit-format logic exposed as `package:efa_fit/efa_fit.dart` (EFA payload
codecs, EFT import/export, fit-link construction/parsing, `FitSnapshot` construction and
protobuf encoding).

- Keep this package usable outside the app and avoid adding app-storage dependencies; the
  app owns the `FitStorage` model and maps it to/from these formats.

## Docs

- Snapshot invariants and examples: `README.md` in this directory.
- Fit links and sharing: [docs/dev/app-links.md](../../docs/dev/app-links.md)
- Validation: `melos run pkg:test`.
