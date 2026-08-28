@TestOn("vm")
library;

import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:efa_platform_client/src/platform_client.dart";
import "package:efa_proto/fit_request.pb.dart";
import "package:efa_proto/fit_snapshot.pb.dart";
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

const _origin = "https://api.efa-tech.dev";

PlatformApiClient _clientWith(Future<ResponseBody> Function(RequestOptions options) onFetch) =>
    PlatformApiClient(
      origin: _origin,
      dio: Dio(BaseOptions())..httpClientAdapter = _FakeAdapter(onFetch),
    );

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ["application/json"],
  },
);

final _postJson = {
  "postId": "7c9e6679-7425-40de-944b-e07fc1f90ae7",
  "authorId": "0f5f0d2f-6d21-4f69-8f8a-2c2f2dbb6f9a",
  "authorDeleted": false,
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
      expect(post.authorId, "0f5f0d2f-6d21-4f69-8f8a-2c2f2dbb6f9a");
      expect(post.authorDeleted, isFalse);
      expect(post.fitName, "Test Fit");
      expect(post.description, "A description");
      expect(post.shipName, "Heron");
      expect(post.shipTypeId, 605);
      expect(post.lastModifiedMs, 1755550000000);
      expect(post.generator, "eve-fit-assistant/1.2.3");
    });

    test("decodes a null-author tombstone", () async {
      final client = _clientWith(
        (options) async => _json({
          "posts": [
            {..._postJson, "authorId": null, "authorDeleted": true},
          ],
          "nextCursor": null,
        }),
      );
      final page = await client.listPosts();
      expect(page.posts.single.authorId, isNull);
      expect(page.posts.single.authorDeleted, isTrue);
    });

    test("decodes the last page with a null cursor", () async {
      final client = _clientWith(
        (options) async => _json({"posts": <Object?>[], "nextCursor": null}),
      );
      final page = await client.listPosts();
      expect(page.posts, isEmpty);
      expect(page.nextCursor, isNull);
    });
  });

  group("getPost", () {
    test("decodes the record", () async {
      final client = _clientWith(
        (options) async => _json({
          "postId": "p",
          "authorId": "u-1",
          "authorDeleted": false,
          "fitHash": "abc",
          "createdAt": "2026-08-19T00:00:00.000Z",
          "commentCount": 3,
        }),
      );
      final record = await client.getPost("p");
      expect(record?.fitHash, "abc");
      expect(record?.authorId, "u-1");
      expect(record?.authorDeleted, isFalse);
      expect(record?.commentCount, 3);
    });

    test("decodes the record of a tombstone author", () async {
      final client = _clientWith(
        (options) async => _json({
          "postId": "p",
          "authorId": null,
          "authorDeleted": true,
          "fitHash": "abc",
          "createdAt": "2026-08-19T00:00:00.000Z",
          "commentCount": 0,
        }),
      );
      final record = await client.getPost("p");
      expect(record?.authorId, isNull);
      expect(record?.authorDeleted, isTrue);
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

  group("getFitState", () {
    final stateBytes = FitState(
      shipTypeId: 12017,
      layout: SnapshotShipLayout(
        highSlots: 1,
        mediumSlots: 0,
        lowSlots: 0,
        rigSlots: 0,
        subsystemSlots: 0,
        serviceSlots: 0,
        turretHardpoints: 0,
        launcherHardpoints: 0,
        fighterTubes: 0,
      ),
      damageProfile: DamageProfile(em: 0.25, thermal: 0.25, kinetic: 0.25, explosive: 0.25),
    ).writeToBuffer();

    test("addresses the by-hash state route and decodes the protobuf bytes", () async {
      RequestOptions? captured;
      final client = _clientWith((options) async {
        captured = options;
        return ResponseBody.fromBytes(stateBytes, 200);
      });
      final state = await client.getFitState("abc123");
      expect(captured?.path, "https://api.efa-tech.dev/platform/internal/fits/abc123/state");
      expect(state?.shipTypeId, 12017);
    });

    test("returns null on 404", () async {
      final client = _clientWith(
        (options) async => _json({"error": "not_found", "message": "unknown fit hash"}, 404),
      );
      expect(await client.getFitState("missing"), isNull);
    });
  });

  group("getThreads", () {
    test("decodes the stub response", () async {
      final client = _clientWith((options) async => _json({"threads": <Object?>[]}));
      expect(await client.getThreads("p"), isEmpty);
    });
  });

  group("listComments", () {
    final commentJson = {
      "commentId": "c-1",
      "authorId": "u-1",
      "authorDeleted": false,
      "body": "**hello**",
      "createdAt": "2026-08-19T00:00:00.000Z",
    };

    test("decodes a page and forwards cursor/limit", () async {
      RequestOptions? captured;
      final client = _clientWith((options) async {
        captured = options;
        return _json({
          "comments": [commentJson],
          "nextCursor": "cursor-2",
        });
      });

      final page = await client.listComments("p", cursor: "cursor-1", limit: 30);

      expect(captured?.path, "https://api.efa-tech.dev/platform/internal/posts/p/comments");
      expect(captured?.queryParameters, {"cursor": "cursor-1", "limit": "30"});
      expect(page.nextCursor, "cursor-2");
      expect(page.comments, hasLength(1));
      final comment = page.comments.single;
      expect(comment.commentId, "c-1");
      expect(comment.authorId, "u-1");
      expect(comment.authorDeleted, isFalse);
      expect(comment.body, "**hello**");
      expect(comment.createdAt, "2026-08-19T00:00:00.000Z");
    });

    test("decodes a null-author tombstone", () async {
      final client = _clientWith(
        (options) async => _json({
          "comments": [
            {...commentJson, "authorId": null, "authorDeleted": true},
          ],
          "nextCursor": null,
        }),
      );
      final page = await client.listComments("p");
      expect(page.comments.single.authorId, isNull);
      expect(page.comments.single.authorDeleted, isTrue);
    });

    test("decodes the last page with a null cursor", () async {
      final client = _clientWith(
        (options) async => _json({"comments": <Object?>[], "nextCursor": null}),
      );
      final page = await client.listComments("p");
      expect(page.comments, isEmpty);
      expect(page.nextCursor, isNull);
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
