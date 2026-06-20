import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "diff.freezed.dart";
part "diff.g.dart";

/// A diff between two resource index snapshots.
///
/// Computed on-demand from two ResourceIndex protobufs.
/// No longer stored — computed when needed.
@freezed
abstract class Diff with _$Diff {
  const factory Diff({
    required String fromSnapshotHash,
    required String toSnapshotHash,
    @Default(IList<DiffAdd>.empty()) IList<DiffAdd> adds,
    @Default(IList<DiffDelete>.empty()) IList<DiffDelete> deletes,
    @Default(IList<DiffModify>.empty()) IList<DiffModify> modifies,
  }) = _Diff;

  factory Diff.fromJson(Map<String, dynamic> json) => _$DiffFromJson(json);
}

@freezed
abstract class DiffAdd with _$DiffAdd {
  const factory DiffAdd({
    required String logicalPath,
    required String resourceId,
    required String contentHash,
    required int size,
  }) = _DiffAdd;

  factory DiffAdd.fromJson(Map<String, dynamic> json) => _$DiffAddFromJson(json);
}

@freezed
abstract class DiffDelete with _$DiffDelete {
  const factory DiffDelete({
    required String logicalPath,
    required String resourceId,
    required int size,
    String? contentHash,
  }) = _DiffDelete;

  factory DiffDelete.fromJson(Map<String, dynamic> json) => _$DiffDeleteFromJson(json);
}

@freezed
abstract class DiffModify with _$DiffModify {
  const factory DiffModify({
    required String logicalPath,
    required String resourceId,
    required String contentHash,
    required int size,
  }) = _DiffModify;

  factory DiffModify.fromJson(Map<String, dynamic> json) => _$DiffModifyFromJson(json);
}
