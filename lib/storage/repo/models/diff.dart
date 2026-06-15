import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "diff.freezed.dart";
part "diff.g.dart";

@freezed
abstract class Diff with _$Diff {
  const factory Diff({
    required String from,
    required String to,
    required String fromCreatedAt,
    required String toCreatedAt,
    @Default(IList<DiffAdd>.empty()) IList<DiffAdd> adds,
    @Default(IList<DiffDelete>.empty()) IList<DiffDelete> deletes,
    @Default(IList<DiffModify>.empty()) IList<DiffModify> modifies,
  }) = _Diff;

  factory Diff.fromJson(Map<String, dynamic> json) => _$DiffFromJson(json);
}

@freezed
abstract class DiffAdd with _$DiffAdd {
  const factory DiffAdd({
    required String path,
    required String pathHash,
    required String hash,
    required int size,
  }) = _DiffAdd;

  factory DiffAdd.fromJson(Map<String, dynamic> json) => _$DiffAddFromJson(json);
}

@freezed
abstract class DiffDelete with _$DiffDelete {
  const factory DiffDelete({
    required String path,
    required String pathHash,
    required int size,
    String? hash,
  }) = _DiffDelete;

  factory DiffDelete.fromJson(Map<String, dynamic> json) => _$DiffDeleteFromJson(json);
}

@freezed
abstract class DiffModify with _$DiffModify {
  const factory DiffModify({
    required String path,
    required String pathHash,
    required String hash,
    required int size,
  }) = _DiffModify;

  factory DiffModify.fromJson(Map<String, dynamic> json) => _$DiffModifyFromJson(json);
}

@freezed
abstract class ReflogEntry with _$ReflogEntry {
  const factory ReflogEntry({
    required String id,
    required String timestamp,
    required String from,
    required String to,
  }) = _ReflogEntry;

  factory ReflogEntry.fromJson(Map<String, dynamic> json) => _$ReflogEntryFromJson(json);
}
