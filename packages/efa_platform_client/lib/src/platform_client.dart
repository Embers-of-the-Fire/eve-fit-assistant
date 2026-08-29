import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:efa_platform_client/src/dio_options.dart";
import "package:efa_proto/fit_request.pb.dart";
import "package:efa_proto/fit_snapshot.pb.dart";

/// A single entry of `GET /platform/internal/posts` (spec §6.3).
class PostSummary {
  const PostSummary({
    required this.postId,
    required this.authorId,
    required this.authorDeleted,
    required this.fitHash,
    required this.fitName,
    required this.description,
    required this.shipName,
    required this.shipTypeId,
    required this.createdAt,
    required this.lastModifiedMs,
    required this.generator,
  });

  factory PostSummary.fromJson(Map<String, dynamic> json) => PostSummary(
    postId: json["postId"] as String,
    authorId: json["authorId"] as String?,
    authorDeleted: json["authorDeleted"] as bool,
    fitHash: json["fitHash"] as String,
    fitName: json["fitName"] as String,
    description: json["description"] as String,
    shipName: json["shipName"] as String,
    shipTypeId: json["shipTypeId"] as int,
    createdAt: json["createdAt"] as String,
    lastModifiedMs: json["lastModifiedMs"] as int,
    generator: json["generator"] as String?,
  );

  final String postId;

  /// The uploading account's user id; null when the author is a tombstone
  /// (deleted account or pre-auth legacy post).
  final String? authorId;

  /// True when the author is a tombstone (null [authorId]) or the account
  /// was deregistered (anonymized in place). Posts survive account deletion.
  final bool authorDeleted;
  final String fitHash;
  final String fitName;

  /// Preview of the fit's description (≤ 280 code points).
  final String description;
  final String shipName;
  final int shipTypeId;
  final String createdAt;
  final int lastModifiedMs;
  final String? generator;
}

/// One page of the cursor-paginated post list; [nextCursor] is null on the
/// last page.
class PostListPage {
  const PostListPage({required this.posts, required this.nextCursor});

  final List<PostSummary> posts;
  final String? nextCursor;
}

/// Time-window filter shared by the post and ship listings. [all] is the
/// server default and sends no query parameter (matching the site's
/// behavior); the others map to the `window` query values.
enum PlatformTimeWindow {
  h24("24h"),
  d7("7d"),
  d30("30d"),
  all("all");

  const PlatformTimeWindow(this.queryValue);

  /// The `window` query value; null for [all], which is omitted instead.
  final String queryValue;
}

/// A popular-ship entry of `GET /platform/internal/stats`.
class TopShip {
  const TopShip({required this.shipTypeId, required this.shipName, required this.postCount});

  factory TopShip.fromJson(Map<String, dynamic> json) => TopShip(
    shipTypeId: json["shipTypeId"] as int,
    shipName: json["shipName"] as String,
    postCount: json["postCount"] as int,
  );

  final int shipTypeId;
  final String shipName;
  final int postCount;
}

/// The platform-wide totals of `GET /platform/internal/stats`.
class PlatformStats {
  const PlatformStats({
    required this.totalPosts,
    required this.distinctShips,
    required this.postsLast7d,
    required this.topShips,
  });

  factory PlatformStats.fromJson(Map<String, dynamic> json) => PlatformStats(
    totalPosts: json["totalPosts"] as int,
    distinctShips: json["distinctShips"] as int,
    postsLast7d: json["postsLast7d"] as int,
    topShips: [
      for (final entry in json["topShips"] as List<dynamic>)
        TopShip.fromJson(entry as Map<String, dynamic>),
    ],
  );

  final int totalPosts;
  final int distinctShips;
  final int postsLast7d;

  /// The ships with the most posts, ordered by post count descending.
  final List<TopShip> topShips;
}

/// A single entry of `GET /platform/internal/ships`.
class ShipSummary {
  const ShipSummary({
    required this.shipTypeId,
    required this.shipName,
    required this.postCount,
    required this.lastPostAt,
  });

  factory ShipSummary.fromJson(Map<String, dynamic> json) => ShipSummary(
    shipTypeId: json["shipTypeId"] as int,
    shipName: json["shipName"] as String,
    postCount: json["postCount"] as int,
    lastPostAt: json["lastPostAt"] as String,
  );

  final int shipTypeId;
  final String shipName;
  final int postCount;
  final String lastPostAt;
}

/// One page of the cursor-paginated ship directory; [nextCursor] is null on
/// the last page.
class ShipListPage {
  const ShipListPage({required this.ships, required this.nextCursor});

  final List<ShipSummary> ships;
  final String? nextCursor;
}

/// The ship detail of `GET /platform/internal/ships/:id`.
class ShipDetail {
  const ShipDetail({
    required this.shipTypeId,
    required this.shipName,
    required this.postCount,
    required this.firstPostAt,
    required this.lastPostAt,
  });

  factory ShipDetail.fromJson(Map<String, dynamic> json) => ShipDetail(
    shipTypeId: json["shipTypeId"] as int,
    shipName: json["shipName"] as String,
    postCount: json["postCount"] as int,
    firstPostAt: json["firstPostAt"] as String,
    lastPostAt: json["lastPostAt"] as String,
  );

  final int shipTypeId;
  final String shipName;
  final int postCount;
  final String firstPostAt;
  final String lastPostAt;
}

/// The post record of `GET /platform/internal/posts/:id` (spec §6.2).
class PostRecord {
  const PostRecord({
    required this.postId,
    required this.authorId,
    required this.authorDeleted,
    required this.fitHash,
    required this.createdAt,
    required this.commentCount,
  });

  factory PostRecord.fromJson(Map<String, dynamic> json) => PostRecord(
    postId: json["postId"] as String,
    authorId: json["authorId"] as String?,
    authorDeleted: json["authorDeleted"] as bool,
    fitHash: json["fitHash"] as String,
    createdAt: json["createdAt"] as String,
    commentCount: json["commentCount"] as int,
  );

  final String postId;

  /// The uploading account's user id; null when the author is a tombstone
  /// (deleted account or pre-auth legacy post).
  final String? authorId;

  /// True when the author is a tombstone (null [authorId]) or the account
  /// was deregistered (anonymized in place). Posts survive account deletion.
  final bool authorDeleted;
  final String fitHash;
  final String createdAt;

  /// The number of discussion comments under the post.
  final int commentCount;
}

/// A single discussion comment of `GET /platform/internal/posts/:id/comments`.
/// Comments form a flat, chronological list under the post.
class Comment {
  const Comment({
    required this.commentId,
    required this.authorId,
    required this.authorDeleted,
    required this.body,
    required this.createdAt,
  });

  factory Comment.fromJson(Map<String, dynamic> json) => Comment(
    commentId: json["commentId"] as String,
    authorId: json["authorId"] as String?,
    authorDeleted: json["authorDeleted"] as bool,
    body: json["body"] as String,
    createdAt: json["createdAt"] as String,
  );

  final String commentId;

  /// The authoring account's user id; null when the author is a tombstone
  /// (deleted account).
  final String? authorId;

  /// True when the author is a tombstone (null [authorId]) or the account
  /// was deregistered. Comments survive account deletion.
  final bool authorDeleted;

  /// Raw markdown; rendering and sanitizing are the client's job (the server
  /// stores bodies verbatim and never sanitizes them).
  final String body;
  final String createdAt;
}

/// One page of the cursor-paginated comment list; [nextCursor] is null on
/// the last page. Pages are ascending (oldest first, chat-log style); the
/// cursor carries the last seen row.
class CommentListPage {
  const CommentListPage({required this.comments, required this.nextCursor});

  final List<Comment> comments;
  final String? nextCursor;
}

/// A thread entry of `GET /platform/internal/posts/:id/threads` (spec §6.4;
/// currently always empty).
class ThreadSummary {
  const ThreadSummary({
    required this.id,
    required this.title,
    required this.author,
    required this.replyCount,
    required this.lastActivityAt,
  });

  factory ThreadSummary.fromJson(Map<String, dynamic> json) => ThreadSummary(
    id: json["id"] as String,
    title: json["title"] as String,
    author: json["author"] as String,
    replyCount: json["replyCount"] as int,
    lastActivityAt: json["lastActivityAt"] as String,
  );

  final String id;
  final String title;
  final String author;
  final int replyCount;
  final String lastActivityAt;
}

/// HTTP failure from the platform API; [code] is the worker's error-envelope
/// code (`bad_request`, `not_found`, ...) when present.
class PlatformApiException implements Exception {
  const PlatformApiException(this.statusCode, [this.code, this.message]);

  final int? statusCode;
  final String? code;
  final String? message;

  bool get isNotFound => statusCode == 404 || code == "not_found";

  @override
  String toString() =>
      "PlatformApiException(${statusCode ?? "network"}"
      "${code == null ? "" : ", $code"}${message == null ? "" : ": $message"})";
}

/// Client for the platform's public front (`worker/efa-platform-api`,
/// `{origin}/platform/internal`).
///
/// All endpoints here are public reads; post creation goes through the
/// fit-snapshot upload API.
class PlatformApiClient {
  PlatformApiClient({required this.origin, Dio? dio}) : _dio = dio ?? Dio(defaultBaseOptions());

  final String origin;
  final Dio _dio;

  /// Cursor-paginated post list (§6.3). [limit] is clamped server-side to
  /// 1..50 (default 20). [shipTypeId] and [window] filter the listing;
  /// [PlatformTimeWindow.all] sends no `window` parameter.
  Future<PostListPage> listPosts({
    String? cursor,
    int? limit,
    String? locale,
    int? shipTypeId,
    PlatformTimeWindow? window,
  }) async {
    final json = await _getJson("/platform/internal/posts", {
      "cursor": ?cursor,
      "limit": ?limit?.toString(),
      "locale": ?locale,
      "shipTypeId": ?shipTypeId?.toString(),
      if (window != null && window != PlatformTimeWindow.all) "window": window.queryValue,
    });
    return PostListPage(
      posts: [
        for (final entry in json["posts"] as List<dynamic>)
          PostSummary.fromJson(entry as Map<String, dynamic>),
      ],
      nextCursor: json["nextCursor"] as String?,
    );
  }

  /// Cursor-paginated ship directory. [q] filters by ship name; [window]
  /// restricts to ships with posts inside the time window
  /// ([PlatformTimeWindow.all] sends no `window` parameter).
  Future<ShipListPage> listShips({
    String? q,
    PlatformTimeWindow? window,
    String? cursor,
    int? limit,
    String? locale,
  }) async {
    final json = await _getJson("/platform/internal/ships", {
      "q": ?q,
      "cursor": ?cursor,
      "limit": ?limit?.toString(),
      "locale": ?locale,
      if (window != null && window != PlatformTimeWindow.all) "window": window.queryValue,
    });
    return ShipListPage(
      ships: [
        for (final entry in json["ships"] as List<dynamic>)
          ShipSummary.fromJson(entry as Map<String, dynamic>),
      ],
      nextCursor: json["nextCursor"] as String?,
    );
  }

  /// The ship detail; null when no posts exist for the ship.
  Future<ShipDetail?> getShip(int shipTypeId, {String? locale}) async {
    try {
      return ShipDetail.fromJson(
        await _getJson("/platform/internal/ships/$shipTypeId", {"locale": ?locale}),
      );
    } on PlatformApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// The platform-wide totals and popular ships.
  Future<PlatformStats> getStats({String? locale}) async =>
      PlatformStats.fromJson(await _getJson("/platform/internal/stats", {"locale": ?locale}));

  /// The post record (§6.2); null when the post does not exist.
  Future<PostRecord?> getPost(String postId) async {
    try {
      return PostRecord.fromJson(await _getJson("/platform/internal/posts/$postId", const {}));
    } on PlatformApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// The stored snapshot behind a post (§6.2); null when the post does not
  /// exist.
  Future<FitSnapshot?> getPostSnapshot(String postId) async {
    try {
      return FitSnapshot.fromBuffer(await _getBytes("/platform/internal/posts/$postId/snapshot"));
    } on PlatformApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// The stored snapshot addressed directly by fit hash (§6.2); null when the
  /// fit does not exist.
  Future<FitSnapshot?> getFitSnapshot(String fitHash) async {
    try {
      return FitSnapshot.fromBuffer(await _getBytes("/platform/internal/fits/$fitHash/snapshot"));
    } on PlatformApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// The stored canonical fit state addressed directly by fit hash (§6.2);
  /// null when the fit does not exist. Unlike the snapshot, the state is
  /// full-fidelity and is what registered fit links import from.
  Future<FitState?> getFitState(String fitHash) async {
    try {
      return FitState.fromBuffer(await _getBytes("/platform/internal/fits/$fitHash/state"));
    } on PlatformApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  /// The thread list of a post (§6.4 stub; currently always empty).
  Future<List<ThreadSummary>> getThreads(String postId) async {
    final json = await _getJson("/platform/internal/posts/$postId/threads", const {});
    return [
      for (final entry in json["threads"] as List<dynamic>)
        ThreadSummary.fromJson(entry as Map<String, dynamic>),
    ];
  }

  /// Cursor-paginated comment list of a post, ascending (oldest first).
  /// [limit] is clamped server-side to 1..100 (default 50).
  Future<CommentListPage> listComments(String postId, {String? cursor, int? limit}) async {
    final json = await _getJson("/platform/internal/posts/$postId/comments", {
      "cursor": ?cursor,
      "limit": ?limit?.toString(),
    });
    return CommentListPage(
      comments: [
        for (final entry in json["comments"] as List<dynamic>)
          Comment.fromJson(entry as Map<String, dynamic>),
      ],
      nextCursor: json["nextCursor"] as String?,
    );
  }

  Future<Map<String, dynamic>> _getJson(String path, Map<String, String> queryParameters) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        "$origin$path",
        queryParameters: queryParameters,
      );
      final data = response.data;
      if (data == null) {
        throw const PlatformApiException(null, null, "empty response body");
      }
      return data;
    } on DioException catch (e) {
      throw mapPlatformDioException(e);
    }
  }

  Future<Uint8List> _getBytes(String path) async {
    try {
      final response = await _dio.get<Uint8List>(
        "$origin$path",
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) {
        throw const PlatformApiException(null, null, "empty response body");
      }
      return data;
    } on DioException catch (e) {
      throw mapPlatformDioException(e);
    }
  }
}

/// Maps a Dio failure to a [PlatformApiException], decoding the worker's
/// error envelope (`{error, message}`) when present. Connection-level
/// failures carry no Dio message; the real cause (SocketException,
/// HandshakeException, ...) lives in `e.error`, so it is kept as the
/// message to keep the exception diagnosable. Package-internal:
/// shared by [PlatformApiClient] and the session's authenticated writes.
PlatformApiException mapPlatformDioException(DioException e) {
  final body = _decodeErrorBody(e.response?.data);
  return PlatformApiException(
    e.response?.statusCode,
    body?.error,
    body?.message ?? e.message ?? e.error?.toString(),
  );
}

({String? error, String? message})? _decodeErrorBody(Object? data) {
  final String? text = switch (data) {
    final Uint8List bytes => utf8.decode(bytes, allowMalformed: true),
    final List<int> bytes => utf8.decode(bytes, allowMalformed: true),
    final String text => text,
    _ => null,
  };
  final Map<String, dynamic> json;
  if (data is Map<String, dynamic>) {
    json = data;
  } else if (text != null) {
    try {
      json = jsonDecode(text) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  } else {
    return null;
  }
  return (error: json["error"] as String?, message: json["message"] as String?);
}
