/// Barrel export for all repo data models.
///
/// | Model | Spec § | Description |
/// |-------|--------|-------------|
/// | Active | 02-models § Active | The single source of truth for "what's loaded" — the active branch and checkout. |
/// | Branch | 02-models § Branch | A named line of checkouts with reflog and forward-diff chain. |
/// | CheckoutIndex | 02-models § Checkout | Index of all known checkouts keyed by hash. |
/// | CheckoutRef | 02-models § CheckoutRef | Lightweight reference to a checkout used by fit/character records. |
/// | CheckoutRefs | 02-models § CheckoutRefs | Append-only registry of installed checkout references. |
/// | AssetManifest | 02-models § AssetManifest | Per-checkout manifest mapping paths to asset hashes. |
/// | Diff + ReflogEntry | 02-models § Diff | Forward-diff representation between two checkouts. |
/// | ManifestIndex / GenerationsIndex / GenerationCatalog / ... | 02-models § RemoteCatalog | Server-side catalog and generation types used by RemoteCatalogService. |
/// | AnnouncementRecord / AnnouncementIndex | 02-models § Announcement | In-app announcement and version-update notice records. |
/// | ReleaseItemRecord | 02-models § Release | APK release metadata. |
/// | CompatibilityCheck / CheckoutResolution | 02-models § Compatibility | Compatibility check result and checkout resolution strategies. |
/// | MissingFiles | — | Verification result listing missing or hash-mismatched asset files. |
/// | GameMetadata / VersionRange / AssetFile | 02-models § Shared | Shared leaf types reused across multiple models. |
library;

export "active.dart";
export "announcement.dart";
export "asset_manifest.dart";
export "branch.dart";
export "checkout_index.dart";
export "checkout_ref.dart";
export "checkout_refs.dart";
export "compatibility.dart";
export "diff.dart";
export "missing_files.dart";
export "release.dart";
export "remote_catalog.dart";
export "shared.dart";
