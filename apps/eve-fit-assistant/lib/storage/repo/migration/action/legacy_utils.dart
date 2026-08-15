/// Legacy utilities for migration action code.
///
/// These helpers support the migration from v1/v2 formats and should not be
/// used outside the migration layer.
library;

/// Extracts the server identifier from a legacy v1 `bundleId` string.
///
/// The bundle ID format is `server-<id>-<version>-<build>`. This function
/// returns the `<id>` portion (e.g. `"tq"` from `"server-tq-21.06-1234567"`).
///
/// Returns an empty string when the bundle ID cannot be parsed.
String serverIdFromBundleId(String bundleId) {
  final segments = bundleId.split("-");
  if (segments.length >= 3) {
    return segments.sublist(0, segments.length - 2).join("-");
  }
  return "";
}
