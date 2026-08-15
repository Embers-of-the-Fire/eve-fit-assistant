import "package:freezed_annotation/freezed_annotation.dart";

part "compatibility.freezed.dart";
part "compatibility.g.dart";

@JsonEnum()
enum CompatibilityResult { compatible, incompatible, outdated }

@freezed
abstract class CompatibilityCheck with _$CompatibilityCheck {
  const factory CompatibilityCheck({required CompatibilityResult result}) = _CompatibilityCheck;

  factory CompatibilityCheck.fromJson(Map<String, dynamic> json) =>
      _$CompatibilityCheckFromJson(json);
}

// ── CheckoutResolution ──────────────────────────────────────────────────────────

sealed class CheckoutResolution {
  const CheckoutResolution();
}

class CheckoutResolutionCompatible extends CheckoutResolution {
  const CheckoutResolutionCompatible();
}

class CheckoutResolutionOfferReSync extends CheckoutResolution {
  const CheckoutResolutionOfferReSync({required this.checkoutId});
  final String checkoutId;
}

class CheckoutResolutionOfferDownload extends CheckoutResolution {
  const CheckoutResolutionOfferDownload({required this.checkoutId});
  final String checkoutId;
}

class CheckoutResolutionApproximate extends CheckoutResolution {
  const CheckoutResolutionApproximate({required this.checkoutId});
  final String checkoutId;
}
