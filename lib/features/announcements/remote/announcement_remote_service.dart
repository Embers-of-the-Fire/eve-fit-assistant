import "dart:convert";

import "package:dio/dio.dart";
import "package:dio_cache_interceptor/dio_cache_interceptor.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/remote/body_cache.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/features/remote_content/endpoint.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

final announcementRemoteServiceProvider = Provider<AnnouncementRemoteService>(
  (Ref ref) => AnnouncementRemoteService(ref: ref),
);

class AnnouncementRemoteService {
  AnnouncementRemoteService({required this._ref, Dio? dio}) : _dio = dio ?? createRemoteDio();

  final Ref _ref;
  final Dio _dio;

  /// Clears only the shared HTTP cache entries for announcement resources under
  /// the configured remote content endpoint.
  ///
  /// [RemoteCache.clear()] evicts the entire shared store, which would also
  /// discard cached remote catalog and other content. We instead use the
  /// configured endpoint's origin to build a URI/prefix pattern and delete only
  /// announcement entries.
  Future<void> invalidateCache() async {
    final endpoint = _resolveEndpoint();
    if (endpoint == null) return;

    final origin = endpoint.originUri.toString();
    final base = origin.endsWith("/") ? origin : "$origin/";
    final pattern = RegExp("${RegExp.escape(base)}.*efa/v2/announcements/");
    await RemoteCache.store.deleteFromPath(pattern);
  }

  Future<AnnouncementCatalog?> fetchCatalog() async {
    final endpoint = _resolveEndpoint();
    if (endpoint == null) return null;

    try {
      final payload = await _fetchJson(endpoint.announcementV2CatalogUri);
      final catalog = AnnouncementCatalog.fromJson(payload);
      if (!catalog.isSupported) {
        warning(
          "Unsupported announcement catalog schemaVersion ${catalog.schemaVersion}; "
          "falling back to bundled entries only",
        );
        return null;
      }
      return catalog;
    } on Object catch (e, st) {
      warning("Failed to fetch announcement catalog: $e", stackTrace: st);
      return null;
    }
  }

  Future<AnnouncementPage?> fetchPage(String uuid, {bool active = false}) async {
    final endpoint = _resolveEndpoint();
    if (endpoint == null) return null;

    final uri = active
        ? endpoint.announcementV2ActivePageUri
        : endpoint.announcementV2PageUri(uuid);

    try {
      final payload = await _fetchJson(uri);
      return AnnouncementPage.fromJson(payload);
    } on Object catch (e, st) {
      warning("Failed to fetch announcement page $uuid: $e", stackTrace: st);
      return null;
    }
  }

  Future<String?> fetchBody(String bodyHash) async {
    final cached = await AnnouncementBodyCache.get(bodyHash);
    if (cached != null) return cached;

    final endpoint = _resolveEndpoint();
    if (endpoint == null) return null;

    try {
      // Markdown bodies are content-addressed by their hash; bypass the shared
      // HTTP cache so a stale ETag cannot produce a 304 with no local body.
      final response = await _dio.getUri<String>(
        endpoint.announcementV2BodyUri(bodyHash),
        options: nonManagedCachePolicy.toRequestOptions().copyWith(
          responseType: ResponseType.plain,
        ),
      );
      final content = response.data;
      if (content == null) return null;
      await AnnouncementBodyCache.put(bodyHash, content);
      return content;
    } on Object catch (e, st) {
      warning("Failed to fetch announcement body $bodyHash: $e", stackTrace: st);
      return null;
    }
  }

  Future<Map<String, dynamic>> _fetchJson(Uri uri) async {
    final response = await _dio.getUri<String>(
      uri,
      options: RemoteCache.options.toOptions().copyWith(responseType: ResponseType.plain),
    );
    final data = response.data;
    if (data == null) {
      throw RemoteContentException("Remote JSON response is empty: $uri");
    }
    final decoded = jsonDecode(data);
    if (decoded is! Map<String, dynamic>) {
      throw RemoteContentException("Remote JSON response is not an object: $uri");
    }
    return decoded;
  }

  RemoteContentEndpoint? _resolveEndpoint() {
    final config = _ref.read(appSettingServiceProvider).remoteContent;
    if (!config.enabled) return null;

    final originUri = Uri.tryParse(config.originUrl);
    if (originUri == null) return null;

    return RemoteContentEndpoint(originUri: originUri, channel: config.channel);
  }
}
