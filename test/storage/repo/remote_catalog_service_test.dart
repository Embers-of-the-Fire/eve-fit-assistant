import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:flutter_test/flutter_test.dart";
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

void main() {
  const originUrl = "https://example.com";

  late String tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_rcat_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");

    EtagCache.init();
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  String _route(Channel channel, String path) => "$originUrl/efa/v2/${channel.value}/$path";

  group("URL construction", () {
    test("fetchManifestIndex uses correct URL for stable channel", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: {"manifestVersion": 1, "activatedGeneration": "gen_1"},
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = RemoteCatalogService(dio: dio, originUrl: originUrl);
      final result = await service.fetchManifestIndex(Channel.stable);

      expect(result.isRight(), isTrue);
    });

    test("fetchGenerations uses correct URL for testing channel", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.testing, "manifest/generations.json"): (
          statusCode: 200,
          data: {"generations": <String, dynamic>{}},
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = RemoteCatalogService(dio: dio, originUrl: originUrl);
      final result = await service.fetchGenerations(Channel.testing);

      expect(result.isRight(), isTrue);
    });

    test("fetchServerCatalog constructs nested generation URL", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/.generations/gen_x/resources/servers/serenity.json"): (
          statusCode: 200,
          data: {
            "id": "serenity",
            "lastUpdatedAt": "2026-01-01T00:00:00Z",
            "metadata": {"gameServer": "Serenity", "gameBuild": "21.06", "gameVersion": "EQUINOX"},
            "name": <String, String>{},
            "checkouts": <Map<String, dynamic>>[],
          },
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = RemoteCatalogService(dio: dio, originUrl: originUrl);
      final result = await service.fetchServerCatalog(Channel.stable, "gen_x", "serenity");

      expect(result.isRight(), isTrue);
    });

    test("fetchCheckoutCatalog uses first 2 chars of hash as prefix", () async {
      final dio = Dio();
      const checkoutHash = "abcdef1234567890abcdef1234567890abcdef12";
      final prefix = checkoutHash.substring(0, 2);

      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/checkouts/$prefix/$checkoutHash.json"): (
          statusCode: 200,
          data: {
            "id": checkoutHash,
            "createdAt": "2026-01-01T00:00:00Z",
            "serverId": "serenity",
            "metadata": {"gameServer": "Serenity", "gameBuild": "21.06", "gameVersion": "EQUINOX"},
            "files": <String, dynamic>{},
          },
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = RemoteCatalogService(dio: dio, originUrl: originUrl);
      final result = await service.fetchCheckoutCatalog(Channel.stable, checkoutHash);

      expect(result.isRight(), isTrue);
    });
  });

  group("error responses", () {
    test("returns CatalogNetworkError on HTTP 500", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 500,
          data: {"error": "Internal Server Error"},
        ),
      });

      final service = RemoteCatalogService(dio: dio, originUrl: originUrl);
      final result = await service.fetchManifestIndex(Channel.stable);

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable()!, isA<CatalogNetworkError>());
    });

    test("returns CatalogNetworkError on HTTP 404", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (statusCode: 404, data: "Not Found"),
      });

      final service = RemoteCatalogService(dio: dio, originUrl: originUrl);
      final result = await service.fetchManifestIndex(Channel.stable);

      expect(result.isLeft(), isTrue);
    });

    test("returns CatalogNetworkError on malformed JSON", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: "not valid json {{{",
        ),
      });

      final service = RemoteCatalogService(dio: dio, originUrl: originUrl);
      final result = await service.fetchManifestIndex(Channel.stable);

      expect(result.isLeft(), isTrue);
    });

    test("returns CatalogNetworkError on JSON array instead of object", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (statusCode: 200, data: [1, 2, 3]),
      });

      final service = RemoteCatalogService(dio: dio, originUrl: originUrl);
      final result = await service.fetchManifestIndex(Channel.stable);

      expect(result.isLeft(), isTrue);
    });
  });

  group("model parsing", () {
    test("ManifestIndex parses from valid JSON", () {
      final json = <String, dynamic>{"manifestVersion": 3, "activatedGeneration": "gen_202601"};
      final index = ManifestIndex.fromJson(json);
      expect(index.manifestVersion, 3);
      expect(index.activatedGeneration, "gen_202601");
    });

    test("GenerationsIndex parses from valid JSON", () {
      final json = <String, dynamic>{
        "generations": {
          "gen_1": <String, dynamic>{
            "id": "gen_1",
            "createdAt": "2026-01-01T00:00:00Z",
            "description": "First",
          },
        },
      };
      final index = GenerationsIndex.fromJson(json);
      expect(index.generations.length, 1);
      expect(index.generations["gen_1"]!.description, "First");
    });

    test("GenerationServer parses from valid JSON", () {
      final json = <String, dynamic>{
        "id": "serenity",
        "lastUpdatedAt": "2026-01-01T00:00:00Z",
        "metadata": {"gameServer": "Serenity", "gameBuild": "21.06", "gameVersion": "EQUINOX"},
        "name": {"en": "Serenity"},
        "checkouts": <Map<String, dynamic>>[],
      };
      final server = GenerationServer.fromJson(json);
      expect(server.id, "serenity");
      expect(server.name["en"], "Serenity");
    });

    test("GenerationCheckoutCatalog parses from valid JSON", () {
      final catalogJson =
          jsonDecode(
                jsonEncode({
                  "id": "hash123",
                  "createdAt": "2026-01-01T00:00:00Z",
                  "serverId": "serenity",
                  "metadata": {
                    "gameServer": "Serenity",
                    "gameBuild": "21.06",
                    "gameVersion": "EQUINOX",
                  },
                  "files": <String, dynamic>{},
                }),
              )
              as Map<String, dynamic>;
      final catalog = GenerationCheckoutCatalog.fromJson(catalogJson);
      expect(catalog.id, "hash123");
      expect(catalog.serverId, "serenity");
    });
  });

  group("CatalogError types", () {
    test("CatalogNetworkError holds message and optional statusCode", () {
      const error = CatalogNetworkError(message: "Connection refused", statusCode: 503);
      expect(error.message, "Connection refused");
      expect(error.statusCode, 503);
    });

    test("CatalogNotFoundError holds message", () {
      const error = CatalogNotFoundError(message: "Resource not found");
      expect(error.message, "Resource not found");
    });

    test("CatalogParseError holds message", () {
      const error = CatalogParseError(message: "Invalid JSON structure");
      expect(error.message, "Invalid JSON structure");
    });
  });
}
