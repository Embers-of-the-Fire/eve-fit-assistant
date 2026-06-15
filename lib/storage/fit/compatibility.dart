import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/compatibility.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/models/compatibility.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

enum FitCheckoutCompatibilityKind { compatible, outdated, incompatible }

class FitCheckoutCompatibility {
  const FitCheckoutCompatibility({
    required this.kind,
    required this.checkoutRef,
    required this.activeCheckoutId,
    required this.activeServerId,
  });

  const FitCheckoutCompatibility.compatible({
    required CheckoutRef checkoutRef,
    required String activeCheckoutId,
    required String activeServerId,
  }) : this(
         kind: FitCheckoutCompatibilityKind.compatible,
         checkoutRef: checkoutRef,
         activeCheckoutId: activeCheckoutId,
         activeServerId: activeServerId,
       );

  final FitCheckoutCompatibilityKind kind;
  final CheckoutRef checkoutRef;
  final String activeCheckoutId;
  final String activeServerId;

  bool get allowsEditing => kind == FitCheckoutCompatibilityKind.compatible;
  bool get requiresAttention => kind != FitCheckoutCompatibilityKind.compatible;
}

FitCheckoutCompatibility checkFitCompatibility(
  FitMetadata metadata, {
  required String activeCheckoutId,
  required String activeServerId,
}) {
  const compatibilityService = CompatibilityService();
  final checkoutRef = metadata.checkoutRef;

  if (checkoutRef.checkoutId.isEmpty) {
    return FitCheckoutCompatibility.compatible(
      checkoutRef: checkoutRef,
      activeCheckoutId: activeCheckoutId,
      activeServerId: activeServerId,
    );
  }

  final result = compatibilityService.check(
    CompatibilityRequest(
      serverId: checkoutRef.serverId,
      checkoutId: checkoutRef.checkoutId,
      targetServerId: activeServerId,
      targetCheckoutId: activeCheckoutId,
    ),
  );

  return FitCheckoutCompatibility(
    kind: switch (result.result) {
      CompatibilityResult.compatible => FitCheckoutCompatibilityKind.compatible,
      CompatibilityResult.outdated => FitCheckoutCompatibilityKind.outdated,
      CompatibilityResult.incompatible => FitCheckoutCompatibilityKind.incompatible,
    },
    checkoutRef: checkoutRef,
    activeCheckoutId: activeCheckoutId,
    activeServerId: activeServerId,
  );
}

final fitCheckoutCompatibilityProvider = Provider.family<FitCheckoutCompatibility?, String>((
  ref,
  fitId,
) {
  final metadata = ref.watch(fitRegistryManagerProvider.select((registry) => registry.fits[fitId]));
  if (metadata == null) {
    return null;
  }

  final active = ref.watch(activeCheckoutProvider);
  return checkFitCompatibility(
    metadata,
    activeCheckoutId: active.match(() => "", (a) => a.checkoutId),
    activeServerId: active.match(() => "", (a) => a.serverId),
  );
});
