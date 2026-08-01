import "dart:io" show Platform;

import "package:dio/dio.dart";
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/features/report/report_schema.dart";

const _workerOrigin = "https://api.efa-tech.dev";

class ReportApi {
  ReportApi()
    : _dio = createRemoteDio(
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        extraHeaders: {"Content-Type": "application/json"},
      );

  final Dio _dio;

  Future<IssueResult> submitBugReport(
    BugReport report,
    String language, {
    bool includeMetadata = true,
  }) async {
    final data = <String, dynamic>{
      "language": language,
      "title": "[Bug]: ${report.title}",
      "summary": report.summary,
      "steps": report.steps,
      "expected": report.expected,
      "actual": report.actual,
      "platform": reportPlatformToJson(report.platform),
      if (includeMetadata) "metadata": await _collectMetadata(),
      if (report.version != null && report.version!.isNotEmpty) "version": report.version,
      if (report.logs != null && report.logs!.isNotEmpty) "logs": report.logs,
    };
    return _post("bug-report", data);
  }

  Future<IssueResult> submitFeatureRequest(
    FeatureRequest req,
    String language, {
    bool includeMetadata = true,
  }) async {
    final data = <String, dynamic>{
      "language": language,
      "title": "[Feature]: ${req.title}",
      "problem": req.problem,
      "proposal": req.proposal,
      "impact": req.impact,
      if (includeMetadata) "metadata": await _collectMetadata(),
      if (req.alternatives != null && req.alternatives!.isNotEmpty)
        "alternatives": req.alternatives,
      if (req.extra != null && req.extra!.isNotEmpty) "extra": req.extra,
    };
    return _post("feature-request", data);
  }

  Future<IssueResult> _post(String endpoint, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        "$_workerOrigin/issue-redirect/$endpoint",
        data: data,
      );
      return IssueResult.fromJson(response.data!);
    } on DioException catch (e) {
      if (e.response != null && e.response?.data is Map<String, dynamic>) {
        final body = e.response!.data as Map<String, dynamic>;
        if (body.containsKey("error")) {
          throw ReportApiException(body["error"] as String? ?? "Unknown error");
        }
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.connectionError) {
        throw const ReportApiException("Network error: could not reach the report server.");
      }
      throw ReportApiException("An unexpected error occurred: ${e.message}");
    } on Object catch (e) {
      throw ReportApiException("Failed to process server response: $e");
    }
  }

  Future<Map<String, String>> _collectMetadata() async {
    try {
      final appVersion = await readFullAppVersion();
      return {
        "os_version": "${Platform.operatingSystem} ${Platform.operatingSystemVersion}",
        "app_version": appVersion,
      };
    } on Object {
      return {"os_version": "${Platform.operatingSystem} ${Platform.operatingSystemVersion}"};
    }
  }
}

class ReportApiException implements Exception {
  const ReportApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
