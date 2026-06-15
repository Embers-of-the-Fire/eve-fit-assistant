import "package:freezed_annotation/freezed_annotation.dart";

part "snapshot_meta.freezed.dart";
part "snapshot_meta.g.dart";

/// Resource snapshot metadata (assets/resources/{hash}/metadata.json).
///
/// schema.md §3.2
@freezed
abstract class ResourceSnapshotMeta with _$ResourceSnapshotMeta {
  const factory ResourceSnapshotMeta({
    required int schemaVersion,
    required String serverId,
    required String gameBuild,
    required String gameVersion,
    required int resourceCount,
    required String createdAt,
    String? description,
  }) = _ResourceSnapshotMeta;

  factory ResourceSnapshotMeta.fromJson(Map<String, dynamic> json) =>
      _$ResourceSnapshotMetaFromJson(json);
}

/// Release snapshot metadata (assets/releases/{hash}/metadata.json).
///
/// schema.md §3.3
@freezed
abstract class ReleaseSnapshotMeta with _$ReleaseSnapshotMeta {
  const factory ReleaseSnapshotMeta({
    required int schemaVersion,
    required int releaseCount,
    required String createdAt,
    String? versionMin,
    String? versionMax,
  }) = _ReleaseSnapshotMeta;

  factory ReleaseSnapshotMeta.fromJson(Map<String, dynamic> json) =>
      _$ReleaseSnapshotMetaFromJson(json);
}

/// Announcement snapshot metadata (assets/announcements/{hash}/metadata.json).
///
/// schema.md §3.4
@freezed
abstract class AnnouncementSnapshotMeta with _$AnnouncementSnapshotMeta {
  const factory AnnouncementSnapshotMeta({
    required int schemaVersion,
    required int announcementCount,
    required String createdAt,
  }) = _AnnouncementSnapshotMeta;

  factory AnnouncementSnapshotMeta.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementSnapshotMetaFromJson(json);
}
