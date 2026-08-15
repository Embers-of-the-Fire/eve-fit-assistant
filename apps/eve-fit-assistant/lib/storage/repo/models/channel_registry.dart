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
    @Default(IMap<String, ChannelEntry>.empty())
    @JsonKey(fromJson: _channelsFromJson, toJson: _channelsToJson)
    IMap<String, ChannelEntry> channels,
  }) = _ChannelRegistry;

  factory ChannelRegistry.fromJson(Map<String, dynamic> json) => _$ChannelRegistryFromJson(json);
}

IMap<String, ChannelEntry> _channelsFromJson(Object? json) {
  if (json is! Map<String, dynamic>) return const IMap.empty();
  return IMap.fromEntries(
    json.entries.map((entry) {
      final value = entry.value;
      if (value is ChannelEntry) {
        // Defensive: some legacy cached payloads may contain already-deserialized entries.
        return MapEntry(entry.key, value);
      }
      return MapEntry(entry.key, ChannelEntry.fromJson(value as Map<String, dynamic>));
    }),
  );
}

Map<String, dynamic> _channelsToJson(IMap<String, ChannelEntry> channels) {
  final result = <String, dynamic>{};
  for (final entry in channels.entries) {
    result[entry.key] = entry.value.toJson();
  }
  return result;
}

@freezed
abstract class ChannelEntry with _$ChannelEntry {
  const factory ChannelEntry({@Default(IMap<String, String>.empty()) IMap<String, String> label}) =
      _ChannelEntry;

  factory ChannelEntry.fromJson(Map<String, dynamic> json) => _$ChannelEntryFromJson(json);
}
