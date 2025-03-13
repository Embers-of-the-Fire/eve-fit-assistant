import 'package:eve_fit_assistant/storage/preference/preference.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:eve_fit_assistant/web/market/market.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'market.freezed.dart';

@freezed
abstract class MarketPriceCache with _$MarketPriceCache {
  const factory MarketPriceCache({
    required MarketPrice price,
    required DateTime timestamp,
  }) = _MarketPriceCache;

  const MarketPriceCache._();

  factory MarketPriceCache.now(MarketPrice price) =>
      MarketPriceCache(price: price, timestamp: DateTime.now());

  bool get isExpired => DateTime.now().difference(timestamp).inMinutes > 5;

  bool get isNotExpired => !isExpired;
}

class MarketStorage {
  final MapView<int, MarketPriceCache> _sePrices = MapView({});
  final MapView<int, MarketPriceCache> _tqPrices = MapView({});

  MarketStorage();

  ReadonlyMap<int, MarketPriceCache> getPrices(Server server) =>
      server == Server.tranquility ? _tqPrices.read : _sePrices.read;

  Future<MarketPrice> getPrice(int typeID, Server server) async {
    final prices = server == Server.tranquility ? _tqPrices : _sePrices;

    if (prices.read.containsKey(typeID)) {
      final price = prices.read[typeID]!;
      if (price.isNotExpired) {
        return price.price;
      }
    }
    final price = await switch (Preference().marketApi) {
      MarketApi.cEveMarket => CEveMarketResponse.request(typeID, server),
      MarketApi.esi => ESIMarketResponse.request(typeID, server),
    };
    prices.write[typeID] = MarketPriceCache.now(price);
    return price;
  }

  void clearCache([int? typeID]) {
    if (typeID != null) {
      _tqPrices.write.remove(typeID);
      _sePrices.write.remove(typeID);
    } else {
      _tqPrices.write.clear();
      _sePrices.write.clear();
    }
  }
}
