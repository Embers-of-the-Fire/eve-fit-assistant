import "package:eve_fit_assistant/features/announcements/models/announcement_entry.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "announcement_record.freezed.dart";

enum AnnouncementEntrySource { bundled, remote }

@freezed
abstract class AnnouncementRecord with _$AnnouncementRecord {
  const factory AnnouncementRecord({
    required String id,
    required AnnouncementEntrySource source,
    required String title,
    required String summary,
    required String bodyHash,
    required DateTime publishedAt,
    required String localeCode,
    @Default(<String>[]) List<String> tags,
    @Default(false) bool startup,
    String? minAppVersion,
    String? maxAppVersion,
    String? appVersion,
    @Default(false) bool isRead,
    @Default(false) bool isDismissed,
    AnnouncementEntry? entry,
  }) = _AnnouncementRecord;
}
