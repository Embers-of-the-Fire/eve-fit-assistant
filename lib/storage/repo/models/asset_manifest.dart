import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "asset_manifest.freezed.dart";
part "asset_manifest.g.dart";

@freezed
abstract class AssetManifest with _$AssetManifest {
  const factory AssetManifest({
    required int assetsVersion,
    @Default(IMap<String, AssetFile>.empty()) IMap<String, AssetFile> files,
  }) = _AssetManifest;

  factory AssetManifest.fromJson(Map<String, dynamic> json) => _$AssetManifestFromJson(json);
}
