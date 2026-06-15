import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "announcement.freezed.dart";
part "announcement.g.dart";

@freezed
abstract class AnnouncementRecord with _$AnnouncementRecord {
  const factory AnnouncementRecord({
    required String id,
    required String firstPublishedAt,
    required String updatedAt,
    required String contentHash,
    @Default(1) int recordVersion,
    @Default(IMap<String, String>.empty()) IMap<String, String> title,
    @Default(IMap<String, String>.empty()) IMap<String, String> excerpt,
    @Default(IList<String>.empty()) IList<String> tags,
    VersionRange? versionRange,
    @Default(false) bool isVersionUpdate,
  }) = _AnnouncementRecord;

  factory AnnouncementRecord.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementRecordFromJson(json);
}

@freezed
abstract class AnnouncementIndexEntry with _$AnnouncementIndexEntry {
  const factory AnnouncementIndexEntry({
    required String id,
    required String contentHash,
    @Default(false) bool isVersionUpdate,
    @Default(false) bool isRead,
  }) = _AnnouncementIndexEntry;

  factory AnnouncementIndexEntry.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementIndexEntryFromJson(json);
}

@freezed
abstract class AnnouncementIndex with _$AnnouncementIndex {
  const factory AnnouncementIndex({
    required int schemaVersion,
    @Default(IList<AnnouncementIndexEntry>.empty()) IList<AnnouncementIndexEntry> records,
  }) = _AnnouncementIndex;

  factory AnnouncementIndex.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementIndexFromJson(json);
}
