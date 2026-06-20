import "package:freezed_annotation/freezed_annotation.dart";

part "checkout_ref.freezed.dart";
part "checkout_ref.g.dart";

@freezed
abstract class CheckoutRef with _$CheckoutRef {
  const factory CheckoutRef({required String checkoutId, required String serverId}) = _CheckoutRef;

  factory CheckoutRef.fromJson(Map<String, dynamic> json) => _$CheckoutRefFromJson(json);
}
