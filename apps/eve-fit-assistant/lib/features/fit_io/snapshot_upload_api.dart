import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:efa_proto/fit_request.pb.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

const _workerOrigin = "https://api.efa-tech.dev";
const _submitUrl = "$_workerOrigin/platform/internal/posts";

/// Injectable seam for the upload API, so tests can substitute a fake transport.
final fitSnapshotUploadApiProvider = Provider<FitSnapshotUploadApi>(
  (Ref ref) => FitSnapshotUploadApi(),
);

/// Error codes reported by the platform API worker, plus client-side categories.
enum FitUploadErrorCode {
  badRequest,
  unauthorized,
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

/// Result of `POST /platform/internal/posts` (docs/temp/api-unit/spec.md §6.1):
/// the post is a fresh publication event (UUID) backed by the content-addressed
/// fit.
class FitPostSubmitResult {
  const FitPostSubmitResult({
    required this.postId,
    required this.fitHash,
    required this.alreadyExisted,
  });

  factory FitPostSubmitResult.fromJson(Map<String, dynamic> json) => FitPostSubmitResult(
    postId: json["postId"] as String,
    fitHash: json["fitHash"] as String,
    alreadyExisted: json["alreadyExisted"] as bool,
  );

  final String postId;
  final String fitHash;
  final bool alreadyExisted;
}

/// Client for the platform's public front (`worker/efa-platform-api`,
/// `api.efa-tech.dev/platform/internal`).
class FitSnapshotUploadApi {
  FitSnapshotUploadApi({Dio? dio})
    : _dio = dio ?? createRemoteDio(connectTimeout: const Duration(seconds: 10));

  final Dio _dio;

  /// Public URL of the stored snapshot for a given fit hash (spec §6.2).
  static String byHashUrl(String fitHash) =>
      "$_workerOrigin/platform/internal/fits/$fitHash/snapshot";

  Future<FitPostSubmitResult> submit(FitUploadRequest request, {required String token}) async {
    try {
      final response = await _dio.post<Object>(
        _submitUrl,
        data: request.writeToBuffer(),
        options: Options(
          contentType: "application/x-protobuf",
          headers: {"Authorization": "Bearer $token"},
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        throw const FitUploadException(FitUploadErrorCode.unexpected);
      }
      return FitPostSubmitResult.fromJson(data);
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
      401 || 403 => FitUploadErrorCode.unauthorized,
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
    return FitUploadException(FitUploadErrorCode.unexpected, e.message);
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
