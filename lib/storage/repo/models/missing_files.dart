import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "missing_files.freezed.dart";
part "missing_files.g.dart";

@freezed
abstract class MissingFiles with _$MissingFiles {
  const factory MissingFiles({
    @Default(IList<String>.empty()) IList<String> missing,
    @Default(IList<String>.empty()) IList<String> hashMismatches,
  }) = _MissingFiles;

  factory MissingFiles.fromJson(Map<String, dynamic> json) => _$MissingFilesFromJson(json);
}
