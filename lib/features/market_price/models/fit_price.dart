/// Aggregated estimated price for a fit.
///
/// Only produced once every requested type has resolved (priced or failed).
/// Types without an available price are silently excluded from [total].
class FitPriceSummary {
  const FitPriceSummary({
    required this.total,
    required this.pricedTypeCount,
    required this.unpricedTypeCount,
  });

  /// Total estimated price in ISK across all priced types and quantities.
  final double total;

  /// Number of distinct types that contributed a price.
  final int pricedTypeCount;

  /// Number of distinct types excluded because no price was available.
  final int unpricedTypeCount;
}
