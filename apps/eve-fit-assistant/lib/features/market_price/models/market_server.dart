/// Market server tag declared by a snapshot's metadata (`marketServer`).
///
/// The tag selects the ceve-market API base used for price lookups. URL
/// knowledge is kept entirely inside the market price feature; the snapshot
/// only carries this opaque server identifier.
enum MarketServer {
  serenity,
  tranquility;

  /// Parses a snapshot `marketServer` value. Returns `null` for empty or
  /// unknown values, which disables the market price feature.
  static MarketServer? parse(String value) => switch (value) {
    "serenity" => MarketServer.serenity,
    "tranquility" => MarketServer.tranquility,
    _ => null,
  };

  /// Base URL for per-type price lookups; the typeID plus `.json` is appended
  /// to build a request URI.
  String get apiBase => switch (this) {
    MarketServer.serenity => "https://www.ceve-market.org/api/market/region/10000002/type/",
    MarketServer.tranquility => "https://www.ceve-market.org/tqapi/market/region/10000002/type/",
  };
}
