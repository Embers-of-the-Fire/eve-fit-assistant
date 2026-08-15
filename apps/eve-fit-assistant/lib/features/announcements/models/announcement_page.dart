import "package:eve_fit_assistant/features/announcements/models/announcement_entry.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "announcement_page.freezed.dart";
part "announcement_page.g.dart";

@freezed
abstract class AnnouncementPage with _$AnnouncementPage {
  const factory AnnouncementPage({
    required String uuid,
    required DateTime publishedAt,
    @Default(50) int maxEntries,
    @Default(<AnnouncementEntry>[]) List<AnnouncementEntry> entries,
  }) = _AnnouncementPage;

  factory AnnouncementPage.fromJson(Map<String, dynamic> json) => _$AnnouncementPageFromJson(json);
}
