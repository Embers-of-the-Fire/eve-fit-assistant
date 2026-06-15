import "dart:convert";
import "dart:typed_data";

import "package:crypto/crypto.dart";

/// SHA-256 hex digest and canonical path hashing utilities.
class RepoHash {
  const RepoHash._();

  /// Computes the SHA-256 hex digest of raw [bytes].
  static String hashBytes(Uint8List bytes) => sha256.convert(bytes).toString();

  /// Computes the SHA-256 hex digest of a UTF-8 encoded [string].
  static String hashString(String string) => hashBytes(utf8.encode(string));

  /// Computes the SHA-256 hex digest of raw content [bytes].
  ///
  /// Same as [hashBytes] — semantic alias for content hashing.
  static String hashContent(Uint8List bytes) => hashBytes(bytes);

  /// Normalizes [path] to POSIX form.
  ///
  /// Applies canonicalization: forward slashes, no trailing slash,
  /// no `.` or `..` segments. Returns an empty string for root-only paths.
  ///
  /// Throws [ArgumentError] when a `..` segment would escape the root,
  /// preventing path traversal.
  static String canonicalizePath(String path) {
    final segments = <String>[];
    for (final s in path.replaceAll("\\", "/").split("/")) {
      if (s.isEmpty || s == ".") continue;
      if (s == "..") {
        if (segments.isNotEmpty) {
          segments.removeLast();
        } else {
          throw ArgumentError("Path traversal not allowed: $path");
        }
        continue;
      }
      segments.add(s);
    }
    return segments.join("/");
  }

  /// Computes the SHA-256 hex digest of a canonical POSIX [path].
  static String hashPath(String path) => hashString(canonicalizePath(path));

  /// Computes the canonical path hash as defined in the spec appendix.
  ///
  /// The canonical path is normalized to use POSIX forward-slash separators,
  /// with no `.` or `..` segments. The hash is then `SHA-256(path_bytes)`.
  static String hashCanonicalPath(String path) => hashPath(path);

  /// Computes the SHA-256 hex digest of a file path in POSIX-normalized form.
  ///
  /// Same as [hashCanonicalPath] — convenience alias.
  static String hashFilePath(String filePath) => hashCanonicalPath(filePath);

  /// Computes the composite checkout hash.
  ///
  /// Builds the content `"efa:checkout:v2\n<pathHash> <contentHash>\n..."` with
  /// lines sorted by path hash, then returns the SHA-256 hex digest.
  static String hashCheckout(Iterable<({String pathHash, String contentHash})> entries) {
    final sorted = entries.toList()..sort((a, b) => a.pathHash.compareTo(b.pathHash));
    final buffer = StringBuffer("efa:checkout:v2\n");
    for (final e in sorted) {
      buffer.writeln("${e.pathHash} ${e.contentHash}");
    }
    return hashString(buffer.toString());
  }
}
