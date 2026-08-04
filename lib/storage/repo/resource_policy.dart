import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:flutter/foundation.dart";

/// The per-snapshot resource list format version that introduced the
/// per-entry download policy (NON_FORCE resources are fetched lazily on
/// first access instead of ahead of time).
const int kPolicyAwareResourceIndexFormatVersion = 2;

/// Parses a [ResourceIndex] from wire bytes and validates it for the current
/// platform (see [validateResourceIndexForPlatform]).
ResourceIndex decodeResourceIndex(Uint8List bytes) {
  final index = ResourceIndex.fromBuffer(bytes);
  validateResourceIndexForPlatform(index);
  return index;
}

/// Validates a parsed [index] for the current platform.
///
/// The web platform has no legacy installs and depends on lazy downloading,
/// so it only accepts the policy-aware format and rejects any index that
/// predates it. Native platforms stay backward-compatible and accept every
/// format.
///
/// Throws [UnsupportedResourceIndexError] when the index is not supported on
/// the current platform. The error is an [Error] (not an [Exception]) on
/// purpose: read paths that swallow parse exceptions must surface it.
void validateResourceIndexForPlatform(ResourceIndex index) {
  if (kIsWeb && index.formatVersion < kPolicyAwareResourceIndexFormatVersion) {
    throw UnsupportedResourceIndexError(formatVersion: index.formatVersion);
  }
}

/// Whether [entry] must be downloaded ahead of time (provisioning, updates).
///
/// Indexes that predate the policy-aware format carry no download policy;
/// every entry is force-downloaded (legacy behavior). In the policy-aware
/// format the entry's `download_policy` decides — absent means NON_FORCE,
/// i.e. the resource is fetched lazily on first access.
bool shouldEagerDownload(ResourceIndex index, ResourceIndex_Entry entry) =>
    index.formatVersion < kPolicyAwareResourceIndexFormatVersion ||
    entry.downloadPolicy == ResourceIndex_DownloadPolicy.FORCE;

/// A [ResourceIndex] whose per-snapshot format is not supported on the
/// current platform (web requires the policy-aware format).
class UnsupportedResourceIndexError extends Error {
  UnsupportedResourceIndexError({required this.formatVersion});

  /// The `format_version` carried by the rejected index.
  final int formatVersion;

  @override
  String toString() =>
      "UnsupportedResourceIndexError: resource index format_version $formatVersion "
      "predates the policy-aware format "
      "($kPolicyAwareResourceIndexFormatVersion) required on web";
}
