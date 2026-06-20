import "package:eve_fit_assistant/features/announcements/models/page_summary.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "announcement_catalog.freezed.dart";
part "announcement_catalog.g.dart";

@freezed
abstract class AnnouncementCatalog with _$AnnouncementCatalog {
  const factory AnnouncementCatalog({
    required int schemaVersion,
    @Default(<PageSummary>[]) List<PageSummary> pages,
  }) = _AnnouncementCatalog;

  factory AnnouncementCatalog.empty() => const AnnouncementCatalog(schemaVersion: 1);

  factory AnnouncementCatalog.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementCatalogFromJson(json);
}
