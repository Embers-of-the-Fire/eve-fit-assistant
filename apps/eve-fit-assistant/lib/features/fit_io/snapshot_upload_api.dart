import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:efa_proto/fit_request.pb.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

const _workerOrigin = "https://api.efa-tech.dev";
const _submitUrl = "$_workerOrigin/platform/storage/fit/submit";

/// Injectable seam for the upload API, so tests can substitute a fake transport.
final fitSnapshotUploadApiProvider = Provider<FitSnapshotUploadApi>(
  (Ref ref) => FitSnapshotUploadApi(),
);

/// Error codes reported by the fit storage worker, plus client-side categories.
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

/// Client for the remote fit storage service
/// (`worker/efa-platform-fit-storage`, `api.efa-tech.dev/platform/storage/fit`).
class FitSnapshotUploadApi {
  FitSnapshotUploadApi({Dio? dio})
    : _dio = dio ?? createRemoteDio(connectTimeout: const Duration(seconds: 10));

  final Dio _dio;

  /// Public URL of the stored snapshot for a given fit hash.
  static String byHashUrl(String fitHash) => "$_workerOrigin/platform/storage/fit/by-hash/$fitHash";

  Future<FitUploadResponse> submit(FitUploadRequest request, {required String token}) async {
    try {
      final response = await _dio.post<Uint8List>(
        _submitUrl,
        data: request.writeToBuffer(),
        options: Options(
          contentType: "application/x-protobuf",
          responseType: ResponseType.bytes,
          headers: {"Authorization": "Bearer $token"},
        ),
      );
      final data = response.data;
      if (data == null) {
        throw const FitUploadException(FitUploadErrorCode.unexpected);
      }
      return FitUploadResponse.fromBuffer(data);
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
