@TestOn("vm")
library;

import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:efa_proto/fit_snapshot.pb.dart";
import "package:eve_fit_assistant/features/platform/platform_api.dart";
import "package:fixnum/fixnum.dart";
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

PlatformApiClient _clientWith(Future<ResponseBody> Function(RequestOptions options) onFetch) =>
    PlatformApiClient(dio: Dio(BaseOptions())..httpClientAdapter = _FakeAdapter(onFetch));

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ["application/json"],
  },
);

final _postJson = {
  "postId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "fitHash": "abc123",
  "fitName": "Test Fit",
  "description": "A description",
  "shipName": "Heron",
  "shipTypeId": 605,
  "createdAt": "2026-08-19T00:00:00.000Z",
  "lastModifiedMs": 1755550000000,
  "generator": "eve-fit-assistant/1.2.3",
};

void main() {
  group("listPosts", () {
    test("decodes a page and forwards cursor/limit/locale", () async {
      RequestOptions? captured;
      final client = _clientWith((options) async {
        captured = options;
        return _json({
          "posts": [_postJson],
          "nextCursor": "cursor-2",
        });
      });

      final page = await client.listPosts(cursor: "cursor-1", limit: 30, locale: "zh");

      expect(captured?.path, "https://api.efa-tech.dev/platform/internal/posts");
      expect(captured?.queryParameters, {"cursor": "cursor-1", "limit": "30", "locale": "zh"});
      expect(page.nextCursor, "cursor-2");
      expect(page.posts, hasLength(1));
      final post = page.posts.single;
      expect(post.postId, _postJson["postId"]);
      expect(post.fitName, "Test Fit");
      expect(post.description, "A description");
      expect(post.shipName, "Heron");
      expect(post.shipTypeId, 605);
      expect(post.lastModifiedMs, 1755550000000);
      expect(post.generator, "eve-fit-assistant/1.2.3");
    });

    test("decodes the last page with a null cursor", () async {
      final client = _clientWith((options) async => _json({"posts": [], "nextCursor": null}));
      final page = await client.listPosts();
      expect(page.posts, isEmpty);
      expect(page.nextCursor, isNull);
    });
  });

  group("getPost", () {
    test("decodes the record", () async {
      final client = _clientWith(
        (options) async =>
            _json({"postId": "p", "fitHash": "abc", "createdAt": "2026-08-19T00:00:00.000Z"}),
      );
      final record = await client.getPost("p");
      expect(record?.fitHash, "abc");
    });

    test("returns null on 404", () async {
      final client = _clientWith(
        (options) async => _json({"error": "not_found", "message": "unknown post id"}, 404),
      );
      expect(await client.getPost("missing"), isNull);
    });
  });

  group("snapshot endpoints", () {
    final snapshotBytes = FitSnapshot(
      version: 1,
      header: SnapshotHeader(fitName: "Test Fit", lastModifiedMs: Int64(1)),
    ).writeToBuffer();

    test("getPostSnapshot decodes the protobuf bytes", () async {
      final client = _clientWith(
        (options) async => ResponseBody.fromBytes(
          snapshotBytes,
          200,
          headers: {
            Headers.contentTypeHeader: ["application/x-protobuf"],
          },
        ),
      );
      final snapshot = await client.getPostSnapshot("p");
      expect(snapshot?.header.fitName, "Test Fit");
    });

    test("getFitSnapshot addresses the by-hash route", () async {
      RequestOptions? captured;
      final client = _clientWith((options) async {
        captured = options;
        return ResponseBody.fromBytes(snapshotBytes, 200);
      });
      final snapshot = await client.getFitSnapshot("abc123");
      expect(captured?.path, "https://api.efa-tech.dev/platform/internal/fits/abc123/snapshot");
      expect(snapshot?.version, 1);
    });

    test("returns null on 404", () async {
      final client = _clientWith(
        (options) async => _json({"error": "not_found", "message": "unknown fit hash"}, 404),
      );
      expect(await client.getFitSnapshot("missing"), isNull);
    });
  });

  group("getThreads", () {
    test("decodes the stub response", () async {
      final client = _clientWith((options) async => _json({"threads": []}));
      expect(await client.getThreads("p"), isEmpty);
    });
  });

  group("errors", () {
    test("non-404 failures throw with the envelope code", () async {
      final client = _clientWith(
        (options) async => _json({"error": "bad_request", "message": "malformed cursor"}, 400),
      );
      await expectLater(
        () => client.listPosts(cursor: "garbage"),
        throwsA(
          isA<PlatformApiException>()
              .having((e) => e.statusCode, "statusCode", 400)
              .having((e) => e.code, "code", "bad_request")
              .having((e) => e.message, "message", "malformed cursor"),
        ),
      );
    });
  });
}
