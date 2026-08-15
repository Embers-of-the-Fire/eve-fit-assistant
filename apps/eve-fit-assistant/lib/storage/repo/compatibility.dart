import "package:eve_fit_assistant/storage/repo/models/compatibility.dart";

/// Pure data container for compatibility check inputs.
///
/// [checkoutId] may be empty to represent unknown/no checkout (the sentinel).
class CompatibilityRequest {
  const CompatibilityRequest({
    required this.serverId,
    required this.checkoutId,
    required this.targetServerId,
    required this.targetCheckoutId,
  });

  final String serverId;
  final String checkoutId;
  final String targetServerId;
  final String targetCheckoutId;
}

/// Pure-function 3-outcome checkout compatibility check.
///
/// Implements the spec's 3-step rule:
/// 1. serverId mismatch       → [CompatibilityResult.incompatible]
/// 2. checkoutId exact match  → [CompatibilityResult.compatible]
/// 3. checkoutId differs       → [CompatibilityResult.outdated]
///
/// Used by CheckoutResolver to determine fitting compatibility when the
/// active checkout differs from a fit or character's bound checkout.
class CompatibilityService {
  const CompatibilityService();

  CompatibilityCheck check(CompatibilityRequest req) {
    if (req.serverId != req.targetServerId) {
      return const CompatibilityCheck(result: CompatibilityResult.incompatible);
    }
    if (req.checkoutId == req.targetCheckoutId) {
      return const CompatibilityCheck(result: CompatibilityResult.compatible);
    }
    return const CompatibilityCheck(result: CompatibilityResult.outdated);
  }
}
