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

class TypePriceEstimate {
  const TypePriceEstimate({this.sell, this.buy});

  final double? sell;
  final double? buy;
}

class FitPriceLineItem {
  const FitPriceLineItem({
    required this.typeId,
    required this.quantity,
    required this.unitSell,
    required this.unitBuy,
  });

  final int typeId;
  final int quantity;
  final double? unitSell;
  final double? unitBuy;

  double? get totalSell => unitSell != null ? unitSell! * quantity : null;
  double? get totalBuy => unitBuy != null ? unitBuy! * quantity : null;
}

/// Aggregated estimated price for a fit, broken down by line item.
///
/// The `totalSell` refers to the sum of the sell prices of all the items,
/// which means if you want to *buy* the fit, you need to pay this amount.
/// Conversely, the `totalBuy` refers to the sum of the buy prices of all the items,
/// which means if you want to *sell* the fit, you will receive this amount.
class FitPriceBreakdown {
  const FitPriceBreakdown({required this.items, required this.totalSell, required this.totalBuy});

  final List<FitPriceLineItem> items;
  final double? totalSell;
  final double? totalBuy;
}
