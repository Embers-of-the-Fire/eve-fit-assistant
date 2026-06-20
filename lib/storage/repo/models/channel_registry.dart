import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "channel_registry.freezed.dart";
part "channel_registry.g.dart";

/// Client-side channel registry (channels/channels.json).
///
/// schema.md §3.9
@freezed
abstract class ChannelRegistry with _$ChannelRegistry {
  const factory ChannelRegistry({
    required int schemaVersion,
    required String active,
    @Default(IMap<String, ChannelEntry>.empty()) IMap<String, ChannelEntry> channels,
  }) = _ChannelRegistry;

  factory ChannelRegistry.fromJson(Map<String, dynamic> json) => _$ChannelRegistryFromJson(json);
}

@freezed
abstract class ChannelEntry with _$ChannelEntry {
  const factory ChannelEntry({@Default(IMap<String, String>.empty()) IMap<String, String> label}) =
      _ChannelEntry;

  factory ChannelEntry.fromJson(Map<String, dynamic> json) => _$ChannelEntryFromJson(json);
}
