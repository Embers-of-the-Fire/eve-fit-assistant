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

  // ── Structured hashes (agent/schemav2/schema.md §6.2, v3) ──────────────────

  /// Computes the structured resource snapshot hash (v3).
  ///
  ///   snapshot_hash = SHA-256(
  ///     "efa:resource:v3\n"
  ///     "metadata.json {sha256_of_canonical_metadata_json_bytes}\n"
  ///   )
  static String hashResourceSnapshot(String metadataJsonHash) =>
      hashString("efa:resource:v3\nmetadata.json $metadataJsonHash\n");

  /// Computes the structured release snapshot hash (v3).
  static String hashReleaseSnapshot(String metadataJsonHash) =>
      hashString("efa:release:v3\nmetadata.json $metadataJsonHash\n");

  /// Computes the structured generation hash (v3).
  ///
  ///   generation_hash = SHA-256(
  ///     "efa:generation:v3\n"
  ///     "metadata.json {hash}\n"
  ///   )
  static String hashGeneration({required String metadataJsonHash}) =>
      hashString("efa:generation:v3\nmetadata.json $metadataJsonHash\n");
}
