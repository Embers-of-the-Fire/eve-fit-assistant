# efa_fit

Scope: shared fit-format logic exposed as `package:efa_fit/efa_fit.dart`.

The package provides:

- EFA(n) native payload codecs: versioned JSON envelope → gzip → base64/base64url with an
  `EFA<n>:` prefix, size caps, and `EfaFitFormatException`;
- EFT-compatible text import/export through `parseEft`/`formatEft` over the neutral `EftFit`
  model, with injected `EftTypeResolver`/`EftTypeNameLookup` name and slot resolution;
- fit-link construction/parsing through `buildFitLinkShareUrl`, `parseFitLinkUri`, and
  `parseFitLinkBootUri`;
- `FitSnapshot` construction and protobuf wire encoding.

The app owns the `FitStorage` model and maps it to/from these formats. Keep this package
usable outside the app and avoid adding app-storage dependencies.

Validation:

```sh
melos run pkg:test
```

See `README.md` in this directory for snapshot invariants and examples.
