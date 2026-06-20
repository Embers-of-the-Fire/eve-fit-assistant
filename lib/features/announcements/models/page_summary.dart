import "package:freezed_annotation/freezed_annotation.dart";

part "page_summary.freezed.dart";
part "page_summary.g.dart";

@freezed
abstract class PageSummary with _$PageSummary {
  const factory PageSummary({
    required String uuid,
    required DateTime publishedAt,
    required String minAppVersion,
    @Default(<String>[]) List<String> channels,
    @Default(0) int count,
    @Default(false) bool active,
  }) = _PageSummary;

  factory PageSummary.fromJson(Map<String, dynamic> json) => _$PageSummaryFromJson(json);
}
