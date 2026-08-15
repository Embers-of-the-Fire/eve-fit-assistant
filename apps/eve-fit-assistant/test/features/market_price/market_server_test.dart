import "package:eve_fit_assistant/features/market_price/models/models.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("MarketServer.parse", () {
    test("parses known server tags", () {
      expect(MarketServer.parse("serenity"), MarketServer.serenity);
      expect(MarketServer.parse("tranquility"), MarketServer.tranquility);
    });

    test("returns null for empty or unknown values", () {
      expect(MarketServer.parse(""), isNull);
      expect(MarketServer.parse("singularity"), isNull);
      expect(MarketServer.parse("SERENITY"), isNull);
    });
  });

  group("MarketServer.apiBase", () {
    test("serenity uses the default API path", () {
      expect(
        MarketServer.serenity.apiBase,
        "https://www.ceve-market.org/api/market/region/10000002/type/",
      );
    });

    test("tranquility uses the tqapi path", () {
      expect(
        MarketServer.tranquility.apiBase,
        "https://www.ceve-market.org/tqapi/market/region/10000002/type/",
      );
    });
  });
}
