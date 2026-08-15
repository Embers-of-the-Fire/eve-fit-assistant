import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "checkout_registry.freezed.dart";
part "checkout_registry.g.dart";

/// Client-side checkout registry (checkouts/checkouts.json).
///
/// schema.md §3.10
@freezed
abstract class CheckoutRegistry with _$CheckoutRegistry {
  const factory CheckoutRegistry({
    required int schemaVersion,
    String? activeCheckoutId,
    @Default(IMap<String, CheckoutRegistryEntry>.empty())
    IMap<String, CheckoutRegistryEntry> checkouts,
  }) = _CheckoutRegistry;

  factory CheckoutRegistry.fromJson(Map<String, dynamic> json) => _$CheckoutRegistryFromJson(json);
}

@freezed
abstract class CheckoutRegistryEntry with _$CheckoutRegistryEntry {
  const factory CheckoutRegistryEntry({
    required String channel,
    required String serverId,
    required String resourceSnapshotHash,
    required String createdAt,
    @Default(IMap<String, String>.empty()) IMap<String, String> name,
  }) = _CheckoutRegistryEntry;

  factory CheckoutRegistryEntry.fromJson(Map<String, dynamic> json) =>
      _$CheckoutRegistryEntryFromJson(json);
}
