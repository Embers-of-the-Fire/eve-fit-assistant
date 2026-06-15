/// Shared utilities for the repo storage module.
///
/// This file is safe for import by any module that needs repo-level helpers,
/// including migration action code and fit/character persistence.
library;

import "dart:convert";
import "dart:io";

import "package:protobuf/protobuf.dart";

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

/// Synchronous variant of [atomicWriteJson].
void atomicWriteJsonSync(File target, Map<String, dynamic> json) {
  final tmp = File("${target.path}.tmp");
  tmp
    ..writeAsStringSync(jsonEncode(json), flush: true)
    ..renameSync(target.path);
}

/// Writes a protobuf message to [path] atomically (write-to-tmp-then-rename).
void writeProtobufSync(String path, GeneratedMessage message) {
  final file = File(path);
  if (!file.parent.existsSync()) {
    file.parent.createSync(recursive: true);
  }
  final tmp = File("$path.tmp");
  tmp
    ..writeAsBytesSync(message.writeToBuffer(), flush: true)
    ..renameSync(path);
}

/// Reads a protobuf message from [path] using [fromBuffer].
///
/// Returns `null` if the file does not exist or is unreadable.
T? readProtobufSync<T extends GeneratedMessage>(
  String path,
  T Function(List<int> bytes) fromBuffer,
) {
  final file = File(path);
  if (!file.existsSync()) return null;
  try {
    return fromBuffer(file.readAsBytesSync());
  } on Exception {
    return null;
  }
}

/// Formats [dt] as an ISO 8601 timestamp string (UTC, seconds precision).
String formatTimestamp(DateTime dt) {
  final y = dt.year.toString().padLeft(4, "0");
  final mo = dt.month.toString().padLeft(2, "0");
  final d = dt.day.toString().padLeft(2, "0");
  final h = dt.hour.toString().padLeft(2, "0");
  final mi = dt.minute.toString().padLeft(2, "0");
  final s = dt.second.toString().padLeft(2, "0");
  return "$y-$mo-${d}T$h:$mi:${s}Z";
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
