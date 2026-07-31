import "package:freezed_annotation/freezed_annotation.dart";

part "report_schema.freezed.dart";
part "report_schema.g.dart";

@JsonEnum()
enum ReportPlatform {
  @JsonValue("Android")
  android,

  @JsonValue("iOS")
  ios,

  @JsonValue("Windows 10/11")
  windows,

  @JsonValue("Linux")
  linux,

  @JsonValue("Other")
  other,
}

String reportPlatformToJson(ReportPlatform p) => _$ReportPlatformEnumMap[p]!;

@freezed
abstract class BugReport with _$BugReport {
  const factory BugReport({
    required String title,
    required String summary,
    required String steps,
    required String expected,
    required String actual,
    required ReportPlatform platform,
    String? version,
    String? logs,
  }) = _BugReport;

  factory BugReport.fromJson(Map<String, dynamic> json) => _$BugReportFromJson(json);
}

@freezed
abstract class FeatureRequest with _$FeatureRequest {
  const factory FeatureRequest({
    required String title,
    required String problem,
    required String proposal,
    required String impact,
    String? alternatives,
    String? extra,
  }) = _FeatureRequest;

  factory FeatureRequest.fromJson(Map<String, dynamic> json) => _$FeatureRequestFromJson(json);
}

@freezed
abstract class IssueResult with _$IssueResult {
  const factory IssueResult({
    @JsonKey(name: "issue_url") required String issueUrl,
    @JsonKey(name: "issue_number") required int issueNumber,
  }) = _IssueResult;

  factory IssueResult.fromJson(Map<String, dynamic> json) => _$IssueResultFromJson(json);
}

@freezed
abstract class FieldError with _$FieldError {
  const factory FieldError({required String path, required String message}) = _FieldError;

  factory FieldError.fromJson(Map<String, dynamic> json) => _$FieldErrorFromJson(json);
}

@freezed
abstract class ValidationError with _$ValidationError {
  const factory ValidationError({required String error, List<FieldError>? details}) =
      _ValidationError;

  factory ValidationError.fromJson(Map<String, dynamic> json) => _$ValidationErrorFromJson(json);
}
