# Fit Storage and Versioning

Saved fits are persisted as JSON files under `<documents>/fittings/`.
The fit registry is stored alongside them as `<documents>/fittings/registry.json`.

This document summarizes the current alpha-stage persistence contract,
including file layout, versioning, eager normalization, and native text import behavior.

## Concept, Choice and Suggestion

The fit persistence layer has three related payload types:

- [Fit files](#fit-files), represented in code by [`FitStorage`](../../apps/eve-fit-assistant/lib/storage/fit/schema.dart).
- [Fit registry](#fit-registry), represented in code by [`FitRegistry`](../../apps/eve-fit-assistant/lib/storage/fit/schema.dart).
- [Native text payloads](#native-text-payloads), used by the fit import/export UI.

To keep local data forward-compatible without introducing full migration machinery yet,
the app follows these principles:

1. Persisted fit files and the fit registry must use an explicit top-level `version` field.
   The encode/decode logic lives in [`lib/storage/fit/persistence.dart`](../../apps/eve-fit-assistant/lib/storage/fit/persistence.dart).
2. Runtime models such as `FitStorage` and `FitRegistry` should remain domain models.
   Version envelopes and compatibility checks should stay in the persistence layer.
3. Missing top-level `version` is treated as the legacy alpha payload shape.
   These payloads are accepted, then eagerly rewritten into the current versioned envelope.
4. Unsupported future versions must fail explicitly.
   The app should not silently guess how to read a newer payload.
5. Persistence parsing should use a dedicated error type.
   `FitPersistenceException` exists so future handlers can distinguish invalid payloads from unsupported versions.

## Dependencies and Code

### Fit Files

- `FitManager` creates and imports fits.
  New fit files are written through `encodeFitStorage(...)`.
- `FitService` loads the file for an individual fit.
  It decodes through `decodeFitStorage(...)`, prunes stale dynamic registry entries,
  and eagerly rewrites legacy unversioned payloads.
- `FitStorage` is defined in [`lib/storage/fit/schema.dart`](../../apps/eve-fit-assistant/lib/storage/fit/schema.dart).
  This is the in-memory fit model, not the on-disk version envelope.

The current on-disk fit file shape is:

```json
{
  "version": 1,
  "fit": {
    "metadata": { "fitId": "..." },
    "body": { "shipTypeId": 0 },
    "dynamicRegistry": { "dynamicItems": {} }
  }
}
```

### Fit Registry

- `FitRegistryManager` loads and stores the fit registry.
- The registry file is `<documents>/fittings/registry.json`.
- The current on-disk registry shape is:

```json
{
  "version": 1,
  "registry": {
    "fits": {}
  }
}
```

As with fit files, an unversioned registry payload is accepted as legacy alpha data,
then rewritten immediately in the versioned format.

### Native Text Payloads

- Native text import/export lives in [`lib/features/fit_io`](../../apps/eve-fit-assistant/lib/features/fit_io).
- Export currently emits the `EFA:` prefix only.
- Import accepts both the legacy `EFA:` prefix and the explicit `EFA1:` prefix.
- Explicit numeric prefixes newer than `EFA1:` are rejected as unsupported.
- The compressed payload inside `EFA:` still contains its own `version` field,
  validated through `decodeNativeFitPayload(...)`.

This separation keeps shareable text payload versioning explicit,
without tying future native text versions directly to on-disk file versions.

## Current Limits

- There is no multi-step historical migration chain yet.
  The current alpha implementation only normalizes legacy unversioned payloads into version `1` envelopes.
- Unknown future versions are rejected instead of partially decoded.
  This applies both to persisted fit payloads and to native text imports with explicit prefixes.
- Additive compatibility is only relaxed where the current JSON decoding already tolerates extra fields.

## Suggested Future Extension

When the fit schema changes after alpha,
add a new storage version in `lib/storage/fit/persistence.dart`
and implement an explicit conversion path from the previous version to the new one.
Keep that migration logic in the persistence layer rather than distributing it across UI and services.
