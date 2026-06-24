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

  // ── Structured hashes (v4 — also binds the typed .pb2 index, spec §7) ───────
  //
  // v4 is the canonical protocol for new snapshots. It binds the `.pb2` index
  // in addition to `metadata.json`, so tampering with the resource/release
  // index changes the content address. Must stay byte-for-byte identical to the
  // Python side (`bootstrap/remote/hash.py: snapshot_hash_v4`) so the client and
  // dev CLI agree on snapshot directory names (no split-brain hash).

  /// Computes the structured resource snapshot hash (v4).
  ///
  ///   snapshot_hash = SHA-256(
  ///     "efa:resource:v4\n"
  ///     "metadata.json {sha256_of_canonical_metadata_json_bytes}\n"
  ///     "resources.pb2 {sha256_of_resources_pb2_bytes}\n"
  ///   )
  static String hashResourceSnapshotV4({
    required String metadataJsonHash,
    required String resourcesPb2Hash,
  }) => hashString(
    "efa:resource:v4\nmetadata.json $metadataJsonHash\nresources.pb2 $resourcesPb2Hash\n",
  );

  /// Computes the structured release snapshot hash (v4).
  static String hashReleaseSnapshotV4({
    required String metadataJsonHash,
    required String releasesPb2Hash,
  }) => hashString(
    "efa:release:v4\nmetadata.json $metadataJsonHash\nreleases.pb2 $releasesPb2Hash\n",
  );
}
