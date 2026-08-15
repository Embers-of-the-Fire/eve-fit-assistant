import "package:dio/dio.dart";
import "package:efa_compat/io.dart" show Platform;
import "package:eve_fit_assistant/features/remote_content/dio_factory.dart";
import "package:eve_fit_assistant/features/report/report_api.dart";
import "package:eve_fit_assistant/features/report/report_schema.dart";

const _workerOrigin = "https://api.efa-tech.dev";

/// The kind of manual feedback: an issue report about a specific document,
/// or a general question raised from the manual pages.
enum ManualFeedbackKind { report, question }

/// Payload for a manual feedback submission.
class ManualFeedback {
  const ManualFeedback({
    required this.kind,
    required this.title,
    required this.description,
    required this.locale,
    this.docId,
  });

  final ManualFeedbackKind kind;
  final String title;
  final String description;
  final String locale;

  /// Path-joined id of the document being reported (e.g. `fitting/modules`);
  /// required when [kind] is [ManualFeedbackKind.report].
  final String? docId;
}

/// Submits manual feedback to the issue-redirect worker (`docs-flag` and
/// `docs-question` endpoints, see `worker/issue-redirect`).
class ManualFeedbackApi {
  ManualFeedbackApi()
    : _dio = createRemoteDio(
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        extraHeaders: {"Content-Type": "application/json"},
      );

  final Dio _dio;

  Future<IssueResult> submit(ManualFeedback feedback, {bool includeMetadata = true}) =>
      switch (feedback.kind) {
        ManualFeedbackKind.report => _submitDocsFlag(feedback, includeMetadata),
        ManualFeedbackKind.question => _submitDocsQuestion(feedback, includeMetadata),
      };

  Future<IssueResult> _submitDocsFlag(ManualFeedback feedback, bool includeMetadata) async {
    final docId = feedback.docId;
    if (docId == null || docId.isEmpty) {
      throw const ReportApiException("Cannot submit a doc issue report without a document id.");
    }
    final data = <String, dynamic>{
      "language": feedback.locale,
      "topic": feedback.title,
      "pagePath": "/manual/$docId",
      "pageId": docId,
      "content": feedback.description,
      if (includeMetadata) "metadata": await _collectMetadata(),
    };
    return _post("docs-flag", data);
  }

  Future<IssueResult> _submitDocsQuestion(ManualFeedback feedback, bool includeMetadata) async {
    final data = <String, dynamic>{
      "language": feedback.locale,
      "topic": feedback.title,
      "content": feedback.description,
      if (includeMetadata) "metadata": await _collectMetadata(),
    };
    return _post("docs-question", data);
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
