import "package:eve_fit_assistant/config/paths.dart";
import "package:path/path.dart" as p;

/// Path resolution for the EFA V2 unified storage schema.
///
/// All paths share the `resources/v2/` root. The layout follows
/// agent/schemav2/schema.md §2 (client-side).
class RepoPaths {
  const RepoPaths._();

  // ── Schema resources ────────────────────────────────────────────────────────

  static String get schemaResourcesPath => p.join(PathProvider.resourcesPath, "v2");

  static String get schemaVersionPath => p.join(schemaResourcesPath, "schema_version.json");

  // ── assets/ ─────────────────────────────────────────────────────────────────

  static String get assetsPath => p.join(schemaResourcesPath, "assets");

  /// Path to a blob in the shared content-addressed store.
  ///
  /// `identHash` is SHA-256 of the identifier URI (e.g. `resource://...`).
  /// `contentHash` is SHA-256 of the raw blob bytes.
  static String blobPath(String identHash, String contentHash) {
    if (identHash.length < 2) {
      throw ArgumentError.value(identHash, "identHash", "Must be at least 2 characters");
    }
    return p.join(assetsPath, "blobs", identHash.substring(0, 2), identHash, contentHash);
  }

  /// Directory containing all content versions for a single ident_hash.
  static String blobIdentDir(String identHash) {
    if (identHash.length < 2) {
      throw ArgumentError.value(identHash, "identHash", "Must be at least 2 characters");
    }
    return p.join(assetsPath, "blobs", identHash.substring(0, 2), identHash);
  }

  // ── assets/resources/ ───────────────────────────────────────────────────────

  /// Directory for a single resource snapshot.
  static String resourceSnapshotPath(String snapshotHash) =>
      p.join(assetsPath, "resources", snapshotHash);

  /// metadata.json for a resource snapshot.
  static String resourceSnapshotMetaPath(String snapshotHash) =>
      p.join(resourceSnapshotPath(snapshotHash), "metadata.json");

  /// resources.pb2 for a resource snapshot (ResourceIndex protobuf).
  static String resourceIndexPath(String snapshotHash) =>
      p.join(resourceSnapshotPath(snapshotHash), "resources.pb2");

  // ── announcements/ (client-side, per spec §2.3) ─────────────────────────────

  /// Root announcements directory.
  static String get announcementsRootPath => p.join(schemaResourcesPath, "announcements");

  static String announcementSnapshotPath(String snapshotHash) =>
      p.join(schemaResourcesPath, "announcements", snapshotHash);

  static String announcementSnapshotMetaPath(String snapshotHash) =>
      p.join(announcementSnapshotPath(snapshotHash), "metadata.json");

  static String announcementIndexPath(String snapshotHash) =>
      p.join(announcementSnapshotPath(snapshotHash), "announcements.pb2");

  // ── channels/ (client-side) ─────────────────────────────────────────────────

  static String get channelsPath => p.join(schemaResourcesPath, "channels");

  /// channels/channels.json — client channel registry.
  static String get channelRegistryPath => p.join(channelsPath, "channels.json");

  /// channels/{channel}/metadata.json — client channel head metadata.
  static String channelHeadMetaPath(String channelName) =>
      p.join(channelsPath, channelName, "metadata.json");

  /// channels/{channel}/server.pb2 — ServerIndex copied from generation.
  static String channelServerIndexPath(String channelName) =>
      p.join(channelsPath, channelName, "server.pb2");

  // ── checkouts/ (client-side) ────────────────────────────────────────────────

  static String get checkoutsPath => p.join(schemaResourcesPath, "checkouts");

  /// checkouts/checkouts.json — checkout registry.
  static String get checkoutRegistryPath => p.join(checkoutsPath, "checkouts.json");

  /// checkouts/{id}/metadata.json — individual checkout metadata.
  static String checkoutMetaPath(String checkoutId) =>
      p.join(checkoutsPath, checkoutId, "metadata.json");

  /// checkouts/{id}/reflog.pb2 — CheckoutReflog.
  static String checkoutReflogPath(String checkoutId) =>
      p.join(checkoutsPath, checkoutId, "reflog.pb2");
}
