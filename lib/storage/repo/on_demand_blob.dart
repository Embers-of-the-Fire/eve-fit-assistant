import "dart:async";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:flutter/foundation.dart";
import "package:fpdart/fpdart.dart";

/// Downloads resource blobs lazily on first access.
///
/// Resources marked NON_FORCE in a policy-aware ResourceIndex are skipped
/// during provisioning and data updates; when a consumer first reads one,
/// this fetcher transparently downloads it from the remote catalog into the
/// content-addressed store and serves it. Subsequent reads hit the store.
///
/// In-flight fetches are deduplicated by blob identity, so concurrent
/// readers of the same missing blob trigger exactly one download.
class OnDemandBlobFetcher {
  OnDemandBlobFetcher({required this._assetStore, required this._remoteCatalog});

  final AssetStore _assetStore;
  final RemoteCatalogService _remoteCatalog;
  final _inFlight = <String, Future<Option<Uint8List>>>{};

  /// Reads the blob `(identHash, contentHash)`, downloading it on demand when
  /// absent from the store.
  ///
  /// Returns [None] when the blob is absent locally and the remote fetch
  /// fails (network error, remote content unavailable).
  Future<Option<Uint8List>> read(String identHash, String contentHash) {
    final key = "$identHash/$contentHash";
    return _inFlight.putIfAbsent(key, () => _readThrough(key, identHash, contentHash));
  }

  Future<Option<Uint8List>> _readThrough(String key, String identHash, String contentHash) async {
    try {
      final local = await _assetStore.readBlob(identHash, contentHash);
      if (local.isSome()) return local;

      final result = await _remoteCatalog.fetchBlob(identHash, contentHash);
      if (result.isLeft()) {
        warning("On-demand blob fetch failed: $key");
        return const None();
      }

      final bytes = result.getRight().toNullable()!;
      // Content-addressed storage: a payload whose hash does not match the
      // index entry would be persisted under a wrong identity until the next
      // verify. Reject it instead of storing a corrupt blob.
      if (RepoHash.hashContent(bytes) != contentHash) {
        warning("On-demand blob content hash mismatch: $key");
        return const None();
      }
      try {
        await _assetStore.writeBlobUncheckedAt(RepoPaths.blobPath(identHash, contentHash), bytes);
      } catch (e, stackTrace) {
        warning("On-demand blob write failed: $key", stackTrace: stackTrace);
        return const None();
      }
      return Some(bytes);
    } finally {
      unawaited(_inFlight.remove(key));
    }
  }
}
