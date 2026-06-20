import "package:freezed_annotation/freezed_annotation.dart";

part "generation_meta.freezed.dart";
part "generation_meta.g.dart";

/// Generation metadata (channels/refs/{hash}/metadata.json).
///
/// schema.md §3.5
@freezed
abstract class GenerationMeta with _$GenerationMeta {
  const factory GenerationMeta({
    required int schemaVersion,
    required String channel,
    required String timestamp,
    String? parent,
    String? subject,
  }) = _GenerationMeta;

  factory GenerationMeta.fromJson(Map<String, dynamic> json) => _$GenerationMetaFromJson(json);
}
