import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "channel_head_meta.freezed.dart";
part "channel_head_meta.g.dart";

/// Client-side channel head metadata (channels/{channel}/metadata.json).
///
/// schema.md §3.8
@freezed
abstract class ChannelHeadMeta with _$ChannelHeadMeta {
  const factory ChannelHeadMeta({
    required int schemaVersion,
    required String generationHash,
    required String updatedAt,
    @Default(IMap<String, String>.empty()) IMap<String, String> label,
  }) = _ChannelHeadMeta;

  factory ChannelHeadMeta.fromJson(Map<String, dynamic> json) => _$ChannelHeadMetaFromJson(json);
}
