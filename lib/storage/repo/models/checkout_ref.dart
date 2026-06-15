import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "checkout_ref.freezed.dart";
part "checkout_ref.g.dart";

@freezed
abstract class CheckoutRef with _$CheckoutRef {
  const factory CheckoutRef({
    required String checkoutId,
    required String serverId,
    required GameMetadata metadata,
  }) = _CheckoutRef;

  factory CheckoutRef.fromJson(Map<String, dynamic> json) => _$CheckoutRefFromJson(json);
}
