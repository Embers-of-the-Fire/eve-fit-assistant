import "package:efa_proto/resource_index.pb.dart";
import "package:flutter/foundation.dart";

/// The per-snapshot resource list format version that introduced the
/// per-entry download policy (NON_FORCE resources are fetched lazily on
/// first access instead of ahead of time).
const int kPolicyAwareResourceIndexFormatVersion = 2;

/// The maximum per-snapshot resource list format version this client can
/// decode.
///
/// Forward versioning mechanism: decoding an index whose `format_version`
/// exceeds this bound raises [UnsupportedResourceIndexError], which the UI
/// routes to the app-update flow instead of silently degrading. The bound is
/// set above the current server format, so nothing changes today; any future
/// incompatible data change bumps the server format and gated clients refuse
/// the update in favor of an app update.
const int kMaxSupportedResourceIndexFormatVersion = 2;

/// Parses a [ResourceIndex] from wire bytes and validates it for the current
/// platform (see [validateResourceIndexForPlatform]).
///
/// Throws [UnsupportedResourceIndexError] when the index's `format_version`
/// exceeds [kMaxSupportedResourceIndexFormatVersion], on every platform.
ResourceIndex decodeResourceIndex(Uint8List bytes) {
  final index = ResourceIndex.fromBuffer(bytes);
  if (index.formatVersion > kMaxSupportedResourceIndexFormatVersion) {
    throw UnsupportedResourceIndexError(formatVersion: index.formatVersion);
  }
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

/// A [ResourceIndex] whose per-snapshot format is not supported by this
/// client — either because it exceeds [kMaxSupportedResourceIndexFormatVersion]
/// (update the app) or, on web, because it predates the policy-aware format.
class UnsupportedResourceIndexError extends Error {
  UnsupportedResourceIndexError({required this.formatVersion});

  /// The `format_version` carried by the rejected index.
  final int formatVersion;

  @override
  String toString() => formatVersion > kMaxSupportedResourceIndexFormatVersion
      ? "UnsupportedResourceIndexError: resource index format_version $formatVersion "
            "exceeds the maximum supported format "
            "($kMaxSupportedResourceIndexFormatVersion); update the app"
      : "UnsupportedResourceIndexError: resource index format_version $formatVersion "
            "predates the policy-aware format "
            "($kPolicyAwareResourceIndexFormatVersion) required on web";
}
