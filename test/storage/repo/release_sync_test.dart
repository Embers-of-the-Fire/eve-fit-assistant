import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/storage/repo/release_sync.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

class _MockHttpAdapter implements HttpClientAdapter {
  _MockHttpAdapter(this._responses);

  final Map<String, ({int statusCode, Object? data, String contentType})> _responses;

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
    final contentType = response.contentType;
    if (contentType == "application/octet-stream") {
      return ResponseBody.fromBytes(
        response.data is Uint8List ? response.data as Uint8List : Uint8List(0),
        response.statusCode,
        headers: {
          Headers.contentTypeHeader: [contentType],
        },
      );
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

ReleaseSyncService _createService(Dio dio, {Future<String> Function()? currentVersionProvider}) =>
    ReleaseSyncService(
      remoteCatalogService: RemoteCatalogService(dio: dio, originUrl: _originUrl),
      currentVersionProvider: currentVersionProvider ?? (() async => "2.0.0+42"),
    );

Map<String, dynamic> _manifestJson(String genId) => {
  "manifestVersion": 1,
  "activatedGeneration": genId,
};

Map<String, dynamic> _releaseCatalogJson(Map<String, Map<String, dynamic>> releases) => {
  "releasesVersion": 1,
  "releases": releases,
};

Map<String, dynamic> _releaseEntry(String version, {List<String>? offering}) => {
  "id": "rls-$version",
  "createdAt": "2026-01-01T00:00:00Z",
  "version": version,
  "offering": offering ?? ["apk"],
};

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_rls_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    final tempDir = Directory.systemTemp.createTempSync("efa_rls_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    EtagCache.init();
  });

  group("ReleaseSyncService check", () {
    test("newer version with apk offering is detected and returned", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
          statusCode: 200,
          data: _releaseCatalogJson({
            "rls-2.1.0": _releaseEntry("2.1.0"),
            "rls-2.0.1": _releaseEntry("2.0.1"),
            "rls-2.0.0": _releaseEntry("2.0.0"),
          }),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.check(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isSome(), isTrue);
      final release = result.getRight().toNullable()!.toNullable()!;
      expect(release.version, "2.1.0");
      expect(release.releaseId, "rls-2.1.0");
    });

    test("equal version returns None", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
          statusCode: 200,
          data: _releaseCatalogJson({
            "rls-2.0.0": _releaseEntry("2.0.0"),
            "rls-1.9.0": _releaseEntry("1.9.0"),
          }),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.check(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isNone(), isTrue);
    });

    test("older version returns None", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
          statusCode: 200,
          data: _releaseCatalogJson({
            "rls-1.9.0": _releaseEntry("1.9.0"),
            "rls-1.8.5": _releaseEntry("1.8.5"),
          }),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio, currentVersionProvider: () async => "2.0.0");

      final result = await service.check(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isNone(), isTrue);
    });

    test("major version bump detected", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
          statusCode: 200,
          data: _releaseCatalogJson({"rls-3.0.0": _releaseEntry("3.0.0")}),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio, currentVersionProvider: () async => "2.9.9");

      final result = await service.check(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isSome(), isTrue);
      expect(result.getRight().toNullable()!.toNullable()!.version, "3.0.0");
    });

    test("minor version bump detected", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
          statusCode: 200,
          data: _releaseCatalogJson({"rls-2.1.0": _releaseEntry("2.1.0")}),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio, currentVersionProvider: () async => "2.0.0");

      final result = await service.check(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isSome(), isTrue);
    });

    test("patch version bump detected", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
          statusCode: 200,
          data: _releaseCatalogJson({"rls-2.0.1": _releaseEntry("2.0.1")}),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio, currentVersionProvider: () async => "2.0.0");

      final result = await service.check(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isSome(), isTrue);
    });

    test(
      "prerelease: release without prerelease is newer than installed with prerelease",
      () async {
        final dio = Dio();
        dio.httpClientAdapter = _MockHttpAdapter({
          _route(Channel.stable, "manifest/index.json"): (
            statusCode: 200,
            data: _manifestJson("gen_1"),
            contentType: Headers.jsonContentType,
          ),
          _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
            statusCode: 200,
            data: _releaseCatalogJson({"rls-2.0.0": _releaseEntry("2.0.0")}),
            contentType: Headers.jsonContentType,
          ),
        });
        dio.options.validateStatus = (status) => true;

        final service = _createService(dio, currentVersionProvider: () async => "2.0.0-rc1");

        final result = await service.check(Channel.stable);
        expect(result.isRight(), isTrue);
        expect(result.getRight().toNullable()!.isSome(), isTrue);
        expect(result.getRight().toNullable()!.toNullable()!.version, "2.0.0");
      },
    );

    test("prerelease: installed full release is newer than prerelease offering", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
          statusCode: 200,
          data: _releaseCatalogJson({"rls-2.0.0-rc2": _releaseEntry("2.0.0-rc2")}),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio, currentVersionProvider: () async => "2.0.0");

      final result = await service.check(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isNone(), isTrue);
    });

    test("no apk offering in any release returns None", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
          statusCode: 200,
          data: _releaseCatalogJson({
            "rls-2.1.0": _releaseEntry("2.1.0", offering: ["playstore"]),
            "rls-2.2.0": _releaseEntry("2.2.0", offering: ["fdroid"]),
          }),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.check(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isNone(), isTrue);
    });

    test("multiple releases, picks newest with apk", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
          statusCode: 200,
          data: _releaseCatalogJson({
            "rls-2.1.0": _releaseEntry("2.1.0", offering: ["playstore"]),
            "rls-2.2.0": _releaseEntry("2.2.0"),
            "rls-2.3.0": _releaseEntry("2.3.0"),
          }),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.check(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isSome(), isTrue);
      expect(result.getRight().toNullable()!.toNullable()!.version, "2.3.0");
    });

    test("empty release catalog returns None", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
          statusCode: 200,
          data: _releaseCatalogJson(<String, Map<String, dynamic>>{}),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.check(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isNone(), isTrue);
    });

    test("manifest fetch error returns ReleaseSyncNetworkError", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 500,
          data: "error",
          contentType: Headers.jsonContentType,
        ),
      });

      final service = _createService(dio);

      final result = await service.check(Channel.stable);
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable()!, isA<ReleaseSyncNetworkError>());
    });

    test("catalog fetch error returns ReleaseSyncNetworkError", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
          statusCode: 404,
          data: "Not Found",
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.check(Channel.stable);
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable()!, isA<ReleaseSyncNetworkError>());
    });

    test("handles v-prefix in installed version", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
          statusCode: 200,
          data: _releaseCatalogJson({"rls-2.1.0": _releaseEntry("2.1.0")}),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio, currentVersionProvider: () async => "v2.0.0");

      final result = await service.check(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isSome(), isTrue);
      expect(result.getRight().toNullable()!.toNullable()!.version, "2.1.0");
    });

    test("strips build metadata from installed version", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/releases/catalog.json"): (
          statusCode: 200,
          data: _releaseCatalogJson({
            "rls-2.0.0": _releaseEntry("2.0.0"),
            "rls-2.0.1": _releaseEntry("2.0.1"),
          }),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio, currentVersionProvider: () async => "2.0.0+42");

      final result = await service.check(Channel.stable);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isSome(), isTrue);
      expect(result.getRight().toNullable()!.toNullable()!.version, "2.0.1");
    });

    test("works with testing channel", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.testing, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_test"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.testing, "manifest/.generations/gen_test/releases/catalog.json"): (
          statusCode: 200,
          data: _releaseCatalogJson({"rls-2.1.0": _releaseEntry("2.1.0")}),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.check(Channel.testing);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!.isSome(), isTrue);
    });
  });

  group("ReleaseSyncService downloadApk", () {
    test("downloads APK bytes successfully", () async {
      const hash = "abcdef1234567890abcdef1234567890abcdef12";
      final prefix = hash.substring(0, 2);
      final apkBytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "resources/releases/$prefix/$hash"): (
          statusCode: 200,
          data: apkBytes,
          contentType: "application/octet-stream",
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.downloadApk(Channel.stable, hash);
      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable()!, apkBytes);
    });

    test("download APK error returns ReleaseSyncNetworkError", () async {
      const hash = "abcdef1234567890abcdef1234567890abcdef12";
      final prefix = hash.substring(0, 2);

      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "resources/releases/$prefix/$hash"): (
          statusCode: 500,
          data: "Server Error",
          contentType: "text/plain",
        ),
      });

      final service = _createService(dio);

      final result = await service.downloadApk(Channel.stable, hash);
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable()!, isA<ReleaseSyncNetworkError>());
    });
  });

  group("AppRelease", () {
    test("creates with required fields", () {
      const release = AppRelease(
        releaseId: "rls-123",
        version: "2.1.0",
        createdAt: "2026-01-01T00:00:00Z",
      );
      expect(release.releaseId, "rls-123");
      expect(release.version, "2.1.0");
      expect(release.createdAt, "2026-01-01T00:00:00Z");
    });
  });

  group("ReleaseSyncError types", () {
    test("ReleaseSyncNetworkError holds message", () {
      const error = ReleaseSyncNetworkError(message: "Connection refused");
      expect(error.message, "Connection refused");
      expect(error, isA<ReleaseSyncError>());
    });

    test("ReleaseSyncVersionParseError holds message", () {
      const error = ReleaseSyncVersionParseError(message: "Invalid version");
      expect(error.message, "Invalid version");
      expect(error, isA<ReleaseSyncError>());
    });
  });
}
