import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/storage/repo/announcement_sync.dart";
import "package:eve_fit_assistant/storage/repo/models/announcement.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;

class _MockHttpAdapter implements HttpClientAdapter {
  _MockHttpAdapter(this._responses);

  final Map<String, ({int statusCode, Object? data})> _responses;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    final response = _responses[url];
    if (response == null) {
      throw DioException(requestOptions: options, message: "No mock for $url");
    }
    final body = response.data is String ? response.data as String : jsonEncode(response.data);
    return ResponseBody.fromString(
      body,
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _originUrl = "https://example.com";

String _route(Channel channel, String path) => "$_originUrl/efa/v2/${channel.value}/$path";

AnnouncementSyncService _createService(Dio dio, {String? localIndexPath}) =>
    AnnouncementSyncService(
      remoteCatalogService: RemoteCatalogService(dio: dio, originUrl: _originUrl),
      localIndexPath: localIndexPath ?? RepoPaths.runtimeAnnouncementsPath,
      supportedLocales: IList(const ["zh", "en"]),
    );

void main() {
  late String tempDir;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_async_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_async_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    EtagCache.init();
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("AnnouncementSyncService sync", () {
    test("new announcement: record + content persisted, isRead = false", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: {"manifestVersion": 1, "activatedGeneration": "gen_1"},
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/announcements/catalog.json"): (
          statusCode: 200,
          data: {
            "announcementsVersion": 1,
            "announcements": {
              "ann-001": {
                "id": "ann-001",
                "firstPublishedAt": "2026-01-01T00:00:00Z",
                "updatedAt": "2026-01-02T00:00:00Z",
                "contentHash": "hash-001",
                "isVersionUpdate": false,
              },
            },
          },
        ),
        _route(Channel.stable, "announcements/registry/ann-001.json"): (
          statusCode: 200,
          data: {
            "id": "ann-001",
            "firstPublishedAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-02T00:00:00Z",
            "contentHash": "hash-001",
            "recordVersion": 1,
            "title": {"en": "Hello", "zh": "你好"},
            "excerpt": {"en": "Summary"},
            "tags": ["update"],
            "isVersionUpdate": false,
          },
        ),
        _route(Channel.stable, "announcements/files/zh/ann-001"): (statusCode: 200, data: "# 你好世界"),
        _route(Channel.stable, "announcements/files/en/ann-001"): (
          statusCode: 200,
          data: "# Hello World",
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.sync(Channel.stable);
      expect(result.isRight(), isTrue);
      final changedIds = result.getRight().toNullable()!;
      expect(changedIds, IList(["ann-001"]));

      final index = service.readLocalIndex();
      expect(index.isSome(), isTrue);
      expect(index.toNullable()!.records.length, 1);
      expect(index.toNullable()!.records.first.id, "ann-001");
      expect(index.toNullable()!.records.first.contentHash, "hash-001");
      expect(index.toNullable()!.records.first.isRead, false);

      final record = service.readLocalRecord("ann-001");
      expect(record.isSome(), isTrue);
      expect(record.toNullable()!.id, "ann-001");
      expect(record.toNullable()!.title["en"], "Hello");
      expect(record.toNullable()!.title["zh"], "你好");

      final enContent = service.readLocalContent("en", "ann-001");
      expect(enContent, const Some("# Hello World"));
      final zhContent = service.readLocalContent("zh", "ann-001");
      expect(zhContent, const Some("# 你好世界"));
    });

    test("changed contentHash: record + content updated, isRead reset", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: {"manifestVersion": 1, "activatedGeneration": "gen_1"},
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/announcements/catalog.json"): (
          statusCode: 200,
          data: {
            "announcementsVersion": 1,
            "announcements": {
              "ann-001": {
                "id": "ann-001",
                "firstPublishedAt": "2026-01-01T00:00:00Z",
                "updatedAt": "2026-01-03T00:00:00Z",
                "contentHash": "hash-002",
                "isVersionUpdate": true,
              },
            },
          },
        ),
        _route(Channel.stable, "announcements/registry/ann-001.json"): (
          statusCode: 200,
          data: {
            "id": "ann-001",
            "firstPublishedAt": "2026-01-01T00:00:00Z",
            "updatedAt": "2026-01-03T00:00:00Z",
            "contentHash": "hash-002",
            "recordVersion": 2,
            "title": {"en": "Updated", "zh": "更新"},
            "excerpt": {"en": "Updated summary"},
            "tags": ["important"],
            "isVersionUpdate": true,
          },
        ),
        _route(Channel.stable, "announcements/files/zh/ann-001"): (statusCode: 200, data: "# 更新内容"),
        _route(Channel.stable, "announcements/files/en/ann-001"): (
          statusCode: 200,
          data: "# Updated Content",
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      // Write local index with old contentHash and isRead = true
      service.writeLocalIndex(
        AnnouncementIndex(
          schemaVersion: 2,
          records: IList([
            AnnouncementIndexEntry(
              id: "ann-001",
              contentHash: "hash-001",
              isVersionUpdate: false,
              isRead: true,
            ),
          ]),
        ),
      );
      service.writeLocalRecord(
        AnnouncementRecord(
          id: "ann-001",
          firstPublishedAt: "2026-01-01T00:00:00Z",
          updatedAt: "2026-01-02T00:00:00Z",
          contentHash: "hash-001",
          title: IMap<String, String>({"en": "Old"}),
          isVersionUpdate: false,
        ),
      );
      service.writeLocalContent("en", "ann-001", "# Old Content");

      final result = await service.sync(Channel.stable);
      expect(result.isRight(), isTrue);
      final changedIds = result.getRight().toNullable()!;
      expect(changedIds, IList(["ann-001"]));

      final index = service.readLocalIndex();
      expect(index.toNullable()!.records.first.contentHash, "hash-002");
      expect(index.toNullable()!.records.first.isRead, false);
      expect(index.toNullable()!.records.first.isVersionUpdate, true);

      final record = service.readLocalRecord("ann-001");
      expect(record.toNullable()!.title["en"], "Updated");

      final enContent = service.readLocalContent("en", "ann-001");
      expect(enContent, const Some("# Updated Content"));
    });

    test("unchanged announcement: no re-download, local record preserved", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: {"manifestVersion": 1, "activatedGeneration": "gen_1"},
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/announcements/catalog.json"): (
          statusCode: 200,
          data: {
            "announcementsVersion": 1,
            "announcements": {
              "ann-001": {
                "id": "ann-001",
                "firstPublishedAt": "2026-01-01T00:00:00Z",
                "updatedAt": "2026-01-02T00:00:00Z",
                "contentHash": "hash-static",
                "isVersionUpdate": false,
              },
            },
          },
        ),
        // No mock for registry or files — sync should not fetch these
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      service.writeLocalIndex(
        AnnouncementIndex(
          schemaVersion: 2,
          records: IList([
            AnnouncementIndexEntry(
              id: "ann-001",
              contentHash: "hash-static",
              isVersionUpdate: false,
              isRead: true,
            ),
          ]),
        ),
      );
      service.writeLocalRecord(
        AnnouncementRecord(
          id: "ann-001",
          firstPublishedAt: "2026-01-01T00:00:00Z",
          updatedAt: "2026-01-02T00:00:00Z",
          contentHash: "hash-static",
          title: IMap<String, String>({"en": "Existing"}),
        ),
      );
      service.writeLocalContent("en", "ann-001", "# Existing Content");

      final result = await service.sync(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!, IList<String>.empty());

      final index = service.readLocalIndex();
      expect(index.toNullable()!.records.first.isRead, true);
      expect(index.toNullable()!.records.first.contentHash, "hash-static");

      final record = service.readLocalRecord("ann-001");
      expect(record.toNullable()!.title["en"], "Existing");
    });

    test("empty remote catalog: no changes to local storage", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: {"manifestVersion": 1, "activatedGeneration": "gen_1"},
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/announcements/catalog.json"): (
          statusCode: 200,
          data: {"announcementsVersion": 1, "announcements": <String, dynamic>{}},
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      // Pre-populate some local data
      service.writeLocalIndex(
        AnnouncementIndex(
          schemaVersion: 2,
          records: IList([
            AnnouncementIndexEntry(
              id: "ann-001",
              contentHash: "h1",
              isVersionUpdate: false,
              isRead: true,
            ),
          ]),
        ),
      );

      final result = await service.sync(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!, IList<String>.empty());

      // Local data unchanged
      final index = service.readLocalIndex();
      expect(index.toNullable()!.records.length, 1);
      expect(index.toNullable()!.records.first.id, "ann-001");
    });

    test("network error returns AnnouncementSyncNetworkError", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (statusCode: 500, data: "not json"),
      });

      final service = _createService(dio);

      final result = await service.sync(Channel.stable);
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable()!, isA<AnnouncementSyncNetworkError>());
    });

    test("catalog fetch error returns AnnouncementSyncNetworkError", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: {"manifestVersion": 1, "activatedGeneration": "gen_1"},
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/announcements/catalog.json"): (
          statusCode: 404,
          data: "Not Found",
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.sync(Channel.stable);
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable()!, isA<AnnouncementSyncNetworkError>());
    });
  });

  group("AnnouncementSyncService local I/O", () {
    test("readLocalIndex returns None when file does not exist", () {
      final service = _createService(Dio());
      expect(service.readLocalIndex(), const None());
    });

    test("writeLocalIndex then readLocalIndex round-trip", () {
      final service = _createService(Dio());
      final entry = AnnouncementIndexEntry(
        id: "ann-001",
        contentHash: "abc123",
        isVersionUpdate: true,
        isRead: false,
      );
      final index = AnnouncementIndex(schemaVersion: 2, records: IList([entry]));
      service.writeLocalIndex(index);

      final restored = service.readLocalIndex();
      expect(restored.isSome(), isTrue);
      expect(restored.toNullable()!.records.length, 1);
      expect(restored.toNullable()!.records.first.id, "ann-001");
      expect(restored.toNullable()!.records.first.contentHash, "abc123");
    });

    test("no .tmp file remains after writeLocalIndex", () {
      final service = _createService(Dio());
      service.writeLocalIndex(AnnouncementIndex(schemaVersion: 2));

      final tmpFile = File("${service.localIndexPath}/index.json.tmp");
      expect(tmpFile.existsSync(), isFalse);
    });

    test("readLocalRecord returns None when file does not exist", () {
      final service = _createService(Dio());
      expect(service.readLocalRecord("nonexistent"), const None());
    });

    test("writeLocalRecord then readLocalRecord round-trip", () {
      final service = _createService(Dio());
      final record = AnnouncementRecord(
        id: "ann-001",
        firstPublishedAt: "2026-01-01T00:00:00Z",
        updatedAt: "2026-01-02T00:00:00Z",
        contentHash: "hash-001",
        title: IMap<String, String>({"en": "Title"}),
        isVersionUpdate: true,
      );
      service.writeLocalRecord(record);

      final restored = service.readLocalRecord("ann-001");
      expect(restored.isSome(), isTrue);
      expect(restored.toNullable()!.id, "ann-001");
      expect(restored.toNullable()!.title["en"], "Title");
      expect(restored.toNullable()!.isVersionUpdate, isTrue);
    });

    test("writeLocalContent then readLocalContent round-trip", () {
      final service = _createService(Dio());
      service.writeLocalContent("en", "ann-001", "# Test Content");

      final content = service.readLocalContent("en", "ann-001");
      expect(content, const Some("# Test Content"));
    });

    test("readLocalContent returns None for missing file", () {
      final service = _createService(Dio());
      expect(service.readLocalContent("en", "nonexistent"), const None());
    });
  });

  group("AnnouncementSyncService multiple announcements", () {
    test("sync handles mix of new, changed, and unchanged announcements", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: {"manifestVersion": 1, "activatedGeneration": "gen_1"},
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/announcements/catalog.json"): (
          statusCode: 200,
          data: {
            "announcementsVersion": 1,
            "announcements": {
              "ann-001": {
                "id": "ann-001",
                "firstPublishedAt": "2026-01-01T00:00:00Z",
                "updatedAt": "2026-01-01T00:00:00Z",
                "contentHash": "hash-unchanged",
                "isVersionUpdate": false,
              },
              "ann-002": {
                "id": "ann-002",
                "firstPublishedAt": "2026-01-02T00:00:00Z",
                "updatedAt": "2026-01-02T00:00:00Z",
                "contentHash": "hash-new",
                "isVersionUpdate": false,
              },
              "ann-003": {
                "id": "ann-003",
                "firstPublishedAt": "2026-01-03T00:00:00Z",
                "updatedAt": "2026-01-03T00:00:00Z",
                "contentHash": "hash-changed",
                "isVersionUpdate": true,
              },
            },
          },
        ),
        _route(Channel.stable, "announcements/registry/ann-002.json"): (
          statusCode: 200,
          data: {
            "id": "ann-002",
            "firstPublishedAt": "2026-01-02T00:00:00Z",
            "updatedAt": "2026-01-02T00:00:00Z",
            "contentHash": "hash-new",
            "recordVersion": 1,
            "title": {"en": "New"},
            "tags": <String>[],
            "isVersionUpdate": false,
          },
        ),
        _route(Channel.stable, "announcements/files/zh/ann-002"): (statusCode: 200, data: "# 新公告"),
        _route(Channel.stable, "announcements/files/en/ann-002"): (
          statusCode: 200,
          data: "# New Announcement",
        ),
        _route(Channel.stable, "announcements/registry/ann-003.json"): (
          statusCode: 200,
          data: {
            "id": "ann-003",
            "firstPublishedAt": "2026-01-03T00:00:00Z",
            "updatedAt": "2026-01-03T00:00:00Z",
            "contentHash": "hash-changed",
            "recordVersion": 2,
            "title": {"en": "Updated"},
            "tags": <String>[],
            "isVersionUpdate": true,
          },
        ),
        _route(Channel.stable, "announcements/files/zh/ann-003"): (statusCode: 200, data: "# 更新"),
        _route(Channel.stable, "announcements/files/en/ann-003"): (
          statusCode: 200,
          data: "# Updated",
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      // Pre-populate local data for ann-001 (unchanged) and ann-003 (will change)
      service.writeLocalIndex(
        AnnouncementIndex(
          schemaVersion: 2,
          records: IList([
            AnnouncementIndexEntry(
              id: "ann-001",
              contentHash: "hash-unchanged",
              isVersionUpdate: false,
              isRead: true,
            ),
            AnnouncementIndexEntry(
              id: "ann-003",
              contentHash: "hash-old",
              isVersionUpdate: false,
              isRead: true,
            ),
          ]),
        ),
      );

      final result = await service.sync(Channel.stable);
      expect(result.isRight(), isTrue);
      final changedIds = result.getRight().toNullable()!;
      expect(changedIds.length, 2);
      expect(changedIds.contains("ann-002"), true);
      expect(changedIds.contains("ann-003"), true);
      expect(changedIds.contains("ann-001"), false);

      final index = service.readLocalIndex().toNullable()!;
      expect(index.records.length, 3);

      // ann-001 unchanged, isRead preserved
      final ann1 = index.records.firstWhere((e) => e.id == "ann-001");
      expect(ann1.isRead, true);

      // ann-002 new, isRead false
      final ann2 = index.records.firstWhere((e) => e.id == "ann-002");
      expect(ann2.isRead, false);
      expect(ann2.contentHash, "hash-new");

      // ann-003 changed, isRead reset
      final ann3 = index.records.firstWhere((e) => e.id == "ann-003");
      expect(ann3.isRead, false);
      expect(ann3.contentHash, "hash-changed");
      expect(ann3.isVersionUpdate, true);
    });
  });

  group("AnnouncementSyncService with testing channel", () {
    test("sync works with testing channel", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.testing, "manifest/index.json"): (
          statusCode: 200,
          data: {"manifestVersion": 1, "activatedGeneration": "gen_test"},
        ),
        _route(Channel.testing, "manifest/.generations/gen_test/announcements/catalog.json"): (
          statusCode: 200,
          data: {"announcementsVersion": 1, "announcements": <String, dynamic>{}},
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.sync(Channel.testing);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!, IList<String>.empty());
    });
  });

  group("AnnouncementSyncError types", () {
    test("AnnouncementSyncNetworkError holds message", () {
      const error = AnnouncementSyncNetworkError(message: "Connection refused");
      expect(error.message, "Connection refused");
    });

    test("AnnouncementSyncStorageError holds message", () {
      const error = AnnouncementSyncStorageError(message: "Disk full");
      expect(error.message, "Disk full");
    });

    test("both are AnnouncementSyncError subtypes", () {
      const netErr = AnnouncementSyncNetworkError(message: "x");
      const storeErr = AnnouncementSyncStorageError(message: "x");
      expect(netErr, isA<AnnouncementSyncError>());
      expect(storeErr, isA<AnnouncementSyncError>());
    });
  });
}
