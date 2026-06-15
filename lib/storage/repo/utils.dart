/// Shared utilities for the repo storage module.
///
/// This file is safe for import by any module that needs repo-level helpers,
/// including migration action code and fit/character persistence.
library;

import "dart:convert";
import "dart:io";

/// Writes [json] to [target] atomically via a temporary file + rename.
///
/// The payload is first serialized with [jsonEncode] and written to a `.tmp`
/// sibling file.  Once the write completes successfully the temp file is
/// atomically renamed over the original target.  If the write is interrupted
/// the original file is left untouched.
///
/// Throws on any I/O or encoding error.
Future<void> atomicWriteJson(File target, Map<String, dynamic> json) async {
  final tmp = File("${target.path}.tmp");
  await tmp.writeAsString(jsonEncode(json));
  await tmp.rename(target.path);
}

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
