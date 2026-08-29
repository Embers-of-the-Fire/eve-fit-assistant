@TestOn("vm")
library;

import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:efa_proto/fit_snapshot.pb.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/features/platform/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
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

class _MemoryStore implements PlatformSessionStore {
  StoredPlatformSession? session;

  @override
  Future<StoredPlatformSession?> read() async => session;

  @override
  Future<void> write(StoredPlatformSession session) async => this.session = session;

  @override
  Future<void> clear() async => session = null;
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ["application/json"],
  },
);

const _origin = "https://test.invalid";

String _jwt(String subject) {
  String segment(Object value) => base64Url.encode(utf8.encode(jsonEncode(value)));
  return "${segment({"alg": "HS256", "typ": "JWT"})}.${segment({"sub": subject, "tv": 0})}.sig";
}

Map<String, Object?> _postSummaryJson(String postId) => {
  "postId": postId,
  "authorId": "u-1",
  "authorDeleted": false,
  "fitHash": "abc123",
  "fitName": "Fit $postId",
  "description": "A description",
  "shipName": "Heron",
  "shipTypeId": 605,
  "createdAt": "2026-08-19T00:00:00.000Z",
  "lastModifiedMs": 1755550000000,
  "generator": null,
};

Map<String, Object?> _commentJson(String commentId) => {
  "commentId": commentId,
  "authorId": "u-1",
  "authorDeleted": false,
  "body": "body of $commentId",
  "createdAt": "2026-08-19T00:00:00.000Z",
};

Map<String, Object?> _shipSummaryJson(int shipTypeId) => {
  "shipTypeId": shipTypeId,
  "shipName": "Ship $shipTypeId",
  "postCount": 12,
  "lastPostAt": "2026-08-19T00:00:00.000Z",
};

/// Scriptable platform API: pages of posts and comments keyed by cursor,
/// plus comment creation. Signed-out only (no auth endpoints).
class _PlatformServer {
  final Map<String?, ({List<Map<String, Object?>> posts, String? next})> postPages = {};
  final Map<String?, ({List<Map<String, Object?>> comments, String? next})> commentPages = {};
  final Map<String?, ({List<Map<String, Object?>> ships, String? next})> shipPages = {};
  final List<Map<String, Object?>> createdComments = [];
  int commentCount = 2;

  Future<ResponseBody> fetch(RequestOptions options) async {
    final path = options.path;
    if (path.endsWith("/platform/auth/refresh")) {
      return _json({"accessToken": _jwt("user-1"), "refreshToken": "refresh-2", "expiresIn": 900});
    }
    if (path == "$_origin/platform/internal/stats") {
      return _json({
        "totalPosts": 42,
        "distinctShips": 7,
        "postsLast7d": 5,
        "topShips": [
          {"shipTypeId": 605, "shipName": "Heron", "postCount": 12},
        ],
      });
    }
    if (path == "$_origin/platform/internal/ships") {
      final page =
          shipPages[options.queryParameters["cursor"]] ??
          const (ships: <Map<String, Object?>>[], next: null);
      return _json({"ships": page.ships, "nextCursor": page.next});
    }
    final shipMatch = RegExp(
      r"^/platform/internal/ships/(\d+)$",
    ).firstMatch(Uri.parse(path).path);
    if (shipMatch != null) {
      final shipTypeId = int.parse(shipMatch.group(1)!);
      if (shipTypeId == 0) {
        return _json({"error": "not_found", "message": "unknown ship"}, 404);
      }
      return _json({..._shipSummaryJson(shipTypeId), "firstPostAt": "2026-08-01T00:00:00.000Z"});
    }
    if (path == "$_origin/platform/internal/posts") {
      final page =
          postPages[options.queryParameters["cursor"]] ??
          const (posts: <Map<String, Object?>>[], next: null);
      return _json({"posts": page.posts, "nextCursor": page.next});
    }
    final commentsMatch = RegExp(
      r"^/platform/internal/posts/([^/]+)/comments$",
    ).firstMatch(Uri.parse(path).path);
    if (commentsMatch != null && options.method == "GET") {
      final page =
          commentPages[options.queryParameters["cursor"]] ??
          const (comments: <Map<String, Object?>>[], next: null);
      return _json({"comments": page.comments, "nextCursor": page.next});
    }
    if (commentsMatch != null && options.method == "POST") {
      final commentId = "c-created-${createdComments.length + 1}";
      final body = (options.data as Map<String, dynamic>)["body"] as String;
      final comment = {..._commentJson(commentId), "body": body};
      createdComments.add(comment);
      commentCount++;
      return _json(comment, 201);
    }
    if (path.endsWith("/snapshot")) {
      return ResponseBody.fromBytes(
        FitSnapshot(
          version: 1,
          header: SnapshotHeader(fitName: "Test Fit", lastModifiedMs: Int64(1)),
        ).writeToBuffer(),
        200,
        headers: {
          Headers.contentTypeHeader: ["application/x-protobuf"],
        },
      );
    }
    final postMatch = RegExp(
      r"^/platform/internal/posts/([^/]+)$",
    ).firstMatch(Uri.parse(path).path);
    if (postMatch != null) {
      return _json({
        "postId": postMatch.group(1),
        "authorId": "u-1",
        "authorDeleted": false,
        "fitHash": "abc123",
        "createdAt": "2026-08-19T00:00:00.000Z",
        "commentCount": commentCount,
      });
    }
    throw StateError("unexpected request: ${options.method} $path");
  }
}

void main() {
  late _PlatformServer server;
  late ProviderContainer container;

  PlatformSession buildSession({_MemoryStore? store}) => PlatformSession(
    origin: _origin,
    store: store ?? _MemoryStore(),
    dioFactory: () => Dio(BaseOptions())..httpClientAdapter = _FakeAdapter(server.fetch),
  );

  /// A session with a valid, far-future stored pair: no refresh traffic, and
  /// authenticated writes carry the access token directly.
  PlatformSession _signedInSession() {
    final store = _MemoryStore()
      ..session = StoredPlatformSession(
        accessToken: _jwt("user-1"),
        refreshToken: "refresh-1",
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        email: "capsuleer@example.com",
        userId: "user-1",
      );
    return buildSession(store: store);
  }

  setUp(() {
    server = _PlatformServer();
    container = ProviderContainer(
      overrides: [
        platformSessionProvider.overrideWith((ref) async => buildSession()),
        localeProvider.overrideWithValue(Locale.en),
      ],
    );
    addTearDown(container.dispose);
  });

  group("platformFeed", () {
    const filter = PlatformFeedFilter();

    ProviderSubscription<AsyncValue<PlatformFeedState>> keepAlive() {
      final sub = container.listen(platformFeedProvider(filter), (_, _) {});
      addTearDown(sub.close);
      return sub;
    }

    test("builds the first page and loadMore appends the next", () async {
      keepAlive();
      server.postPages[null] = (posts: [_postSummaryJson("p-1")], next: "cursor-2");
      server.postPages["cursor-2"] = (posts: [_postSummaryJson("p-2")], next: null);

      final feed = await container.read(platformFeedProvider(filter).future);
      expect(feed.posts.map((p) => p.postId), ["p-1"]);
      expect(feed.nextCursor, "cursor-2");

      await container.read(platformFeedProvider(filter).notifier).loadMore();
      final updated = container.read(platformFeedProvider(filter)).value;
      expect(updated?.posts.map((p) => p.postId), ["p-1", "p-2"]);
      expect(updated?.nextCursor, isNull);
    });

    test("loadMore is a no-op when the feed is exhausted", () async {
      keepAlive();
      server.postPages[null] = (posts: [_postSummaryJson("p-1")], next: null);
      await container.read(platformFeedProvider(filter).future);

      await container.read(platformFeedProvider(filter).notifier).loadMore();
      expect(container.read(platformFeedProvider(filter)).value?.posts, hasLength(1));
    });

    test("forwards the filter to the post list", () async {
      Map<String, dynamic>? seenQuery;
      final session = PlatformSession(
        origin: _origin,
        store: _MemoryStore(),
        dioFactory: () => Dio(BaseOptions())
          ..httpClientAdapter = _FakeAdapter((options) async {
            seenQuery = options.queryParameters;
            return _json({"posts": <Object?>[], "nextCursor": null});
          }),
      );
      final scoped = ProviderContainer(
        overrides: [
          platformSessionProvider.overrideWith((ref) async => session),
          localeProvider.overrideWithValue(Locale.en),
        ],
      );
      addTearDown(scoped.dispose);

      await scoped.read(
        platformFeedProvider(
          const PlatformFeedFilter(shipTypeId: 605, window: PlatformTimeWindow.d30),
        ).future,
      );
      expect(seenQuery?["shipTypeId"], "605");
      expect(seenQuery?["window"], "30d");

      await scoped.read(platformFeedProvider(const PlatformFeedFilter()).future);
      expect(seenQuery, isNot(contains("shipTypeId")));
      expect(seenQuery, isNot(contains("window")));
    });

    test("forwards the app locale to the post list", () async {
      String? seenLocale;
      final session = PlatformSession(
        origin: _origin,
        store: _MemoryStore(),
        dioFactory: () => Dio(BaseOptions())
          ..httpClientAdapter = _FakeAdapter((options) async {
            seenLocale = options.queryParameters["locale"] as String?;
            return _json({"posts": <Object?>[], "nextCursor": null});
          }),
      );
      final scoped = ProviderContainer(
        overrides: [
          platformSessionProvider.overrideWith((ref) async => session),
          localeProvider.overrideWithValue(Locale.zh),
        ],
      );
      addTearDown(scoped.dispose);

      await scoped.read(platformFeedProvider(filter).future);
      expect(seenLocale, "zh");
    });
  });

  group("platformStats", () {
    test("resolves the totals and top ships", () async {
      final stats = await container.read(platformStatsProvider.future);
      expect(stats.totalPosts, 42);
      expect(stats.distinctShips, 7);
      expect(stats.postsLast7d, 5);
      expect(stats.topShips.single.shipName, "Heron");
    });
  });

  group("platformShipDirectory", () {
    test("builds the first page and loadMore appends the next", () async {
      const query = PlatformShipQuery();
      final sub = container.listen(platformShipDirectoryProvider(query), (_, _) {});
      addTearDown(sub.close);
      server.shipPages[null] = (ships: [_shipSummaryJson(605)], next: "cursor-2");
      server.shipPages["cursor-2"] = (ships: [_shipSummaryJson(624)], next: null);

      final directory = await container.read(platformShipDirectoryProvider(query).future);
      expect(directory.ships.map((s) => s.shipTypeId), [605]);
      expect(directory.nextCursor, "cursor-2");

      await container.read(platformShipDirectoryProvider(query).notifier).loadMore();
      final updated = container.read(platformShipDirectoryProvider(query)).value;
      expect(updated?.ships.map((s) => s.shipTypeId), [605, 624]);
      expect(updated?.nextCursor, isNull);
    });

    test("forwards the query and window to the ship list", () async {
      Map<String, dynamic>? seenQuery;
      final session = PlatformSession(
        origin: _origin,
        store: _MemoryStore(),
        dioFactory: () => Dio(BaseOptions())
          ..httpClientAdapter = _FakeAdapter((options) async {
            seenQuery = options.queryParameters;
            return _json({"ships": <Object?>[], "nextCursor": null});
          }),
      );
      final scoped = ProviderContainer(
        overrides: [
          platformSessionProvider.overrideWith((ref) async => session),
          localeProvider.overrideWithValue(Locale.en),
        ],
      );
      addTearDown(scoped.dispose);

      await scoped.read(
        platformShipDirectoryProvider(
          const PlatformShipQuery(query: " heron ", window: PlatformTimeWindow.h24),
        ).future,
      );
      expect(seenQuery?["q"], "heron");
      expect(seenQuery?["window"], "24h");

      await scoped.read(platformShipDirectoryProvider(const PlatformShipQuery()).future);
      expect(seenQuery, isNot(contains("q")));
      expect(seenQuery, isNot(contains("window")));
    });
  });

  group("platformShip", () {
    test("resolves the ship detail", () async {
      final detail = await container.read(platformShipProvider(605).future);
      expect(detail?.shipName, "Ship 605");
      expect(detail?.postCount, 12);
    });

    test("resolves to null for an unknown ship", () async {
      final detail = await container.read(platformShipProvider(0).future);
      expect(detail, isNull);
    });
  });

  group("platformPost", () {
    test("resolves the record and snapshot", () async {
      final sub = container.listen(platformPostProvider("p-1"), (_, _) {});
      addTearDown(sub.close);
      final detail = await container.read(platformPostProvider("p-1").future);
      expect(detail?.record.postId, "p-1");
      expect(detail?.record.commentCount, 2);
      expect(detail?.snapshot.header.fitName, "Test Fit");
    });
  });

  group("platformComments", () {
    ProviderSubscription<AsyncValue<PlatformCommentState>> keepAlive(String postId) {
      final sub = container.listen(platformCommentsProvider(postId), (_, _) {});
      addTearDown(sub.close);
      return sub;
    }

    test("builds the first page and loadMore appends ascending pages", () async {
      keepAlive("p-1");
      server.commentPages[null] = (comments: [_commentJson("c-1")], next: "cursor-2");
      server.commentPages["cursor-2"] = (comments: [_commentJson("c-2")], next: null);

      final state = await container.read(platformCommentsProvider("p-1").future);
      expect(state.comments.map((c) => c.commentId), ["c-1"]);
      expect(state.nextCursor, "cursor-2");

      await container.read(platformCommentsProvider("p-1").notifier).loadMore();
      final updated = container.read(platformCommentsProvider("p-1")).value;
      expect(updated?.comments.map((c) => c.commentId), ["c-1", "c-2"]);
      expect(updated?.nextCursor, isNull);
    });

    test("signed-out submit throws before reaching the server", () async {
      keepAlive("p-1");
      server.commentPages[null] = (comments: [_commentJson("c-1")], next: "cursor-2");
      server.commentPages["cursor-2"] = (comments: [_commentJson("c-2")], next: null);
      await container.read(platformCommentsProvider("p-1").future);

      // Signed-out creation must never reach the server.
      await expectLater(
        () => container.read(platformCommentsProvider("p-1").notifier).submit("hello"),
        throwsA(isA<PlatformAuthRequiredException>()),
      );
      expect(server.createdComments, isEmpty);
    });

    test("submit pages forward to the end and appends the created comment", () async {
      server.commentPages[null] = (comments: [_commentJson("c-1")], next: "cursor-2");
      server.commentPages["cursor-2"] = (comments: [_commentJson("c-2")], next: null);
      final session = _signedInSession();
      final scoped = ProviderContainer(
        overrides: [
          platformSessionProvider.overrideWith((ref) async => session),
          localeProvider.overrideWithValue(Locale.en),
        ],
      );
      addTearDown(scoped.dispose);
      final sub = scoped.listen(platformCommentsProvider("p-1"), (_, _) {});
      addTearDown(sub.close);
      await scoped.read(platformCommentsProvider("p-1").future);

      await scoped.read(platformCommentsProvider("p-1").notifier).submit("hello there");

      expect(server.createdComments.single["body"], "hello there");
      final state = scoped.read(platformCommentsProvider("p-1")).value;
      expect(state?.comments.map((c) => c.commentId), ["c-1", "c-2", "c-created-1"]);
      expect(state?.comments.last.body, "hello there");
      expect(state?.nextCursor, isNull);
    });

    test("concurrent submits keep both created comments", () async {
      // A non-null first-page cursor forces each submit to page forward
      // before appending, so both calls snapshot the same state at entry.
      server.commentPages[null] = (comments: [_commentJson("c-1")], next: "cursor-2");
      server.commentPages["cursor-2"] = (comments: [_commentJson("c-2")], next: null);
      final session = _signedInSession();
      final scoped = ProviderContainer(
        overrides: [
          platformSessionProvider.overrideWith((ref) async => session),
          localeProvider.overrideWithValue(Locale.en),
        ],
      );
      addTearDown(scoped.dispose);
      final sub = scoped.listen(platformCommentsProvider("p-1"), (_, _) {});
      addTearDown(sub.close);
      await scoped.read(platformCommentsProvider("p-1").future);

      // Fire both creations without awaiting so their runs overlap.
      final first = scoped.read(platformCommentsProvider("p-1").notifier).submit("first");
      final second = scoped.read(platformCommentsProvider("p-1").notifier).submit("second");
      await Future.wait([first, second]);

      expect(server.createdComments.map((c) => c["body"]), ["first", "second"]);
      final state = scoped.read(platformCommentsProvider("p-1")).value;
      expect(state?.comments.map((c) => c.commentId), ["c-1", "c-2", "c-created-1", "c-created-2"]);
      expect(state?.nextCursor, isNull);
    });

    test("submit refreshes the post comment count", () async {
      final session = _signedInSession();
      final scoped = ProviderContainer(
        overrides: [
          platformSessionProvider.overrideWith((ref) async => session),
          localeProvider.overrideWithValue(Locale.en),
        ],
      );
      addTearDown(scoped.dispose);
      final postSub = scoped.listen(platformPostProvider("p-1"), (_, _) {});
      addTearDown(postSub.close);
      final commentSub = scoped.listen(platformCommentsProvider("p-1"), (_, _) {});
      addTearDown(commentSub.close);

      final before = await scoped.read(platformPostProvider("p-1").future);
      expect(before?.record.commentCount, 2);

      await scoped.read(platformCommentsProvider("p-1").notifier).submit("hello there");

      final after = await scoped.read(platformPostProvider("p-1").future);
      expect(after?.record.commentCount, 3);
    });
  });
}
