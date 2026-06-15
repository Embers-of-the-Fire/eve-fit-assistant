import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/remote_content/http.dart" as remote_http;
import "package:eve_fit_assistant/storage/repo/models/announcement.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_catalog.dart";
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

/// Fetches remote catalog data under `efa/v2/<channel>/` with ETag caching.
///
/// Reuses the existing [remote_http.fetchRemoteJson] infrastructure which
/// handles conditional requests via EtagCache and Dio.
class RemoteCatalogService {
  const RemoteCatalogService({required this.dio, required this.originUrl});

  final Dio dio;
  final String originUrl;

  Uri _buildUri(Channel channel, String relativePath) {
    final normalizedOrigin = originUrl.endsWith("/") ? originUrl : "$originUrl/";
    return Uri.parse("${normalizedOrigin}efa/v2/${channel.value}/$relativePath");
  }

  /// Fetches the manifest index for [channel].
  ///
  /// GET `efa/v2/<channel>/manifest/index.json`
  Future<Either<CatalogError, ManifestIndex>> fetchManifestIndex(Channel channel) async {
    final uri = _buildUri(channel, "manifest/index.json");
    try {
      final json = await remote_http.fetchRemoteJson(dio, uri);
      return Right(ManifestIndex.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const Left(CatalogNotFoundError(message: "Manifest index not found"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } on FormatException catch (e) {
      return Left(CatalogParseError(message: "Invalid JSON: ${e.message}"));
    } on Exception catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }

  /// Fetches the generations index for [channel].
  ///
  /// GET `efa/v2/<channel>/manifest/generations.json`
  Future<Either<CatalogError, GenerationsIndex>> fetchGenerations(Channel channel) async {
    final uri = _buildUri(channel, "manifest/generations.json");
    try {
      final json = await remote_http.fetchRemoteJson(dio, uri);
      return Right(GenerationsIndex.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return const Left(CatalogNotFoundError(message: "Generations index not found"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } on FormatException catch (e) {
      return Left(CatalogParseError(message: "Invalid JSON: ${e.message}"));
    } on Exception catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }

  /// Fetches the server catalog for [genId] and [serverId] on [channel].
  ///
  /// GET `efa/v2/<channel>/manifest/.generations/<gen>/resources/servers/<serverId>.json`
  Future<Either<CatalogError, GenerationServer>> fetchServerCatalog(
    Channel channel,
    String genId,
    String serverId,
  ) async {
    final uri = _buildUri(channel, "manifest/.generations/$genId/resources/servers/$serverId.json");
    try {
      final json = await remote_http.fetchRemoteJson(dio, uri);
      return Right(GenerationServer.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(CatalogNotFoundError(message: "Server catalog not found: $serverId"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } on FormatException catch (e) {
      return Left(CatalogParseError(message: "Invalid JSON: ${e.message}"));
    } on Exception catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }

  /// Fetches the checkout catalog for [checkoutHash] on [channel] from the
  /// flat content-addressed registry.
  ///
  /// GET `efa/v2/<channel>/manifest/checkouts/<first-2-chars>/<checkoutHash>.json`
  Future<Either<CatalogError, GenerationCheckoutCatalog>> fetchCheckoutCatalog(
    Channel channel,
    String checkoutHash,
  ) async {
    if (checkoutHash.length < 2) {
      return const Left(CatalogParseError(message: "checkoutHash must be at least 2 characters"));
    }
    final prefix = checkoutHash.substring(0, 2);
    final uri = _buildUri(channel, "manifest/checkouts/$prefix/$checkoutHash.json");
    try {
      final json = await remote_http.fetchRemoteJson(dio, uri);
      return Right(GenerationCheckoutCatalog.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(CatalogNotFoundError(message: "Checkout catalog not found: $checkoutHash"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } on FormatException catch (e) {
      return Left(CatalogParseError(message: "Invalid JSON: ${e.message}"));
    } on Exception catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }

  /// Fetches the resources catalog for [genId] on [channel].
  ///
  /// GET `efa/v2/<channel>/manifest/.generations/<gen>/resources/catalog.json`
  Future<Either<CatalogError, GenerationResources>> fetchResourcesCatalog(
    Channel channel,
    String genId,
  ) async {
    final uri = _buildUri(channel, "manifest/.generations/$genId/resources/catalog.json");
    try {
      final json = await remote_http.fetchRemoteJson(dio, uri);
      return Right(GenerationResources.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(CatalogNotFoundError(message: "Resources catalog not found: $genId"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } on FormatException catch (e) {
      return Left(CatalogParseError(message: "Invalid JSON: ${e.message}"));
    } on Exception catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }

  /// Fetches a generation-scoped checkout catalog for [genId] and [checkoutId].
  ///
  /// GET `efa/v2/<channel>/manifest/.generations/<gen>/resources/checkouts/<checkoutId>.json`
  ///
  /// This is distinct from the flat-registry [fetchCheckoutCatalog]: the flat
  /// registry is for checkout discovery (unknown hash lookup), while this
  /// generation-scoped endpoint is for navigation through a generation's server list.
  Future<Either<CatalogError, GenerationCheckoutCatalog>> fetchGenerationCheckoutCatalog(
    Channel channel,
    String genId,
    String checkoutId,
  ) async {
    final uri = _buildUri(
      channel,
      "manifest/.generations/$genId/resources/checkouts/$checkoutId.json",
    );
    try {
      final json = await remote_http.fetchRemoteJson(dio, uri);
      return Right(GenerationCheckoutCatalog.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(CatalogNotFoundError(message: "Checkout catalog not found: $checkoutId"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } on FormatException catch (e) {
      return Left(CatalogParseError(message: "Invalid JSON: ${e.message}"));
    } on Exception catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }

  /// Fetches the generation catalog for [genId] on [channel].
  ///
  /// GET `efa/v2/<channel>/manifest/.generations/<gen>/catalog.json`
  Future<Either<CatalogError, GenerationCatalog>> fetchGenerationCatalog(
    Channel channel,
    String genId,
  ) async {
    final uri = _buildUri(channel, "manifest/.generations/$genId/catalog.json");
    try {
      final json = await remote_http.fetchRemoteJson(dio, uri);
      return Right(GenerationCatalog.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(CatalogNotFoundError(message: "Generation catalog not found: $genId"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } on FormatException catch (e) {
      return Left(CatalogParseError(message: "Invalid JSON: ${e.message}"));
    } on Exception catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }

  /// Fetches the announcement catalog for [genId] on [channel].
  ///
  /// GET `efa/v2/<channel>/manifest/.generations/<gen>/announcements/catalog.json`
  Future<Either<CatalogError, AnnouncementCatalog>> fetchAnnouncementCatalog(
    Channel channel,
    String genId,
  ) async {
    final uri = _buildUri(channel, "manifest/.generations/$genId/announcements/catalog.json");
    try {
      final json = await remote_http.fetchRemoteJson(dio, uri);
      return Right(AnnouncementCatalog.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(CatalogNotFoundError(message: "Announcement catalog not found: $genId"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } on FormatException catch (e) {
      return Left(CatalogParseError(message: "Invalid JSON: ${e.message}"));
    } on Exception catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }

  /// Fetches an announcement record by [id] on [channel].
  ///
  /// GET `efa/v2/<channel>/announcements/registry/<id>.json`
  Future<Either<CatalogError, AnnouncementRecord>> fetchAnnouncementRecord(
    Channel channel,
    String id,
  ) async {
    final uri = _buildUri(channel, "announcements/registry/$id.json");
    try {
      final json = await remote_http.fetchRemoteJson(dio, uri);
      return Right(AnnouncementRecord.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(CatalogNotFoundError(message: "Announcement record not found: $id"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } on FormatException catch (e) {
      return Left(CatalogParseError(message: "Invalid JSON: ${e.message}"));
    } on Exception catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }

  /// Fetches raw announcement markdown content for [locale] and [id].
  ///
  /// GET `efa/v2/<channel>/announcements/files/<locale>/<id>`
  ///
  /// Returns the raw markdown body as a string, not a JSON model.
  Future<Either<CatalogError, String>> fetchAnnouncementContent(
    Channel channel,
    String locale,
    String id,
  ) async {
    final uri = _buildUri(channel, "announcements/files/$locale/$id");
    try {
      final result = await remote_http.getRemoteUri<String>(dio, uri);
      if (result.notModified) {
        return Left(CatalogNotFoundError(message: "Not modified, no cached content: $uri"));
      }
      final data = result.response.data;
      if (data is! String) {
        return Left(CatalogParseError(message: "Content not text: $uri"));
      }
      return Right(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(CatalogNotFoundError(message: "Announcement content not found: $id"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } on Exception catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }

  /// Fetches the release catalog for [genId] on [channel].
  ///
  /// GET `efa/v2/<channel>/manifest/.generations/<gen>/releases/catalog.json`
  Future<Either<CatalogError, ReleaseCatalog>> fetchReleaseCatalog(
    Channel channel,
    String genId,
  ) async {
    final uri = _buildUri(channel, "manifest/.generations/$genId/releases/catalog.json");
    try {
      final json = await remote_http.fetchRemoteJson(dio, uri);
      return Right(ReleaseCatalog.fromJson(json));
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(CatalogNotFoundError(message: "Release catalog not found: $genId"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } on FormatException catch (e) {
      return Left(CatalogParseError(message: "Invalid JSON: ${e.message}"));
    } on Exception catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }

  /// Fetches a release file (binary blob) by [hash] on [channel].
  ///
  /// GET `efa/v2/<channel>/resources/releases/<first-2-chars>/<hash>`
  Future<Either<CatalogError, Uint8List>> fetchReleaseFile(Channel channel, String hash) async {
    final prefix = hash.substring(0, 2);
    final uri = _buildUri(channel, "resources/releases/$prefix/$hash");
    return _fetchBytes(uri);
  }

  /// Fetches a single asset file (binary blob) by [pathHash] and [contentHash].
  ///
  /// GET `efa/v2/<channel>/resources/assets/<first-2-chars>/<pathHash>/<contentHash>`
  Future<Either<CatalogError, Uint8List>> fetchAsset(
    Channel channel,
    String pathHash,
    String contentHash,
  ) async {
    final prefix = pathHash.substring(0, 2);
    final uri = _buildUri(channel, "resources/assets/$prefix/$pathHash/$contentHash");
    return _fetchBytes(uri);
  }

  Future<Either<CatalogError, Uint8List>> _fetchBytes(Uri uri) async {
    try {
      final result = await remote_http.getRemoteUri<Uint8List>(
        dio,
        uri,
        responseType: ResponseType.bytes,
      );
      if (result.notModified) {
        return Left(CatalogNotFoundError(message: "Not modified, no cached data: $uri"));
      }
      final data = result.response.data;
      if (data is! Uint8List) {
        return Left(CatalogParseError(message: "Response not bytes: $uri"));
      }
      return Right(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return Left(CatalogNotFoundError(message: "Asset not found: $uri"));
      }
      return Left(
        CatalogNetworkError(message: e.message ?? e.toString(), statusCode: e.response?.statusCode),
      );
    } on Exception catch (e) {
      return Left(CatalogNetworkError(message: e.toString()));
    }
  }
}
