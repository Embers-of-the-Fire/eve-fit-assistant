import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:efa_proto/fit_request.pb.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Injectable seam for the upload API, so tests can substitute a fake transport.
final fitSnapshotUploadApiProvider = Provider<FitSnapshotUploadApi>(
  (Ref ref) => FitSnapshotUploadApi(),
);

/// Error codes reported by the platform API worker, plus client-side categories.
enum FitUploadErrorCode {
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  snapshotIncomplete,
  unknownType,
  validationFailed,
  network,
  unexpected,
}

class FitUploadException implements Exception {
  const FitUploadException(this.code, [this.message, this.issues]);

  final FitUploadErrorCode code;
  final String? message;

  /// Raw `issues` array from the worker's `validation_failed` error envelope
  /// (`[{slot_type, index, severity, kind}]`), kept as decoded JSON.
  final Object? issues;

  @override
  String toString() =>
      "FitUploadException(${code.name}${message == null ? "" : ": $message"}"
      "${issues == null ? "" : ", issues: ${jsonEncode(issues)}"})";
}

/// Result of `POST /platform/internal/posts`: the post is a fresh publication
/// event (UUID) backed by the content-addressed fit.
class FitPostSubmitResult {
  const FitPostSubmitResult({
    required this.postId,
    required this.fitHash,
    required this.alreadyExisted,
    required this.origin,
  });

  factory FitPostSubmitResult.fromJson(Map<String, dynamic> json, {required String origin}) =>
      FitPostSubmitResult(
        postId: json["postId"] as String,
        fitHash: json["fitHash"] as String,
        alreadyExisted: json["alreadyExisted"] as bool,
        origin: origin,
      );

  final String postId;
  final String fitHash;
  final bool alreadyExisted;

  /// The origin the upload went to. Snapshot URLs for this fit must be built
  /// against it: preview and production use separate database and fit-storage
  /// bindings, so a URL on the wrong origin can return no snapshot.
  final String origin;
}

/// Client for the platform's public front (`worker/efa-platform-api`,
/// `{origin}/platform/internal`).
class FitSnapshotUploadApi {
  /// Public URL of the stored snapshot for a given fit hash (spec §6.2),
  /// built against the origin the upload targeted (the resolved
  /// `PlatformSession.origin`, not always production).
  static String byHashUrl(String fitHash, {required String origin}) =>
      "$origin/platform/internal/fits/$fitHash/snapshot";

  /// Submits the upload through the session's authenticated Dio (the access
  /// token is attached — and refreshed on 401 — by the session interceptor).
  Future<FitPostSubmitResult> submit(
    FitUploadRequest request, {
    required Dio dio,
    required String origin,
  }) async {
    try {
      final response = await dio.post<Object>(
        "$origin/platform/internal/posts",
        data: request.writeToBuffer(),
        options: Options(contentType: "application/x-protobuf"),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FitUploadException(FitUploadErrorCode.unexpected);
      }
      return FitPostSubmitResult.fromJson(data, origin: origin);
    } on DioException catch (e) {
      throw _mapDioException(e);
    } on FitUploadException {
      rethrow;
    } on Object catch (e) {
      throw FitUploadException(FitUploadErrorCode.unexpected, "$e");
    }
  }

  FitUploadException _mapDioException(DioException e) {
    final body = _decodeErrorBody(e.response?.data);
    final envelopeCode = switch (body?.error) {
      "bad_request" => FitUploadErrorCode.badRequest,
      "unauthorized" => FitUploadErrorCode.unauthorized,
      "forbidden" => FitUploadErrorCode.forbidden,
      "not_found" => FitUploadErrorCode.notFound,
      "snapshot_incomplete" => FitUploadErrorCode.snapshotIncomplete,
      "unknown_type" => FitUploadErrorCode.unknownType,
      "validation_failed" => FitUploadErrorCode.validationFailed,
      _ => null,
    };
    if (envelopeCode != null) {
      return FitUploadException(envelopeCode, body?.message, body?.issues);
    }
    final statusCode = switch (e.response?.statusCode) {
      400 => FitUploadErrorCode.badRequest,
      401 => FitUploadErrorCode.unauthorized,
      // 403 is the worker's ACL permission failure (post:create missing),
      // not an authentication problem.
      403 => FitUploadErrorCode.forbidden,
      404 => FitUploadErrorCode.notFound,
      409 => FitUploadErrorCode.snapshotIncomplete,
      422 => FitUploadErrorCode.validationFailed,
      _ => null,
    };
    if (statusCode != null) {
      return FitUploadException(statusCode, body?.message ?? e.message);
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return const FitUploadException(FitUploadErrorCode.network);
    }
    // The session interceptor wraps non-Dio failures (e.g. an
    // AccountApiException from a failed token refresh) in a bare
    // DioException with no message or response; surface the wrapped cause
    // instead of an opaque "unexpected".
    final cause = e.error;
    if (cause is AccountApiException) {
      if (cause.statusCode == null) {
        return FitUploadException(FitUploadErrorCode.network, cause.message);
      }
      return FitUploadException(FitUploadErrorCode.unexpected, "$cause");
    }
    final description = StringBuffer(e.message ?? e.type.name);
    if (cause != null) {
      description.write(": $cause");
    }
    return FitUploadException(FitUploadErrorCode.unexpected, description.toString());
  }

  ({String? error, String? message, Object? issues})? _decodeErrorBody(Object? data) {
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
    return (
      error: json["error"] as String?,
      message: json["message"] as String?,
      issues: json["issues"],
    );
  }
}
