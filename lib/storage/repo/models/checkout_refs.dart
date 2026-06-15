import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "checkout_refs.freezed.dart";
part "checkout_refs.g.dart";

@freezed
abstract class CheckoutRefs with _$CheckoutRefs {
  const factory CheckoutRefs({
    required int schemaVersion,
    @Default(IMap<String, CheckoutRefRecord>.empty()) IMap<String, CheckoutRefRecord> refs,
  }) = _CheckoutRefs;

  factory CheckoutRefs.fromJson(Map<String, dynamic> json) => _$CheckoutRefsFromJson(json);
}

@freezed
abstract class CheckoutRefRecord with _$CheckoutRefRecord {
  const factory CheckoutRefRecord({
    required String id,
    required String installedAt,
    required String remoteCreatedAt,
    required String serverId,
    required GameMetadata metadata,
    String? parentCheckoutId,
  }) = _CheckoutRefRecord;

  factory CheckoutRefRecord.fromJson(Map<String, dynamic> json) =>
      _$CheckoutRefRecordFromJson(json);
}
