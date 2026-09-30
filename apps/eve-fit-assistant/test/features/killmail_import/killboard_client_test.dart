@TestOn("vm")
library;

import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/killmail_import/killboard_client.dart";
import "package:eve_fit_assistant/features/killmail_import/killboard_server.dart";
import "package:flutter_test/flutter_test.dart";

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._onFetch);

  final Future<ResponseBody> Function(RequestOptions options) _onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _onFetch(options);

  @override
  void close({bool force = false}) {}
}

KillboardClient _clientWith(Future<ResponseBody> Function(RequestOptions) onFetch) =>
    KillboardClient(dio: Dio()..httpClientAdapter = _FakeAdapter(onFetch));

ResponseBody _jsonBody(String body) =>
    ResponseBody.fromString(body, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_kb_client_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  group("KillboardClient.parseKillUrl", () {
    test("parses zKillboard URLs", () {
      expect(
        KillboardClient.parseKillUrl("https://zkillboard.com/kill/126861807/"),
        (KillboardServer.zkillboard, 126861807),
      );
      expect(
        KillboardClient.parseKillUrl("http://www.zkillboard.com/kill/42"),
        (KillboardServer.zkillboard, 42),
      );
      expect(
        KillboardClient.parseKillUrl("zkillboard.com/kill/42/"),
        (KillboardServer.zkillboard, 42),
      );
    });

    test("rejects unknown hosts and non-kill URLs", () {
      expect(KillboardClient.parseKillUrl("https://example.com/kill/42/"), isNull);
      expect(KillboardClient.parseKillUrl("https://kb.ceve-market.org/kill/42/"), isNull);
      expect(KillboardClient.parseKillUrl("https://zkillboard.com/character/42/"), isNull);
      expect(KillboardClient.parseKillUrl("126861807"), isNull);
      expect(KillboardClient.parseKillUrl(""), isNull);
    });
  });

  group("KillboardClient.killmailUriFor", () {
    test("builds the zKillboard API URL", () {
      final client = KillboardClient(dio: Dio());
      expect(
        client.killmailUriFor(KillboardServer.zkillboard, 126861807).toString(),
        "https://zkillboard.com/api/killID/126861807/",
      );
      client.dispose();
    });
  });

  group("KillboardClient.fetchKillmail", () {
    test("parses a successful response", () async {
      final client = _clientWith(
        (options) async => _jsonBody(
          '{"killmail_id": 1, "victim": {"ship_type_id": 638, "items": []}}',
        ),
      );
      final killmail = await client.fetchKillmail(KillboardServer.zkillboard, 1);
      expect(killmail.killmailId, 1);
      expect(killmail.shipTypeId, 638);
      client.dispose();
    });

    test("maps 404 to notFound", () async {
      final client = _clientWith(
        (options) async => throw DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 404),
        ),
      );
      expect(
        () => client.fetchKillmail(KillboardServer.zkillboard, 1),
        throwsA(
          isA<KillboardFetchException>().having(
            (e) => e.code,
            "code",
            KillboardFetchErrorCode.notFound,
          ),
        ),
      );
      client.dispose();
    });

    test("maps 403 to blocked", () async {
      final client = _clientWith(
        (options) async => throw DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 403),
        ),
      );
      expect(
        () => client.fetchKillmail(KillboardServer.zkillboard, 1),
        throwsA(
          isA<KillboardFetchException>().having(
            (e) => e.code,
            "code",
            KillboardFetchErrorCode.blocked,
          ),
        ),
      );
      client.dispose();
    });

    test("maps bot-mitigation HTML challenge pages to blocked", () async {
      final client = _clientWith(
        (options) async => _jsonBody("<html><body>WAF challenge</body></html>"),
      );
      expect(
        () => client.fetchKillmail(KillboardServer.zkillboard, 1),
        throwsA(
          isA<KillboardFetchException>().having(
            (e) => e.code,
            "code",
            KillboardFetchErrorCode.blocked,
          ),
        ),
      );
      client.dispose();
    });

    test("maps malformed JSON to invalidResponse", () async {
      final client = _clientWith((options) async => _jsonBody('{"unexpected": true}'));
      expect(
        () => client.fetchKillmail(KillboardServer.zkillboard, 1),
        throwsA(
          isA<KillboardFetchException>().having(
            (e) => e.code,
            "code",
            KillboardFetchErrorCode.invalidResponse,
          ),
        ),
      );
      client.dispose();
    });

    test("maps network failures to fetchFailed", () async {
      final client = _clientWith(
        (options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
        ),
      );
      expect(
        () => client.fetchKillmail(KillboardServer.zkillboard, 1),
        throwsA(
          isA<KillboardFetchException>().having(
            (e) => e.code,
            "code",
            KillboardFetchErrorCode.fetchFailed,
          ),
        ),
      );
      client.dispose();
    });

    test("maps an empty array response (withheld/unknown killmail) to notFound", () async {
      final client = _clientWith((options) async => _jsonBody("[]"));
      expect(
        () => client.fetchKillmail(KillboardServer.zkillboard, 138806831),
        throwsA(
          isA<KillboardFetchException>().having(
            (e) => e.code,
            "code",
            KillboardFetchErrorCode.notFound,
          ),
        ),
      );
      client.dispose();
    });

    test("maps a JSON error object to fetchFailed", () async {
      final client = _clientWith((options) async => _jsonBody('{"error": "Invalid killID"}'));
      expect(
        () => client.fetchKillmail(KillboardServer.zkillboard, 1),
        throwsA(
          isA<KillboardFetchException>()
              .having((e) => e.code, "code", KillboardFetchErrorCode.fetchFailed)
              .having((e) => e.detail, "detail", "Invalid killID"),
        ),
      );
      client.dispose();
    });
  });
}
