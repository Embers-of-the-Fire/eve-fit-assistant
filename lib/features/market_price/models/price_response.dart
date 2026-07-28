/// Extracts an estimated unit price from a ceve-market price response.
///
/// The lowest sell price (`sell.min`) is the preferred estimate. Sections are
/// probed in preference order and the first positive numeric value wins.
/// Returns `null` when nothing usable is found.
///
/// The API response shape is:
/// ```json
/// {"all":{"max":…,"min":…,"volume":…},"buy":{…},"sell":{…}}
/// ```
double? extractEstimatedPrice(Map<String, dynamic> payload) {
  for (final section in ["sell", "all", "buy"]) {
    final value = payload[section];
    if (value is! Map<String, dynamic>) continue;
    final price = _firstPositiveNumber(value, const ["min", "max"]);
    if (price != null) return price;
  }
  return null;
}

double? extractSellPrice(Map<String, dynamic> payload) {
  final sell = payload["sell"];
  if (sell is Map<String, dynamic>) {
    return _firstPositiveNumber(sell, const ["min", "max"]);
  }
  return null;
}

double? extractBuyPrice(Map<String, dynamic> payload) {
  final buy = payload["buy"];
  if (buy is Map<String, dynamic>) {
    return _firstPositiveNumber(buy, const ["max", "min"]);
  }
  return null;
}

double? _firstPositiveNumber(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final raw = map[key];
    if (raw is num && raw > 0) return raw.toDouble();
  }
  return null;
}
