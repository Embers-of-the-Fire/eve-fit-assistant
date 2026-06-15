import "dart:convert";
import "dart:typed_data";

import "package:crypto/crypto.dart";

/// SHA-256 hex digest and structured hash utilities.
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

  /// Computes the ident hash for a blob URI.
  ///
  /// ident_hash = SHA-256(uri_string) — used for blob storage addressing.
  static String hashIdent(String uri) => hashString(uri);

  // ── Structured hashes (agent/schemav2/schema.md §6.2) ───────────────────────

  /// Computes the structured resource snapshot hash.
  ///
  /// snapshot_hash = SHA-256(
  ///   "efa:resource:v2\n"
  ///   "metadata.json <sha256_of_metadata_json_bytes>\n"
  ///   "resources.pb2 <sha256_of_resources_pb2_bytes>\n"
  /// )
  static String hashResourceSnapshot(String metadataJsonHash, String resourcesPb2Hash) {
    final buffer = StringBuffer("efa:resource:v2\n");
    buffer.writeln("metadata.json $metadataJsonHash");
    buffer.writeln("resources.pb2 $resourcesPb2Hash");
    return hashString(buffer.toString());
  }

  /// Computes the structured release snapshot hash.
  static String hashReleaseSnapshot(String metadataJsonHash, String releasesPb2Hash) {
    final buffer = StringBuffer("efa:release:v2\n");
    buffer.writeln("metadata.json $metadataJsonHash");
    buffer.writeln("releases.pb2 $releasesPb2Hash");
    return hashString(buffer.toString());
  }

  /// Computes the structured announcement snapshot hash.
  static String hashAnnouncementSnapshot(String metadataJsonHash, String announcementsPb2Hash) {
    final buffer = StringBuffer("efa:announcement:v2\n");
    buffer.writeln("metadata.json $metadataJsonHash");
    buffer.writeln("announcements.pb2 $announcementsPb2Hash");
    return hashString(buffer.toString());
  }

  /// Computes the structured generation hash.
  ///
  /// generation_hash = SHA-256(
  ///   "efa:generation:v2\n"
  ///   "announcements.pb2 <hash>\n"
  ///   "metadata.json <hash>\n"
  ///   "releases.pb2 <hash>\n"
  ///   "resources.pb2 <hash>\n"
  ///   "server.pb2 <hash>\n"
  /// )
  ///
  /// Lines are sorted lexicographically by filename.
  static String hashGeneration({
    required String metadataJsonHash,
    required String serverPb2Hash,
    required String resourcesPb2Hash,
    required String releasesPb2Hash,
    required String announcementsPb2Hash,
  }) {
    final buffer = StringBuffer("efa:generation:v2\n");
    // Sorted lexicographically by filename
    buffer.writeln("announcements.pb2 $announcementsPb2Hash");
    buffer.writeln("metadata.json $metadataJsonHash");
    buffer.writeln("releases.pb2 $releasesPb2Hash");
    buffer.writeln("resources.pb2 $resourcesPb2Hash");
    buffer.writeln("server.pb2 $serverPb2Hash");
    return hashString(buffer.toString());
  }
}
