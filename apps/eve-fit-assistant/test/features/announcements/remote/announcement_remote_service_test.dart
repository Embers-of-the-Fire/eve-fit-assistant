@TestOn("vm")
library;

import "dart:io";

import "package:dio/dio.dart";
import "package:dio_cache_interceptor/dio_cache_interceptor.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/features/announcements/remote/announcement_remote_service.dart";
import "package:eve_fit_assistant/features/announcements/remote/body_cache.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:eve_fit_assistant/features/remote_content/endpoint.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

const _defaultOriginUrl = "https://cdn.example.com/";
const _defaultChannel = "stable";

const _sampleCatalogJson = """
{
  "schemaVersion": 1,
  "pages": [
    {
      "uuid": "11111111-1111-1111-1111-111111111111",
      "publishedAt": "2026-06-15T00:00:00.000Z",
      "minAppVersion": "1.0.0",
      "channels": ["stable"],
      "count": 5,
      "active": false
    },
    {
      "uuid": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      "publishedAt": "2026-06-18T00:00:00.000Z",
      "minAppVersion": "0.0.0",
      "channels": ["stable"],
      "count": 3,
      "active": true
    }
  ]
}""";

const _samplePageJson = """
{
  "uuid": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
  "publishedAt": "2026-06-18T00:00:00.000Z",
  "maxEntries": 50,
  "entries": [
    {
      "id": "test-entry",
      "publishedAt": "2026-06-15T08:00:00.000Z",
      "tags": ["test"],
      "startup": false,
      "minAppVersion": null,
      "maxAppVersion": null,
      "channels": ["stable"],
      "platforms": ["android"],
      "appVersion": null,
      "localizations": {
        "en": {
          "title": "Test Entry",
          "summary": "A test entry.",
          "bodyHash": "deadbeef12345678901234567890123456789012345678901234567890abcdef"
        }
      }
    }
  ]
}""";

const _bodyHash = "deadbeef12345678901234567890123456789012345678901234567890abcdef";
const _sampleBodyContent = "# Test Body\n\nThis is a test body document.";

class _SuccessAdapter implements HttpClientAdapter {
  /// Count of requests without an `If-None-Match` header, i.e. requests that
  /// could not be answered by cache revalidation and fetched a fresh body.
  int unconditionalRequests = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    if (options.headers["if-none-match"] == null) {
      unconditionalRequests += 1;
    }
    final path = options.uri.path;
    String body;
    if (path.endsWith("/catalog.json") && path.contains("/announcements/")) {
      body = _sampleCatalogJson;
    } else if (path == "/efa/v2/announcements/active.json" ||
        path.startsWith("/efa/v2/announcements/pages/")) {
      body = _samplePageJson;
    } else if (path.startsWith("/efa/v2/announcements/documents/")) {
      body = _sampleBodyContent;
    } else if (path == "/efa/v2/manifest/index.json") {
      body = '{"schemaVersion": 1, "generations": []}';
    } else {
      return ResponseBody.fromString("", 404);
    }
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        "etag": ['"test-etag"'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _ErrorAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    throw DioException(requestOptions: options, message: "Network error");
  }

  @override
  void close({bool force = false}) {}
}

class _NotFoundAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString("Not Found", 404);

  @override
  void close({bool force = false}) {}
}

class _UnsupportedSchemaAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    '{"schemaVersion": 999, "pages": []}',
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

AppSetting _testAppSetting({bool remoteEnabled = true}) => AppSetting(
  locale: Locale.en,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
  remoteContent: RemoteContentSetting(
    enabled: remoteEnabled,
    originUrl: _defaultOriginUrl,
    channel: _defaultChannel,
  ),
);

ProviderContainer _createContainer({bool remoteEnabled = true, Dio? dio}) {
  final container = ProviderContainer(
    overrides: [
      appSettingServiceProvider.overrideWithValue(_testAppSetting(remoteEnabled: remoteEnabled)),
      if (dio != null)
        announcementRemoteServiceProvider.overrideWith(
          (ref) => AnnouncementRemoteService(ref: ref, dio: dio),
        ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Dio _createCachingDio(HttpClientAdapter adapter) {
  final dio = Dio(BaseOptions());
  dio.interceptors.add(DioCacheInterceptor(options: RemoteCache.options));
  dio.httpClientAdapter = adapter;
  return dio;
}

String _urlPattern(String url) => "^${RegExp.escape(url)}\$";

void main() {
  late String tempDir;

  setUpAll(() async {
    tempDir = Directory.systemTemp.createTempSync("efa_rsvc_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.cachesPath = tempDir;
    await RemoteCache.init();
    await RemoteCache.clear();
    GlobalLogger.init(tempDir, enableDebugLog: false);
  });

  tearDownAll(() {
    Directory(tempDir).deleteSync(recursive: true);
  });

  group("AnnouncementRemoteService fetchCatalog", () {
    test("returns AnnouncementCatalog on success", () async {
      final dio = Dio(BaseOptions())..httpClientAdapter = _SuccessAdapter();
      final container = _createContainer(dio: dio);
      final service = container.read(announcementRemoteServiceProvider);

      final catalog = await service.fetchCatalog();
      expect(catalog, isNotNull);
      expect(catalog!.schemaVersion, 1);
      expect(catalog.pages, hasLength(2));
      expect(catalog.pages[0].count, 5);
      expect(catalog.pages[1].active, isTrue);
    });

    test("returns null on network error", () async {
      final dio = Dio(BaseOptions())..httpClientAdapter = _ErrorAdapter();
      final container = _createContainer(dio: dio);
      final service = container.read(announcementRemoteServiceProvider);

      final catalog = await service.fetchCatalog();
      expect(catalog, isNull);
    });

    test("returns null when remote content is disabled", () async {
      final container = _createContainer(remoteEnabled: false);
      final service = container.read(announcementRemoteServiceProvider);

      final catalog = await service.fetchCatalog();
      expect(catalog, isNull);
    });

    test("returns null on origin parse failure", () async {
      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(
            _testAppSetting().copyWith(
              remoteContent: const RemoteContentSetting(originUrl: "", channel: _defaultChannel),
            ),
          ),
          announcementRemoteServiceProvider.overrideWith(
            (ref) => AnnouncementRemoteService(ref: ref, dio: Dio(BaseOptions())),
          ),
        ],
      );
      addTearDown(container.dispose);
      final service = container.read(announcementRemoteServiceProvider);

      final catalog = await service.fetchCatalog();
      expect(catalog, isNull);
    });

    test("returns null for unsupported schema version", () async {
      final dio = Dio(BaseOptions())..httpClientAdapter = _UnsupportedSchemaAdapter();
      final container = _createContainer(dio: dio);
      final service = container.read(announcementRemoteServiceProvider);

      final catalog = await service.fetchCatalog();
      expect(catalog, isNull);
    });

    test("invalidateCache deletes announcement shared cache entries", () async {
      final adapter = _SuccessAdapter();
      final dio = _createCachingDio(adapter);
      final container = _createContainer(dio: dio);
      final service = container.read(announcementRemoteServiceProvider);

      const pageUuid = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
      final endpoint = RemoteContentEndpoint(
        originUri: Uri.parse(_defaultOriginUrl),
        channel: _defaultChannel,
      );
      final catalogUri = endpoint.announcementV2CatalogUri.toString();
      final pageUri = endpoint.announcementV2PageUri(pageUuid).toString();

      // First fetch populates the shared cache.
      expect(await service.fetchCatalog(), isNotNull);
      expect(await service.fetchPage(pageUuid), isNotNull);
      expect(await RemoteCache.store.getFromPath(RegExp(_urlPattern(catalogUri))), isNotEmpty);
      expect(await RemoteCache.store.getFromPath(RegExp(_urlPattern(pageUri))), isNotEmpty);
      expect(adapter.unconditionalRequests, 2);

      // With cache entries intact a refetch only revalidates via ETag and
      // issues no new unconditional adapter request.
      expect(await service.fetchCatalog(), isNotNull);
      expect(adapter.unconditionalRequests, 2);

      // After invalidation the announcement entries are gone and refetching
      // issues fresh unconditional adapter requests again.
      await service.invalidateCache();
      expect(await RemoteCache.store.getFromPath(RegExp(_urlPattern(catalogUri))), isEmpty);
      expect(await RemoteCache.store.getFromPath(RegExp(_urlPattern(pageUri))), isEmpty);

      expect(await service.fetchCatalog(), isNotNull);
      expect(await service.fetchPage(pageUuid), isNotNull);
      expect(adapter.unconditionalRequests, 4);
    });

    test("invalidateCache keeps non-announcement shared cache entries", () async {
      final adapter = _SuccessAdapter();
      final dio = _createCachingDio(adapter);
      final container = _createContainer(dio: dio);
      final service = container.read(announcementRemoteServiceProvider);

      const pageUuid = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
      final endpoint = RemoteContentEndpoint(
        originUri: Uri.parse(_defaultOriginUrl),
        channel: _defaultChannel,
      );
      final catalogUri = endpoint.announcementV2CatalogUri.toString();
      final pageUri = endpoint.announcementV2PageUri(pageUuid).toString();
      const manifestIndexUrl = "https://cdn.example.com/efa/v2/manifest/index.json";

      // Populate announcement and non-announcement cache entries.
      expect(await service.fetchCatalog(), isNotNull);
      expect(await service.fetchPage(pageUuid), isNotNull);
      await dio.getUri<String>(
        Uri.parse(manifestIndexUrl),
        options: RemoteCache.options.toOptions().copyWith(responseType: ResponseType.plain),
      );

      // After scoped invalidation only announcement entries are removed.
      await service.invalidateCache();
      expect(await RemoteCache.store.getFromPath(RegExp(_urlPattern(catalogUri))), isEmpty);
      expect(await RemoteCache.store.getFromPath(RegExp(_urlPattern(pageUri))), isEmpty);
      expect(
        await RemoteCache.store.getFromPath(RegExp(_urlPattern(manifestIndexUrl))),
        isNotEmpty,
      );
    });
  });

  group("AnnouncementRemoteService fetchPage", () {
    test("returns AnnouncementPage on success", () async {
      final dio = Dio(BaseOptions())..httpClientAdapter = _SuccessAdapter();
      final container = _createContainer(dio: dio);
      final service = container.read(announcementRemoteServiceProvider);

      final page = await service.fetchPage("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
      expect(page, isNotNull);
      expect(page!.uuid, "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
      expect(page.entries, hasLength(1));
      expect(page.entries.first.id, "test-entry");
      expect(page.entries.first.localizations["en"]!.title, "Test Entry");
    });

    test("fetches active page URI when active=true", () async {
      final dio = Dio(BaseOptions())..httpClientAdapter = _SuccessAdapter();
      final container = _createContainer(dio: dio);
      final service = container.read(announcementRemoteServiceProvider);

      final page = await service.fetchPage("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", active: true);
      expect(page, isNotNull);
      expect(page!.uuid, "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
    });

    test("returns null on network error", () async {
      final dio = Dio(BaseOptions())..httpClientAdapter = _ErrorAdapter();
      final container = _createContainer(dio: dio);
      final service = container.read(announcementRemoteServiceProvider);

      final page = await service.fetchPage("some-uuid");
      expect(page, isNull);
    });

    test("returns null when remote content is disabled", () async {
      final container = _createContainer(remoteEnabled: false);
      final service = container.read(announcementRemoteServiceProvider);

      final page = await service.fetchPage("some-uuid");
      expect(page, isNull);
    });
  });

  group("AnnouncementRemoteService fetchBody", () {
    setUp(() {
      final cacheDir = Directory("$tempDir/announcements/bodies");
      if (cacheDir.existsSync()) {
        cacheDir.deleteSync(recursive: true);
      }
    });

    test("returns cached content on cache hit", () async {
      await AnnouncementBodyCache.put(_bodyHash, "cached content");

      final container = _createContainer();
      final service = container.read(announcementRemoteServiceProvider);

      final body = await service.fetchBody(_bodyHash);
      expect(body, "cached content");
    });

    test("fetches from network on cache miss and caches result", () async {
      final dio = Dio(BaseOptions())..httpClientAdapter = _SuccessAdapter();
      final container = _createContainer(dio: dio);
      final service = container.read(announcementRemoteServiceProvider);

      final body = await service.fetchBody(_bodyHash);
      expect(body, _sampleBodyContent);

      // Verify it was cached
      final cached = await AnnouncementBodyCache.get(_bodyHash);
      expect(cached, _sampleBodyContent);
    });

    test("returns null on network error", () async {
      final dio = Dio(BaseOptions())..httpClientAdapter = _ErrorAdapter();
      final container = _createContainer(dio: dio);
      final service = container.read(announcementRemoteServiceProvider);

      final body = await service.fetchBody(_bodyHash);
      expect(body, isNull);
    });

    test("returns null on 404 response", () async {
      final dio = Dio(BaseOptions())..httpClientAdapter = _NotFoundAdapter();
      final container = _createContainer(dio: dio);
      final service = container.read(announcementRemoteServiceProvider);

      final body = await service.fetchBody(_bodyHash);
      expect(body, isNull);
    });

    test("returns null when remote content is disabled", () async {
      final container = _createContainer(remoteEnabled: false);
      final service = container.read(announcementRemoteServiceProvider);

      final body = await service.fetchBody(_bodyHash);
      expect(body, isNull);
    });
  });
}
