import "package:freezed_annotation/freezed_annotation.dart";

part "localization_meta.freezed.dart";
part "localization_meta.g.dart";

@freezed
abstract class LocalizationMeta with _$LocalizationMeta {
  const factory LocalizationMeta({
    required String title,
    required String summary,
    required String bodyHash,
  }) = _LocalizationMeta;

  factory LocalizationMeta.fromJson(Map<String, dynamic> json) => _$LocalizationMetaFromJson(json);
}
