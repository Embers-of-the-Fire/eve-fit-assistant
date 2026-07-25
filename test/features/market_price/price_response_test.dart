import "package:eve_fit_assistant/features/market_price/models/models.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("extractEstimatedPrice", () {
    test("prefers the lowest sell price (sell.min)", () {
      final price = extractEstimatedPrice({
        "all": {"max": 1750000, "min": 44010, "volume": 602},
        "buy": {"max": 400100, "min": 44010, "volume": 31},
        "sell": {"max": 1750000, "min": 996600, "volume": 571},
      });
      expect(price, 996600.0);
    });

    test("falls back through sections and keys in order", () {
      expect(
        extractEstimatedPrice({
          "sell": {"avg": 42.0},
        }),
        42.0,
      );
      expect(
        extractEstimatedPrice({
          "all": {"median": 7.0},
        }),
        7.0,
      );
      expect(
        extractEstimatedPrice({
          "buy": {"max": 3.0},
        }),
        3.0,
      );
      expect(extractEstimatedPrice({"avg": 11.0}), 11.0);
      expect(extractEstimatedPrice({"price": 5}), 5.0);
    });

    test("accepts integer values", () {
      expect(
        extractEstimatedPrice({
          "sell": {"min": 1000000},
        }),
        1000000.0,
      );
    });

    test("rejects non-positive and malformed values", () {
      expect(
        extractEstimatedPrice({
          "sell": {"min": 0},
        }),
        isNull,
      );
      expect(
        extractEstimatedPrice({
          "sell": {"min": -5},
        }),
        isNull,
      );
      expect(
        extractEstimatedPrice({
          "sell": {"min": "not a number"},
        }),
        isNull,
      );
      expect(extractEstimatedPrice({"sell": "not a map"}), isNull);
      expect(extractEstimatedPrice({}), isNull);
    });
  });
}
