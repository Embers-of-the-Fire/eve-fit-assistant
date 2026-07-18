import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
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

/// Fetches remote catalog data under `efa/v2/` with the shared HTTP cache.
///
/// All JSON metadata is cached and validated by the Dio cache interceptor using
/// the origin's ETag/Last-Modified headers. Byte resources (generation refs,
/// resource indexes, blobs) are content-addressed and fetched with
/// `CachePolicy.noCache` so they are not managed by the HTTP cache.
class RemoteCatalogService {
  RemoteCatalogService({required this.dio, required this.originUrl});

  final Dio dio;
  final String originUrl;

  Uri _buildUri(String relativePath) {
    final normalizedOrigin = originUrl.endsWith("/") ? originUrl : "$originUrl/";
    return Uri.parse("${normalizedOrigin}efa/v2/$relativePath");
  }

  // ── Channel discovery ──────────────────────────────────────────────────────

  /// GET `channels/heads/channels.json`
  ///
  /// Remote spec uses `defaultChannel`, while the client model stores `active`.
  /// We map the key before parsing.
  Future<Either<CatalogError, ChannelRegistry>> fetchChannelRegistry() async {
    final uri = _buildUri("channels/heads/channels.json");
    return _fetchJson(uri, (json) {
      final mapped = Map<String, dynamic>.from(json);
      if (mapped.containsKey("defaultChannel") && !mapped.containsKey("active")) {
        mapped["active"] = mapped["defaultChannel"];
      }
      return ChannelRegistry.fromJson(mapped);
    });
  }

  /// GET `channels/heads/{channel}/metadata.json`
  Future<Either<CatalogError, ChannelHeadMeta>> fetchHeadMeta(String channelName) async {
    final uri = _buildUri("channels/heads/$channelName/metadata.json");
    return _fetchJson(uri, ChannelHeadMeta.fromJson);
  }

  // ── Generation fetch ───────────────────────────────────────────────────────

  /// GET `channels/refs/{generationHash}/server.pb2`
  Future<Either<CatalogError, Uint8List>> fetchServerIndex(String generationHash) async {
    final uri = _buildUri("channels/refs/$generationHash/server.pb2");
    return _fetchBytes(uri);
  }

  /// GET `channels/refs/{generationHash}/resources.pb2`
  Future<Either<CatalogError, Uint8List>> fetchGenerationResources(String generationHash) async {
    final uri = _buildUri("channels/refs/$generationHash/resources.pb2");
    return _fetchBytes(uri);
  }

  /// GET `channels/refs/{generationHash}/releases.pb2`
  Future<Either<CatalogError, Uint8List>> fetchGenerationPointer(String generationHash) async {
    final uri = _buildUri("channels/refs/$generationHash/releases.pb2");
    return _fetchBytes(uri);
  }

  // ── Release fetch ───────────────────────────────────────────────────────────

  /// GET `assets/resources/{snapshotHash}/metadata.json`
  Future<Either<CatalogError, ResourceSnapshotMeta>> fetchResourceSnapshotMeta(
    String snapshotHash,
  ) async {
    final uri = _buildUri("assets/resources/$snapshotHash/metadata.json");
    return _fetchJson(uri, ResourceSnapshotMeta.fromJson);
  }

  /// GET `assets/resources/{snapshotHash}/resources.pb2`
  Future<Either<CatalogError, Uint8List>> fetchResourceIndex(String snapshotHash) async {
    final uri = _buildUri("assets/resources/$snapshotHash/resources.pb2");
    return _fetchBytes(uri);
  }

  /// GET `assets/releases/{snapshotHash}/releases.pb2`
  Future<Either<CatalogError, Uint8List>> fetchReleaseIndex(String snapshotHash) async {
    final uri = _buildUri("assets/releases/$snapshotHash/releases.pb2");
    return _fetchBytes(uri);
  }

  // ── Blob fetch ─────────────────────────────────────────────────────────────

  /// GET `assets/blobs/{2c}/{identHash}/{contentHash}`
  ///
  /// Blobs are content-addressed and non-managed: the HTTP cache interceptor is
  /// bypassed and the caller is responsible for writing to the asset store.
  Future<Either<CatalogError, Uint8List>> fetchBlob(String identHash, String contentHash) async {
    final uri = _blobUri(identHash, contentHash);
    return _fetchBytes(uri);
  }

  /// The content-addressed URI for a blob or artifact.
  ///
  /// Exposed so callers (e.g. APK downloader) can build the exact URL for
  /// content-addressed resources that are fetched outside the shared HTTP cache.
  Uri blobUri(String identHash, String contentHash) {
    final prefix = identHash.substring(0, 2);
    return _buildUri("assets/blobs/$prefix/$identHash/$contentHash");
  }

  Uri _blobUri(String identHash, String contentHash) => blobUri(identHash, contentHash);

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<Either<CatalogError, T>> _fetchJson<T>(
    Uri uri,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    try {
      final response = await dio.getUri<String>(uri);
      final data = response.data;
      if (data == null) {
        return Left(CatalogParseError(message: "Empty JSON response: $uri"));
      }
      final decoded = jsonDecode(data) as Object?;
      if (decoded is! Map<String, dynamic>) {
        return Left(CatalogParseError(message: "JSON response is not an object: $uri"));
      }
      return Right(fromJson(decoded));
    } on DioException catch (e) {
      return Left(_mapDioException(e, uri));
    } on FormatException catch (e) {
      return Left(CatalogParseError(message: "Invalid JSON for $uri: ${e.message}"));
    } catch (e) {
      return Left(CatalogParseError(message: "Catalog parse error for $uri: $e"));
    }
  }

  Future<Either<CatalogError, Uint8List>> _fetchBytes(Uri uri) async {
    try {
      final response = await dio.getUri<Uint8List>(
        uri,
        options: nonManagedCachePolicy.toRequestOptions().copyWith(
          responseType: ResponseType.bytes,
        ),
      );
      final data = response.data;
      if (data == null) {
        return Left(CatalogParseError(message: "Empty byte response: $uri"));
      }
      return Right(data);
    } on DioException catch (e) {
      return Left(_mapDioException(e, uri));
    } catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }

  CatalogError _mapDioException(DioException exception, Uri uri) {
    final status = exception.response?.statusCode;
    if (status == 404) {
      return CatalogNotFoundError(message: "Not found: $uri");
    }
    final statusMsg = status == null ? "" : " with HTTP $status";
    return CatalogNetworkError(
      message: exception.message ?? "Remote request failed for $uri$statusMsg",
      statusCode: status,
    );
  }
}
