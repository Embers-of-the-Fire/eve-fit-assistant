import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/remote/body_cache.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/features/remote_content/endpoint.dart";
import "package:eve_fit_assistant/features/remote_content/http.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

final announcementRemoteServiceProvider = Provider<AnnouncementRemoteService>(
  (Ref ref) => AnnouncementRemoteService(ref: ref),
);

class AnnouncementRemoteService {
  AnnouncementRemoteService({required Ref ref, Dio? dio})
    : _ref = ref,
      _dio = dio ?? createRemoteDio();

  final Ref _ref;
  final Dio _dio;

  Map<String, dynamic>? _cachedCatalogPayload;
  final Map<String, Map<String, dynamic>> _pageCache = <String, Map<String, dynamic>>{};

  /// Drop in-memory catalog and page caches so the next fetch hits the
  /// network.
  void invalidateCache() {
    _cachedCatalogPayload = null;
    _pageCache.clear();
  }

  Future<AnnouncementCatalog?> fetchCatalog() async {
    final endpoint = _resolveEndpoint();
    if (endpoint == null) return null;

    try {
      final payload = await fetchRemoteJson(
        _dio,
        endpoint.announcementV2CatalogUri,
        cachedPayload: _cachedCatalogPayload,
      );
      _cachedCatalogPayload = payload;
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
      final payload = await fetchRemoteJson(_dio, uri, cachedPayload: _pageCache[uuid]);
      _pageCache[uuid] = payload;
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
      final result = await getRemoteUri<String>(_dio, endpoint.announcementV2BodyUri(bodyHash));
      if (result.notModified) return null;
      final content = result.response.data;
      if (content is! String) return null;
      await AnnouncementBodyCache.put(bodyHash, content);
      return content;
    } on Object catch (e, st) {
      warning("Failed to fetch announcement body $bodyHash: $e", stackTrace: st);
      return null;
    }
  }

  RemoteContentEndpoint? _resolveEndpoint() {
    final config = _ref.read(appSettingServiceProvider).remoteContent;
    if (!config.enabled) return null;

    final originUri = Uri.tryParse(config.originUrl);
    if (originUri == null) return null;

    return RemoteContentEndpoint(originUri: originUri, channel: config.channel);
  }
}
