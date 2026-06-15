import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "release.freezed.dart";
part "release.g.dart";

@freezed
abstract class ReleaseItemRecord with _$ReleaseItemRecord {
  const factory ReleaseItemRecord({
    required String id,
    required String createdAt,
    required String version,
    required String versionUpdateAnnouncement,
    @Default(IMap<String, IMap<String, String>>.empty()) IMap<String, IMap<String, String>> files,
  }) = _ReleaseItemRecord;

  factory ReleaseItemRecord.fromJson(Map<String, dynamic> json) =>
      _$ReleaseItemRecordFromJson(json);
}
