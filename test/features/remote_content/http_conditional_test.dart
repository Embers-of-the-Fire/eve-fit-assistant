import "dart:io";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/features/remote_content/http.dart";
import "package:flutter_test/flutter_test.dart";

/// Records every request and returns a canned response.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.status = 200, this.body = "{}", this.responseHeaders = const {}});

  final int status;
  final String body;
  final Map<String, List<String>> responseHeaders;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return ResponseBody.fromString(body, status, headers: responseHeaders);
  }

  @override
  void close({bool force = false}) {}
}

String? _header(RequestOptions options, String name) {
  for (final entry in options.headers.entries) {
    if (entry.key.toLowerCase() == name.toLowerCase()) return entry.value?.toString();
  }
  return null;
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    GlobalLogger.init(
      Directory.systemTemp.createTempSync("efa_http_log_").path,
      enableDebugLog: false,
    );
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync("efa_http_test_");
    PathProvider.documentsPath = tempDir.path;
    EtagCache.init();
    EtagCache.clearAll();
    await EtagCache.flush();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group("getRemoteUri sendConditionalHeaders", () {
    test("false: no conditional header sent and cache not updated", () async {
      final uri = Uri.parse("https://example.com/blob");
      EtagCache.update(uri, etag: '"old"');

      final adapter = _RecordingAdapter(
        body: "payload",
        responseHeaders: {
          "etag": ['"new"'],
        },
      );
      final dio = Dio()..httpClientAdapter = adapter;

      final result = await getRemoteUri<String>(dio, uri, sendConditionalHeaders: false);

      expect(result.notModified, isFalse);
      expect(_header(adapter.requests.single, "If-None-Match"), isNull);
      // Response ETag must NOT be recorded back into the cache.
      expect(EtagCache.getEtag(uri), '"old"');
    });

    test("true (default): sends If-None-Match and records response ETag", () async {
      final uri = Uri.parse("https://example.com/meta.json");
      EtagCache.update(uri, etag: '"old"');

      final adapter = _RecordingAdapter(
        responseHeaders: {
          "etag": ['"fresh"'],
        },
      );
      final dio = Dio()..httpClientAdapter = adapter;

      await getRemoteUri<String>(dio, uri);

      expect(_header(adapter.requests.single, "If-None-Match"), '"old"');
      expect(EtagCache.getEtag(uri), '"fresh"');
    });
  });

  group("fetchRemoteJson on 304", () {
    test("returns cachedPayload without warning or retry", () async {
      final uri = Uri.parse("https://example.com/meta.json");
      final adapter = _RecordingAdapter(status: 304);
      final dio = Dio()..httpClientAdapter = adapter;

      final cached = {"schemaVersion": 1, "hello": "world"};
      final result = await fetchRemoteJson(dio, uri, cachedPayload: cached);

      expect(result, cached);
      // Exactly one request: no destructive ETag clear + unconditional refetch.
      expect(adapter.requests.length, 1);
    });
  });
}
