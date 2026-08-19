import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:efa_proto/fit_snapshot.pb.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Public origin of the platform API (`worker/efa-platform-api`).
const platformApiOrigin = "https://api.efa-tech.dev";

/// Injectable seam for the platform API client, so tests can substitute a fake
/// transport.
final platformApiClientProvider = Provider<PlatformApiClient>((Ref ref) => PlatformApiClient());

/// A single entry of `GET /platform/internal/posts` (spec §6.3).
class PostSummary {
  const PostSummary({
    required this.postId,
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

/// The post record of `GET /platform/internal/posts/:id` (spec §6.2).
class PostRecord {
  const PostRecord({required this.postId, required this.fitHash, required this.createdAt});

  factory PostRecord.fromJson(Map<String, dynamic> json) => PostRecord(
    postId: json["postId"] as String,
    fitHash: json["fitHash"] as String,
    createdAt: json["createdAt"] as String,
  );

  final String postId;
  final String fitHash;
  final String createdAt;
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
/// `api.efa-tech.dev/platform/internal`; docs/temp/api-unit/spec.md §6).
///
/// All endpoints here are public reads; post creation goes through
/// `FitSnapshotUploadApi.submit`.
class PlatformApiClient {
  PlatformApiClient({Dio? dio})
    : _dio = dio ?? createRemoteDio(connectTimeout: const Duration(seconds: 10));

  final Dio _dio;

  /// Cursor-paginated post list (§6.3). [limit] is clamped server-side to
  /// 1..50 (default 20).
  Future<PostListPage> listPosts({String? cursor, int? limit, String? locale}) async {
    final json = await _getJson("/platform/internal/posts", {
      "cursor": ?cursor,
      "limit": ?limit?.toString(),
      "locale": ?locale,
    });
    return PostListPage(
      posts: [
        for (final entry in json["posts"] as List<dynamic>)
          PostSummary.fromJson(entry as Map<String, dynamic>),
      ],
      nextCursor: json["nextCursor"] as String?,
    );
  }

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

  /// The thread list of a post (§6.4 stub; currently always empty).
  Future<List<ThreadSummary>> getThreads(String postId) async {
    final json = await _getJson("/platform/internal/posts/$postId/threads", const {});
    return [
      for (final entry in json["threads"] as List<dynamic>)
        ThreadSummary.fromJson(entry as Map<String, dynamic>),
    ];
  }

  Future<Map<String, dynamic>> _getJson(String path, Map<String, String> queryParameters) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        "$platformApiOrigin$path",
        queryParameters: queryParameters,
      );
      final data = response.data;
      if (data == null) {
        throw const PlatformApiException(null, null, "empty response body");
      }
      return data;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Future<Uint8List> _getBytes(String path) async {
    try {
      final response = await _dio.get<Uint8List>(
        "$platformApiOrigin$path",
        options: Options(responseType: ResponseType.bytes),
      );
      final data = response.data;
      if (data == null) {
        throw const PlatformApiException(null, null, "empty response body");
      }
      return data;
    } on DioException catch (e) {
      throw _mapDioException(e);
    }
  }

  Exception _mapDioException(DioException e) {
    final body = _decodeErrorBody(e.response?.data);
    return PlatformApiException(e.response?.statusCode, body?.error, body?.message ?? e.message);
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
}
