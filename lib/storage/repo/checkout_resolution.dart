import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/checkout_registry_service.dart";
import "package:eve_fit_assistant/storage/repo/compatibility.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/models/compatibility.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";

/// Resolves a [CheckoutRef] (from a fit or character) to a [CheckoutResolution].
///
/// In the new schema, checkouts reference a resource snapshot. Resolution
/// checks if the referenced checkout exists locally and matches.
class CheckoutResolver {
  const CheckoutResolver({
    required this.checkoutRegistry,
    required this.remoteCatalogService,
    required this.compatibilityService,
  });

  final CheckoutRegistryService checkoutRegistry;
  final RemoteCatalogService remoteCatalogService;
  final CompatibilityService compatibilityService;

  /// Sync local-only resolution against the checkout registry.
  CheckoutResolution resolve(CheckoutRef ref) {
    if (ref.checkoutId.isEmpty) return const CheckoutResolutionApproximate(checkoutId: "");

    final registry = checkoutRegistry.readRegistry();
    if (registry.isNone()) {
      return CheckoutResolutionApproximate(checkoutId: ref.checkoutId);
    }

    final entry = registry.toNullable()!.checkouts[ref.checkoutId];
    if (entry == null) {
      return CheckoutResolutionOfferDownload(checkoutId: ref.checkoutId);
    }

    // Check if this is the active checkout
    final activeId = checkoutRegistry.activeCheckoutId();
    if (activeId.isSome() && activeId.toNullable() == ref.checkoutId) {
      return const CheckoutResolutionCompatible();
    }

    // Checkout exists but not active
    return CheckoutResolutionOfferReSync(checkoutId: ref.checkoutId);
  }

  /// Async resolution with remote fallback for unknown checkouts.
  Future<CheckoutResolution> resolveAsync(CheckoutRef ref, {required Channel channel}) async {
    if (ref.checkoutId.isEmpty) return const CheckoutResolutionApproximate(checkoutId: "");

    final local = resolve(ref);
    if (local is! CheckoutResolutionOfferDownload) return local;

    // Try to find the checkout on remote
    // In the new schema, we can verify if a checkout UUID exists by checking
    // if the resource snapshot is fetchable (via the remote generation chain).
    // For now, return OfferDownload — the fetch pipeline handles it.
    return local;
  }

  /// Checks compatibility between [ref] and the active checkout.
  CompatibilityCheck checkActiveCompatibility(CheckoutRef ref) {
    final activeEntry = checkoutRegistry.activeCheckoutEntry();
    if (activeEntry.isNone()) {
      return const CompatibilityCheck(result: CompatibilityResult.incompatible);
    }

    final activeId = checkoutRegistry.activeCheckoutId();

    final req = CompatibilityRequest(
      serverId: ref.serverId,
      checkoutId: ref.checkoutId,
      targetServerId: activeEntry.toNullable()!.serverId,
      targetCheckoutId: activeId.toNullable() ?? "",
    );
    return compatibilityService.check(req);
  }
}
