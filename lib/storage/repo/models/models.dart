/// Barrel export for all repo data models.
///
/// | Model | Spec § | Description |
/// |-------|--------|-------------|
/// | ChannelRegistry | §3.9 | Client channel registry (channels.json) |
/// | ChannelHeadMeta | §3.8 | Client channel head metadata |
/// | CheckoutRegistry | §3.10 | Client checkout registry (checkouts.json) |
/// | CheckoutMeta | §3.11 | Individual checkout metadata |
/// | ResourceSnapshotMeta | §3.2 | Resource snapshot metadata JSON |
/// | ReleaseSnapshotMeta | §3.3 | Release snapshot metadata JSON |
/// | AnnouncementSnapshotMeta | §3.4 | Announcement snapshot metadata JSON |
/// | GenerationMeta | §3.5 | Generation metadata JSON |
/// | ServerMeta | — | Server metadata (from ServerIndex protobuf) |
/// | BlobIdent | §5 | URI-based blob identification with ident_hash |
/// | CheckoutRef | — | Lightweight reference to a checkout used by fit/character records |
/// | Diff + DiffAdd + DiffDelete + DiffModify | — | On-demand diff between resource index snapshots |
/// | CompatibilityCheck / CheckoutResolution | — | Compatibility check result and checkout resolution strategies |
/// | MissingFiles | — | Verification result listing missing or hash-mismatched asset files |
/// | GameMetadata / VersionRange / AssetFile | — | Shared leaf types reused across multiple models |
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
export "server_meta.dart";
export "shared.dart";
export "snapshot_meta.dart";
