import "package:eve_fit_assistant/storage/repo/hash.dart";

/// Identifies a blob by its URI namespace and computes the ident_hash.
///
/// The ident_hash is SHA-256 of the full URI string (spec §5).
class BlobIdent {
  /// Creates a resource blob ident.
  ///
  /// URI format: `resource://{relativePath}`
  factory BlobIdent.resource(String relativePath) {
    final uri = "resource://$relativePath";
    return BlobIdent._(uri: uri, identHash: RepoHash.hashIdent(uri));
  }

  /// Creates a release blob ident.
  ///
  /// URI format: `release://{platform}/{version}/{filename}`
  factory BlobIdent.release(String platform, String version, String filename) {
    final uri = "release://$platform/$version/$filename";
    return BlobIdent._(uri: uri, identHash: RepoHash.hashIdent(uri));
  }

  /// Creates an announcement blob ident.
  ///
  /// URI format: `announcement://{locale}/{id}`
  factory BlobIdent.announcement(String locale, String id) {
    final uri = "announcement://$locale/$id";
    return BlobIdent._(uri: uri, identHash: RepoHash.hashIdent(uri));
  }
  const BlobIdent._({required this.uri, required this.identHash});

  /// The full URI string (e.g. `resource://tranquility/proto/ships.bin`).
  final String uri;

  /// SHA-256 hex digest of [uri].
  final String identHash;

  @override
  bool operator ==(Object other) => other is BlobIdent && other.identHash == identHash;

  @override
  int get hashCode => identHash.hashCode;

  @override
  String toString() => "BlobIdent($uri)";
}
