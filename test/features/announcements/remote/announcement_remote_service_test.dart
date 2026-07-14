import "dart:io";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/features/announcements/remote/announcement_remote_service.dart";
import "package:eve_fit_assistant/features/announcements/remote/body_cache.dart";
import "package:eve_fit_assistant/features/remote_content/endpoint.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
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
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    String body;
    if (path.endsWith("/catalog.json")) {
      body = _sampleCatalogJson;
    } else if (path == "/efa/v2/announcements/active.json" ||
        path.startsWith("/efa/v2/announcements/pages/")) {
      body = _samplePageJson;
    } else if (path.startsWith("/efa/v2/announcements/documents/")) {
      body = _sampleBodyContent;
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

/// Adapter that honors conditional requests: answers 304 when the client
/// sends a matching `If-None-Match` header and 200 otherwise. Tracks how many
/// times each resource was fetched so tests can assert whether a request
/// actually reached the network.
class _ConditionalAdapter implements HttpClientAdapter {
  static const String etag = '"test-etag"';

  int catalogFetchCount = 0;
  int pageFetchCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final String body;
    if (path.endsWith("/catalog.json")) {
      catalogFetchCount++;
      body = _sampleCatalogJson;
    } else if (path == "/efa/v2/announcements/active.json" ||
        path.startsWith("/efa/v2/announcements/pages/")) {
      pageFetchCount++;
      body = _samplePageJson;
    } else {
      return ResponseBody.fromString("", 404);
    }
    if (_ifNoneMatch(options) == etag) {
      return ResponseBody.fromString("", 304);
    }
    return ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        "etag": [etag],
      },
    );
  }

  static String? _ifNoneMatch(RequestOptions options) {
    for (final MapEntry<String, dynamic> entry in options.headers.entries) {
      if (entry.key.toLowerCase() == "if-none-match") {
        return entry.value?.toString();
      }
    }
    return null;
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

void main() {
  late String tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync("efa_rsvc_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.cachesPath = tempDir;
    EtagCache.init();
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

    test("invalidateCache clears catalog and page caches", () async {
      final adapter = _ConditionalAdapter();
      final dio = Dio(BaseOptions())..httpClientAdapter = adapter;
      final container = _createContainer(dio: dio);
      final service = container.read(announcementRemoteServiceProvider);

      const pageUuid = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";

      // Start from a clean persisted cache so the test is deterministic
      // regardless of entries left behind by earlier tests.
      EtagCache.clearAll();

      // First fetch populates the in-memory caches and the persisted ETag
      // entries.
      expect(await service.fetchCatalog(), isNotNull);
      expect(await service.fetchPage(pageUuid), isNotNull);
      expect(adapter.catalogFetchCount, 1);
      expect(adapter.pageFetchCount, 1);

      // A second fetch sends conditional headers and is answered 304; the
      // in-memory caches satisfy it with exactly one network call each.
      expect(await service.fetchCatalog(), isNotNull);
      expect(await service.fetchPage(pageUuid), isNotNull);
      expect(adapter.catalogFetchCount, 2);
      expect(adapter.pageFetchCount, 2);

      // Drop the persisted payloads so only the service's in-memory caches
      // could satisfy a 304; keep the ETags so requests stay conditional.
      final endpoint = RemoteContentEndpoint(
        originUri: Uri.parse(_defaultOriginUrl),
        channel: _defaultChannel,
      );
      EtagCache.clearAll();
      EtagCache.update(endpoint.announcementV2CatalogUri, etag: _ConditionalAdapter.etag);
      EtagCache.update(endpoint.announcementV2PageUri(pageUuid), etag: _ConditionalAdapter.etag);

      service.invalidateCache();

      // With the in-memory caches cleared, each 304 has no payload to fall
      // back to, forcing an unconditional retry: two additional network
      // calls per resource instead of one. If invalidateCache() failed to
      // clear a cache, the stale payload would answer the 304 and the count
      // would be one lower.
      final catalog = await service.fetchCatalog();
      final page = await service.fetchPage(pageUuid);
      expect(catalog, isNotNull);
      expect(page, isNotNull);
      expect(adapter.catalogFetchCount, 4);
      expect(adapter.pageFetchCount, 4);
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
