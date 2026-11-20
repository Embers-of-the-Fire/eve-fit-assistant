/// Barrel export for all repo data models.
///
/// | Model | Description |
/// |-------|-------------|
/// | ChannelRegistry | Client channel registry (channels.json) |
/// | ChannelHeadMeta | Client channel head metadata |
/// | CheckoutRegistry | Client checkout registry (checkouts.json) |
/// | CheckoutMeta | Individual checkout metadata |
/// | ResourceSnapshotMeta | Resource snapshot metadata JSON |
/// | ReleaseSnapshotMeta | Release snapshot metadata JSON |
/// | GenerationMeta | Generation metadata JSON |
/// | ServerMeta | Server metadata (from ServerIndex protobuf) |
/// | BlobIdent | URI-based blob identification with ident_hash |
/// | CheckoutRef | Lightweight reference to a checkout used by fit/character records |
/// | RemoteAppRelease | A newer app release discovered from the remote release index |
/// | Diff + DiffAdd + DiffDelete + DiffModify | On-demand diff between resource index snapshots |
/// | CompatibilityCheck / CheckoutResolution | Compatibility check result and checkout resolution strategies |
/// | MissingFiles | Verification result listing missing or hash-mismatched asset files |
/// | VersionRange / AssetFile | Shared leaf types reused across multiple models |
library;

export "blob_ident.dart";
export "channel_head_meta.dart";
export "channel_registry.dart";
export "checkout_meta.dart";
export "checkout_ref.dart";
export "checkout_registry.dart";
export "compatibility.dart";
export "diff.dart";
export "generation_meta.dart";
export "missing_files.dart";
export "remote_app_release.dart";
export "server_meta.dart";
export "shared.dart";
export "snapshot_meta.dart";
