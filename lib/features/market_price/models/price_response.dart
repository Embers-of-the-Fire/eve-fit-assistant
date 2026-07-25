/// Extracts an estimated unit price from a ceve-market price response.
///
/// The lowest sell price (`sell.min`) is the preferred estimate. The upstream
/// API is loosely specified, so parsing is defensive: known section/key
/// combinations are probed in preference order and the first positive numeric
/// value wins. Returns `null` when nothing usable is found.
double? extractEstimatedPrice(Map<String, dynamic> payload) {
  for (final section in ["sell", "all", "buy"]) {
    final value = payload[section];
    if (value is! Map<String, dynamic>) continue;
    final price = _firstPositiveNumber(value, const ["min", "avg", "average", "median", "max"]);
    if (price != null) return price;
  }
  return _firstPositiveNumber(payload, const ["avg", "average", "median", "price"]);
}

double? _firstPositiveNumber(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final raw = map[key];
    if (raw is num && raw > 0) return raw.toDouble();
  }
  return null;
}
