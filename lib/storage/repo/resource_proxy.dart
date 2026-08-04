import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/on_demand_blob.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter/foundation.dart";
import "package:fpdart/fpdart.dart";

/// Unified read-only access to resources in the content-addressed blob store.
///
/// Wraps an [AssetStore] and a [ResourceIndex] to provide O(1) resource lookup
/// by `resource_id` URI. All consumers (collection service, engine service,
/// image assets) resolve resources through this proxy instead of accessing the
/// blob store or filesystem paths directly.
///
/// When an [OnDemandBlobFetcher] is supplied, reads of blobs that are absent
/// locally (NON_FORCE resources skipped during provisioning, or failed
/// downloads) transparently fetch them from the remote catalog.
class ResourceBlobProxy {
  ResourceBlobProxy(this._assetStore, ResourceIndex resourceIndex, [this._fetcher])
    : _entries = {for (final e in resourceIndex.entries) e.resourceId: e};

  final AssetStore _assetStore;
  final OnDemandBlobFetcher? _fetcher;
  final Map<String, ResourceIndex_Entry> _entries;

  /// Reads resource bytes by [resourceId] (e.g. `"resource://static/collection.pb2"`).
  ///
  /// Returns [None] if the resource is not in the index, or the blob is
  /// missing locally and no [OnDemandBlobFetcher] is available (or the
  /// on-demand fetch fails).
  Future<Option<Uint8List>> read(String resourceId) async {
    final entry = _entries[resourceId];
    if (entry == null) return const None();
    final identHash = RepoHash.hashIdent(resourceId);
    final local = await _assetStore.readBlob(identHash, entry.contentHash);
    if (local.isSome()) return local;
    final fetcher = _fetcher;
    if (fetcher == null) return const None();
    return fetcher.read(identHash, entry.contentHash);
  }

  /// Resolves the direct content-addressed blob store file path for [resourceId].
  ///
  /// Returns `null` if the resource is not in the index — or on web, where
  /// blobs live in OPFS and no filesystem path exists; web consumers must use
  /// [read] instead. The returned path points to the immutable blob file on
  /// disk; consumers that need a file path (e.g. the Rust engine via FRB) can
  /// use it directly.
  String? resolvePath(String resourceId) {
    if (kIsWeb) return null;
    final entry = _entries[resourceId];
    if (entry == null) return null;
    return RepoPaths.blobPath(RepoHash.hashIdent(resourceId), entry.contentHash);
  }

  /// Returns the [ResourceIndex_Entry] for [resourceId], or `null` if absent.
  ResourceIndex_Entry? entry(String resourceId) => _entries[resourceId];

  /// Returns the ident hash and content hash for [resourceId], or `null`.
  ({String identHash, String contentHash})? ident(String resourceId) {
    final entry = _entries[resourceId];
    if (entry == null) return null;
    return (identHash: RepoHash.hashIdent(resourceId), contentHash: entry.contentHash);
  }
}
