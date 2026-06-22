import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/features/remote_content/http.dart" as remote_http;
import "package:eve_fit_assistant/storage/repo/models/channel_head_meta.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_registry.dart";
import "package:eve_fit_assistant/storage/repo/models/snapshot_meta.dart";
import "package:fpdart/fpdart.dart";

/// Errors that may occur during remote catalog operations.
sealed class CatalogError {
  const CatalogError();
}

class CatalogNetworkError extends CatalogError {
  const CatalogNetworkError({required this.message, this.statusCode});

  final String message;
  final int? statusCode;
}

class CatalogNotFoundError extends CatalogError {
  const CatalogNotFoundError({required this.message});

  final String message;
}

class CatalogParseError extends CatalogError {
  const CatalogParseError({required this.message});

  final String message;
}

class CatalogNotModified extends CatalogError {
  const CatalogNotModified();
}

/// Fetches remote catalog data under `efa/v2/` with ETag caching.
///
/// Implements the fetch protocol from agent/schemav2/workflow.md §2.2-§2.6.
class RemoteCatalogService {
  RemoteCatalogService({required this.dio, required this.originUrl});

  final Dio dio;
  final String originUrl;

  /// In-memory payload caches so HTTP 304 responses can be satisfied without a
  /// redundant re-download. The persistent [EtagCache] outlives a process, so
  /// these warm during a session; cold starts fall back to a fresh fetch.
  final Map<Uri, Map<String, dynamic>> _jsonCache = <Uri, Map<String, dynamic>>{};
  final Map<Uri, Uint8List> _bytesCache = <Uri, Uint8List>{};

  Uri _buildUri(String relativePath) {
    final normalizedOrigin = originUrl.endsWith("/") ? originUrl : "$originUrl/";
    return Uri.parse("${normalizedOrigin}efa/v2/$relativePath");
  }

  // ── Channel discovery (§13.1) ──────────────────────────────────────────────

  /// GET `channels/heads/channels.json`
  ///
  /// Remote spec §7.3 uses `defaultChannel`, while the client model stores
  /// `active`. We map the key before parsing.
  Future<Either<CatalogError, ChannelRegistry>> fetchChannelRegistry({
    Map<String, dynamic>? cachedPayload,
  }) async {
    final uri = _buildUri("channels/heads/channels.json");
    return _fetchJson(uri, (json) {
      final mapped = Map<String, dynamic>.from(json);
      if (mapped.containsKey("defaultChannel") && !mapped.containsKey("active")) {
        mapped["active"] = mapped["defaultChannel"];
      }
      return ChannelRegistry.fromJson(mapped);
    }, cachedPayload: cachedPayload);
  }

  /// GET `channels/heads/{channel}/metadata.json`
  Future<Either<CatalogError, ChannelHeadMeta>> fetchHeadMeta(
    String channelName, {
    Map<String, dynamic>? cachedPayload,
  }) async {
    final uri = _buildUri("channels/heads/$channelName/metadata.json");
    return _fetchJson(uri, ChannelHeadMeta.fromJson, cachedPayload: cachedPayload);
  }

  // ── Generation fetch (§13.2) ───────────────────────────────────────────────

  /// GET `channels/refs/{generationHash}/server.pb2`
  Future<Either<CatalogError, Uint8List>> fetchServerIndex(String generationHash) async {
    final uri = _buildUri("channels/refs/$generationHash/server.pb2");
    return _fetchBytes(uri);
  }

  /// GET `channels/refs/{generationHash}/server.pb2`, bypassing the ETag cache.
  ///
  /// Used by the setup/welcome browser to recover from a stale persisted ETag
  /// that yields HTTP 304 with no locally available payload.
  Future<Either<CatalogError, Uint8List>> fetchServerIndexFresh(String generationHash) async {
    final uri = _buildUri("channels/refs/$generationHash/server.pb2");
    return _fetchBytes(uri, bypassEtag: true);
  }

  /// GET `channels/refs/{generationHash}/resources.pb2`
  Future<Either<CatalogError, Uint8List>> fetchGenerationResources(String generationHash) async {
    final uri = _buildUri("channels/refs/$generationHash/resources.pb2");
    return _fetchBytes(uri);
  }

  /// GET `channels/refs/{generationHash}/resources.pb2`, bypassing the ETag cache.
  Future<Either<CatalogError, Uint8List>> fetchGenerationResourcesFresh(
    String generationHash,
  ) async {
    final uri = _buildUri("channels/refs/$generationHash/resources.pb2");
    return _fetchBytes(uri, bypassEtag: true);
  }

  /// GET `channels/refs/{generationHash}/releases.pb2`
  Future<Either<CatalogError, Uint8List>> fetchGenerationPointer(String generationHash) async {
    final uri = _buildUri("channels/refs/$generationHash/releases.pb2");
    return _fetchBytes(uri);
  }

  // ── Release fetch (§13.4) ─────────────────────────────────────────────────

  /// GET `assets/resources/{snapshotHash}/metadata.json`
  Future<Either<CatalogError, ResourceSnapshotMeta>> fetchResourceSnapshotMeta(
    String snapshotHash, {
    Map<String, dynamic>? cachedPayload,
  }) async {
    final uri = _buildUri("assets/resources/$snapshotHash/metadata.json");
    return _fetchJson(uri, ResourceSnapshotMeta.fromJson, cachedPayload: cachedPayload);
  }

  /// GET `assets/resources/{snapshotHash}/resources.pb2`
  Future<Either<CatalogError, Uint8List>> fetchResourceIndex(String snapshotHash) async {
    final uri = _buildUri("assets/resources/$snapshotHash/resources.pb2");
    return _fetchBytes(uri);
  }

  // ── Blob fetch ─────────────────────────────────────────────────────────────

  /// GET `assets/releases/{snapshotHash}/releases.pb2`
  Future<Either<CatalogError, Uint8List>> fetchReleaseIndex(String snapshotHash) async {
    final uri = _buildUri("assets/releases/$snapshotHash/releases.pb2");
    return _fetchBytes(uri);
  }

  // ── Blob fetch ─────────────────────────────────────────────────────────────

  /// GET `assets/blobs/{2c}/{identHash}/{contentHash}`
  Future<Either<CatalogError, Uint8List>> fetchBlob(String identHash, String contentHash) async =>
      _fetchBytes(blobUri(identHash, contentHash));

  /// The content-addressed URI for a blob.
  ///
  /// Exposed so callers can target the exact URL (e.g. to clear a stale ETag).
  Uri blobUri(String identHash, String contentHash) {
    final prefix = identHash.substring(0, 2);
    return _buildUri("assets/blobs/$prefix/$identHash/$contentHash");
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<Either<CatalogError, T>> _fetchJson<T>(
    Uri uri,
    T Function(Map<String, dynamic>) fromJson, {
    Map<String, dynamic>? cachedPayload,
  }) async {
    try {
      final json = await remote_http.fetchRemoteJson(dio, uri, cachedPayload: cachedPayload);
      return Right(fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(CatalogNotFoundError(message: "Not found: $uri"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } on FormatException catch (e) {
      return Left(CatalogParseError(message: "Invalid JSON: ${e.message}"));
    } catch (e) {
      return Left(CatalogParseError(message: "Catalog parse error: $e"));
    }
  }

  Future<Either<CatalogError, Uint8List>> _fetchBytes(Uri uri, {bool bypassEtag = false}) async {
    if (bypassEtag) {
      EtagCache.remove(uri);
    }
    try {
      // All byte resources under `efa/v2/` are content-addressed (keyed by
      // generation/snapshot/content hash), so conditional requests can never
      // produce a useful 304 — the server returns the exact bytes or 404.
      // Skip conditional headers to avoid wasting memory caching their ETags.
      final result = await remote_http.getRemoteUri<Uint8List>(
        dio,
        uri,
        responseType: ResponseType.bytes,
        sendConditionalHeaders: false,
      );
      if (result.notModified) {
        final cached = _bytesCache[uri];
        if (cached != null) {
          return Right(cached);
        }
        // Cold start with a stale persisted ETag: no cached payload exists,
        // so we clear the ETag and retry unconditionally (mirrors the JSON
        // self-healing pattern in fetchRemoteJson).
        EtagCache.remove(uri);
        return _fetchBytes(uri);
      }
      final data = result.response.data;
      if (data is! Uint8List) {
        return Left(CatalogParseError(message: "Response not bytes: $uri"));
      }
      _bytesCache[uri] = data;
      return Right(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(CatalogNotFoundError(message: "Not found: $uri"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }
}
