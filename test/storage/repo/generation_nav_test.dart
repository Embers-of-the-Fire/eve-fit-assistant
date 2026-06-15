import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/storage/repo/generation_nav.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
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

GenerationNavigationService _createService(Dio dio) => GenerationNavigationService(
  remoteCatalogService: RemoteCatalogService(dio: dio, originUrl: _originUrl),
);

Map<String, dynamic> _manifestJson(String genId) => {
  "manifestVersion": 1,
  "activatedGeneration": genId,
};

Map<String, dynamic> _generationsJson(Map<String, Map<String, dynamic>> gens) => {
  "generations": gens,
};

Map<String, dynamic> _genEntry(String id, {String? description}) => {
  "id": id,
  "createdAt": "2026-01-01T00:00:00Z",
  "description": description ?? "Generation $id",
};

Map<String, dynamic> _resourcesCatalogJson(Map<String, Map<String, dynamic>> servers) => {
  "resourcesVersion": 1,
  "servers": servers,
};

Map<String, dynamic> _serverEntry({String? name}) => {
  "lastUpdatedAt": "2026-02-01T00:00:00Z",
  "name": name != null ? {"en": name, "zh": name} : {"en": "Test Server", "zh": "Test Server"},
};

Map<String, dynamic> _serverCatalogJson({
  required String id,
  List<Map<String, dynamic>>? checkouts,
}) => {
  "id": id,
  "lastUpdatedAt": "2026-03-01T00:00:00Z",
  "metadata": {"gameServer": "serenity", "gameBuild": "12345", "gameVersion": "1.0"},
  "name": {"en": "Test Server", "zh": "Test Server"},
  "checkouts": checkouts ?? [],
};

Map<String, dynamic> _checkoutEntry(String id) => {
  "id": id,
  "createdAt": "2026-04-01T00:00:00Z",
  "metadata": {"gameServer": "serenity", "gameBuild": "12345", "gameVersion": "1.0"},
};

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_gnav_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    final tempDir = Directory.systemTemp.createTempSync("efa_gnav_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    EtagCache.init();
  });

  group("GenerationNavigationService fetchTree", () {
    test("returns correct activatedGeneration, generations, and servers", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_2"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/generations.json"): (
          statusCode: 200,
          data: _generationsJson({
            "gen_1": _genEntry("gen_1"),
            "gen_2": _genEntry("gen_2", description: "Current stable"),
            "gen_3": _genEntry("gen_3", description: "Next release"),
          }),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_2/resources/catalog.json"): (
          statusCode: 200,
          data: _resourcesCatalogJson({
            "srv_alpha": _serverEntry(name: "Alpha"),
            "srv_beta": _serverEntry(name: "Beta"),
          }),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.fetchTree(Channel.stable);
      expect(result.isRight(), isTrue);

      final tree = result.getRight().toNullable()!;
      expect(tree.activatedGeneration, "gen_2");
      expect(tree.generations.length, 3);
      expect(tree.generations.map((g) => g.id), containsAll(["gen_1", "gen_2", "gen_3"]));
      expect(tree.servers.length, 2);
      expect(tree.servers.map((s) => s.serverId), containsAll(["srv_alpha", "srv_beta"]));

      final alpha = tree.servers.firstWhere((s) => s.serverId == "srv_alpha");
      expect(alpha.lastUpdatedAt, "2026-02-01T00:00:00Z");
      expect(alpha.name["en"], "Alpha");
    });

    test("manifest index failure returns GenerationNavNetworkError", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 500,
          data: "error",
          contentType: Headers.jsonContentType,
        ),
      });

      final service = _createService(dio);

      final result = await service.fetchTree(Channel.stable);
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable()!, isA<GenerationNavNetworkError>());
    });

    test("generations index failure returns GenerationNavNetworkError", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/generations.json"): (
          statusCode: 404,
          data: "Not Found",
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.fetchTree(Channel.stable);
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable()!, isA<GenerationNavNetworkError>());
    });

    test("resources catalog failure returns GenerationNavNetworkError", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_1"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/generations.json"): (
          statusCode: 200,
          data: _generationsJson({"gen_1": _genEntry("gen_1")}),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_1/resources/catalog.json"): (
          statusCode: 503,
          data: "Service Unavailable",
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.fetchTree(Channel.stable);
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable()!, isA<GenerationNavNetworkError>());
    });

    test("works with testing channel", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.testing, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_test"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.testing, "manifest/generations.json"): (
          statusCode: 200,
          data: _generationsJson({"gen_test": _genEntry("gen_test")}),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.testing, "manifest/.generations/gen_test/resources/catalog.json"): (
          statusCode: 200,
          data: _resourcesCatalogJson({"srv_test": _serverEntry(name: "Test")}),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.fetchTree(Channel.testing);
      expect(result.isRight(), isTrue);

      final tree = result.getRight().toNullable()!;
      expect(tree.activatedGeneration, "gen_test");
      expect(tree.generations.length, 1);
      expect(tree.servers.length, 1);
    });

    test("empty generations and servers", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/index.json"): (
          statusCode: 200,
          data: _manifestJson("gen_empty"),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/generations.json"): (
          statusCode: 200,
          data: _generationsJson(<String, Map<String, dynamic>>{}),
          contentType: Headers.jsonContentType,
        ),
        _route(Channel.stable, "manifest/.generations/gen_empty/resources/catalog.json"): (
          statusCode: 200,
          data: _resourcesCatalogJson(<String, Map<String, dynamic>>{}),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.fetchTree(Channel.stable);
      expect(result.isRight(), isTrue);

      final tree = result.getRight().toNullable()!;
      expect(tree.activatedGeneration, "gen_empty");
      expect(tree.generations.isEmpty, isTrue);
      expect(tree.servers.isEmpty, isTrue);
    });
  });

  group("GenerationNavigationService fetchServerDetail", () {
    test("returns server with checkout list", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/.generations/gen_1/resources/servers/srv_alpha.json"): (
          statusCode: 200,
          data: _serverCatalogJson(
            id: "srv_alpha",
            checkouts: [_checkoutEntry("co_1"), _checkoutEntry("co_2"), _checkoutEntry("co_3")],
          ),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.fetchServerDetail(Channel.stable, "gen_1", "srv_alpha");
      expect(result.isRight(), isTrue);

      final detail = result.getRight().toNullable()!;
      expect(detail.server.id, "srv_alpha");
      expect(detail.server.lastUpdatedAt, "2026-03-01T00:00:00Z");
      expect(detail.checkouts.length, 3);
      expect(detail.checkouts.map((c) => c.id), containsAll(["co_1", "co_2", "co_3"]));
    });

    test("server with no checkouts", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/.generations/gen_1/resources/servers/srv_empty.json"): (
          statusCode: 200,
          data: _serverCatalogJson(id: "srv_empty"),
          contentType: Headers.jsonContentType,
        ),
      });
      dio.options.validateStatus = (status) => true;

      final service = _createService(dio);

      final result = await service.fetchServerDetail(Channel.stable, "gen_1", "srv_empty");
      expect(result.isRight(), isTrue);

      final detail = result.getRight().toNullable()!;
      expect(detail.server.id, "srv_empty");
      expect(detail.checkouts.isEmpty, isTrue);
    });

    test("server catalog failure returns GenerationNavNetworkError", () async {
      final dio = Dio();
      dio.httpClientAdapter = _MockHttpAdapter({
        _route(Channel.stable, "manifest/.generations/gen_1/resources/servers/srv_404.json"): (
          statusCode: 404,
          data: "Not Found",
          contentType: Headers.jsonContentType,
        ),
      });

      final service = _createService(dio);

      final result = await service.fetchServerDetail(Channel.stable, "gen_1", "srv_404");
      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable()!, isA<GenerationNavNetworkError>());
    });
  });

  group("GenerationNavigationService result types", () {
    test("GenerationTree holds required fields", () {
      final tree = GenerationTree(
        activatedGeneration: "gen_1",
        generations: IList<GenerationEntry>.empty(),
        servers: IList<ServerSummary>.empty(),
      );
      expect(tree.activatedGeneration, "gen_1");
      expect(tree.generations.isEmpty, isTrue);
      expect(tree.servers.isEmpty, isTrue);
    });

    test("ServerSummary holds required fields", () {
      final summary = ServerSummary(
        serverId: "srv_1",
        lastUpdatedAt: "2026-01-01T00:00:00Z",
        name: IMap(const {"en": "English", "zh": "中文"}),
      );
      expect(summary.serverId, "srv_1");
      expect(summary.lastUpdatedAt, "2026-01-01T00:00:00Z");
      expect(summary.name["en"], "English");
      expect(summary.name["zh"], "中文");
    });

    test("GenerationServerDetail holds required fields", () {
      final server = GenerationServer.fromJson({
        "id": "srv_test",
        "lastUpdatedAt": "2026-01-01T00:00:00Z",
        "metadata": {"gameServer": "serenity", "gameBuild": "1", "gameVersion": "1.0"},
      });
      final detail = GenerationServerDetail(
        server: server,
        checkouts: IList<GenerationCheckoutEntry>.empty(),
      );
      expect(detail.server.id, "srv_test");
      expect(detail.checkouts.isEmpty, isTrue);
    });

    test("GenerationNavNetworkError holds message", () {
      const error = GenerationNavNetworkError(message: "Test error");
      expect(error.message, "Test error");
      expect(error, isA<GenerationNavError>());
    });
  });
}
