import "dart:io";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/endpoint.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/features/remote_content/http.dart";
import "package:flutter_test/flutter_test.dart";

/// Records every request and returns a canned response.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.status = 200, this.body = "{}", this.responseHeaders = const {}});

  factory _RecordingAdapter.sequence(List<_RecordingResponse> responses) =>
      _SequencedRecordingAdapter(responses);

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

class _RecordingResponse {
  const _RecordingResponse({required this.status, this.body = "{}", this.headers = const {}});

  final int status;
  final String body;
  final Map<String, List<String>> headers;
}

class _SequencedRecordingAdapter extends _RecordingAdapter {
  _SequencedRecordingAdapter(this._responses);

  final List<_RecordingResponse> _responses;
  var _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final response = _responses[_index.clamp(0, _responses.length - 1)];
    if (_index < _responses.length - 1) {
      _index++;
    }
    return ResponseBody.fromString(response.body, response.status, headers: response.headers);
  }
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

    test("persists response payload and satisfies later 304 from cache", () async {
      final uri = Uri.parse("https://example.com/meta.json");
      final adapter = _RecordingAdapter(
        status: 200,
        body: '{"schemaVersion":1,"hello":"world"}',
        responseHeaders: {
          "etag": ['"fresh"'],
        },
      );
      final dio = Dio()..httpClientAdapter = adapter;

      final first = await fetchRemoteJson(dio, uri);
      expect(first, {"schemaVersion": 1, "hello": "world"});
      expect(EtagCache.getPayload(uri), '{"schemaVersion":1,"hello":"world"}');

      // Simulate a later request that gets 304; caller passes no cached payload.
      final adapter2 = _RecordingAdapter(status: 304);
      final dio2 = Dio()..httpClientAdapter = adapter2;
      final second = await fetchRemoteJson(dio2, uri);

      expect(second, {"schemaVersion": 1, "hello": "world"});
      expect(adapter2.requests.length, 1);
    });

    test("without cachedPayload or persisted payload clears ETag and retries", () async {
      final uri = Uri.parse("https://example.com/meta.json");
      EtagCache.update(uri, etag: '"stale"');

      final adapter = _RecordingAdapter.sequence([
        const _RecordingResponse(status: 304),
        const _RecordingResponse(
          status: 200,
          body: '{"schemaVersion":1}',
          headers: {
            "etag": ['"fresh"'],
          },
        ),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;

      final result = await fetchRemoteJson(dio, uri);

      expect(result, {"schemaVersion": 1});
      expect(adapter.requests.length, 2);
      // First request used the stale ETag.
      expect(_header(adapter.requests[0], "If-None-Match"), '"stale"');
      // Retry must not send any conditional header.
      expect(_header(adapter.requests[1], "If-None-Match"), isNull);
      expect(_header(adapter.requests[1], "If-Modified-Since"), isNull);
      // Fresh payload is persisted.
      expect(EtagCache.getPayload(uri), '{"schemaVersion":1}');
    });

    test("throws when server returns 304 even on unconditional retry", () async {
      final uri = Uri.parse("https://example.com/meta.json");
      EtagCache.update(uri, etag: '"stale"');

      final adapter = _RecordingAdapter.sequence([
        const _RecordingResponse(status: 304),
        const _RecordingResponse(status: 304),
      ]);
      final dio = Dio()..httpClientAdapter = adapter;

      await expectLater(() => fetchRemoteJson(dio, uri), throwsA(isA<RemoteContentException>()));
      // First conditional request + unconditional retry.
      expect(adapter.requests.length, 2);
      expect(_header(adapter.requests[0], "If-None-Match"), '"stale"');
      expect(_header(adapter.requests[1], "If-None-Match"), isNull);
      // Stale ETag is removed.
      expect(EtagCache.getEtag(uri), isNull);
    });
  });
}
