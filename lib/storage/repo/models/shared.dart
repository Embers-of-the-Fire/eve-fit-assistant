import "package:freezed_annotation/freezed_annotation.dart";

part "shared.freezed.dart";
part "shared.g.dart";

@freezed
abstract class GameMetadata with _$GameMetadata {
  const factory GameMetadata({
    required String gameServer,
    required String gameBuild,
    required String gameVersion,
  }) = _GameMetadata;

  factory GameMetadata.fromJson(Map<String, dynamic> json) => _$GameMetadataFromJson(json);
}

@freezed
abstract class VersionRange with _$VersionRange {
  const factory VersionRange({String? min, String? max}) = _VersionRange;

  factory VersionRange.fromJson(Map<String, dynamic> json) => _$VersionRangeFromJson(json);
}

@freezed
abstract class AssetFile with _$AssetFile {
  const factory AssetFile({required String pathHash, required String hash, required int size}) =
      _AssetFile;

  factory AssetFile.fromJson(Map<String, dynamic> json) => _$AssetFileFromJson(json);
}
