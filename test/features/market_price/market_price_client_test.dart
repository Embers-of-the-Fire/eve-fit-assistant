import "package:dio/dio.dart";
import "package:eve_fit_assistant/features/market_price/models/models.dart";
import "package:eve_fit_assistant/features/market_price/remote/remote.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("MarketPriceClient.priceUriFor", () {
    test("builds the serenity URL", () {
      final client = MarketPriceClient(server: MarketServer.serenity, dio: Dio());
      expect(
        client.priceUriFor(587).toString(),
        "https://www.ceve-market.org/api/market/region/10000002/type/587.json",
      );
      client.dispose();
    });

    test("builds the tranquility URL", () {
      final client = MarketPriceClient(server: MarketServer.tranquility, dio: Dio());
      expect(
        client.priceUriFor(587).toString(),
        "https://www.ceve-market.org/tqapi/market/region/10000002/type/587.json",
      );
      client.dispose();
    });
  });
}
