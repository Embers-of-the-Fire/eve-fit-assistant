import "dart:async";

import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/active.dart";
import "package:eve_fit_assistant/storage/repo/checkout.dart";
import "package:eve_fit_assistant/storage/repo/compatibility.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_index.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/models/compatibility.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fpdart/fpdart.dart";

/// Resolves a [CheckoutRef] (from a fit or character) to a [CheckoutResolution].
///
/// Implements the 4-possibility resolution table from the spec:
/// installed → Compatible, historical → OfferReSync, known → OfferDownload,
/// not-in-index → remote query → add as known → OfferDownload,
/// not-found → Approximate.
class CheckoutResolver {
  const CheckoutResolver({
    required this.checkoutService,
    required this.remoteCatalogService,
    required this.activeService,
    required this.compatibilityService,
  });

  final CheckoutService checkoutService;

  final RemoteCatalogService remoteCatalogService;

  final ActiveService activeService;

  final CompatibilityService compatibilityService;

  /// Sync local-only resolution against the checkout index.
  ///
  /// Returns [CheckoutResolutionCompatible] when the checkout is installed locally,
  /// [CheckoutResolutionOfferReSync] when it exists as historical, or
  /// [CheckoutResolutionOfferDownload] when it is known but not downloaded.
  /// Returns [CheckoutResolutionApproximate] for checkouts not in the local index.
  ///
  /// This is the fast path for UIs that only need a local answer. For the remote
  /// fallback, use [resolveAsync].
  CheckoutResolution resolve(CheckoutRef ref) {
    if (ref.checkoutId.isEmpty) return const CheckoutResolutionApproximate(checkoutId: "");

    final state = checkoutService.lookup(ref.checkoutId);

    if (state.isNone()) {
      return CheckoutResolutionApproximate(checkoutId: ref.checkoutId);
    }

    switch (state.toNullable()!) {
      case CheckoutState.installed:
        return const CheckoutResolutionCompatible();
      case CheckoutState.historical:
        return CheckoutResolutionOfferReSync(
          checkoutId: ref.checkoutId,
          branchCheckoutId: _activeBranchCheckout(),
        );
      case CheckoutState.known:
        return CheckoutResolutionOfferDownload(checkoutId: ref.checkoutId);
    }
  }

  /// Async resolution with remote fallback for checkouts not in the local index.
  ///
  /// Same as [resolve] for locally-known checkouts, but queries the remote flat
  /// checkout registry for unknown checkouts on the given [channel].
  /// On success the checkout is added to the local index as [CheckoutState.known]
  /// and [CheckoutResolutionOfferDownload] is returned. Any remote error falls
  /// back to [CheckoutResolutionApproximate].
  Future<CheckoutResolution> resolveAsync(CheckoutRef ref, {required Channel channel}) async {
    if (ref.checkoutId.isEmpty) return const CheckoutResolutionApproximate(checkoutId: "");

    final state = checkoutService.lookup(ref.checkoutId);

    if (state.isSome()) {
      switch (state.toNullable()!) {
        case CheckoutState.installed:
          return const CheckoutResolutionCompatible();
        case CheckoutState.historical:
          return CheckoutResolutionOfferReSync(
            checkoutId: ref.checkoutId,
            branchCheckoutId: _activeBranchCheckout(),
          );
        case CheckoutState.known:
          return CheckoutResolutionOfferDownload(checkoutId: ref.checkoutId);
      }
    }

    return _resolveRemote(ref, channel);
  }

  /// Checks compatibility between [ref] and the active checkout.
  ///
  /// Implements the spec's 3-step rule via [CompatibilityService.check]:
  /// serverId mismatch → incompatible, checkoutId exact match → compatible,
  /// checkoutId differs → outdated. When no active record exists the result
  /// is [CompatibilityResult.incompatible].
  CompatibilityCheck checkActiveCompatibility(CheckoutRef ref) {
    final active = activeService.readActive();
    if (active.isNone()) {
      return const CompatibilityCheck(result: CompatibilityResult.incompatible);
    }

    final req = CompatibilityRequest(
      serverId: ref.serverId,
      checkoutId: ref.checkoutId,
      targetServerId: active.toNullable()!.serverId,
      targetCheckoutId: active.toNullable()!.checkoutId,
    );
    return compatibilityService.check(req);
  }

  /// Returns the active branch's HEAD checkout ID, or empty string if unknown.
  String _activeBranchCheckout() => activeService.getActiveCheckoutId().getOrElse(() => "");

  /// Queries the remote flat checkout registry for the given checkout on [channel].
  ///
  /// On success the checkout is added to the local index as [CheckoutState.known] and
  /// [CheckoutResolutionOfferDownload] is returned. Any remote error (404, network
  /// failure, parse failure) falls back to [CheckoutResolutionApproximate].
  Future<CheckoutResolution> _resolveRemote(CheckoutRef ref, Channel channel) async {
    final result = await remoteCatalogService.fetchCheckoutCatalog(channel, ref.checkoutId);
    return result.fold((_) => CheckoutResolutionApproximate(checkoutId: ref.checkoutId), (_) {
      checkoutService.markKnown(ref.checkoutId);
      return CheckoutResolutionOfferDownload(checkoutId: ref.checkoutId);
    });
  }
}
