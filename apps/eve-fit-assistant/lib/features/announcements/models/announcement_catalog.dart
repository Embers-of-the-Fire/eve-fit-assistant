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

  const AnnouncementCatalog._();

  factory AnnouncementCatalog.empty() => const AnnouncementCatalog(schemaVersion: 1);

  factory AnnouncementCatalog.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementCatalogFromJson(json);

  /// Returns whether the catalog schema is supported by this client version.
  bool get isSupported => schemaVersion <= 1;
}
