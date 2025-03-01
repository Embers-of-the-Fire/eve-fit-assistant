part of 'market.dart';

@freezed
abstract class CEveMarketResponse with _$CEveMarketResponse {
  const factory CEveMarketResponse({
    required Price all,
    required Price buy,
    required Price sell,
  }) = _CEveMarketResponse;

  factory CEveMarketResponse.fromJson(Map<String, dynamic> json) =>
      _$CEveMarketResponseFromJson(json);

  static Future<MarketPrice> request(int typeID, Server server) async {
    final apiText = switch (server) {
      Server.tranquility => 'tqapi',
      Server.serenity => 'api',
    };
    final url =
        Uri.parse('https://www.ceve-market.org/$apiText/market/region/10000002/type/$typeID.json');
    final response = await http.get(url);
    final json = jsonDecode(response.body);
    final resp = CEveMarketResponse.fromJson(json);
    return MarketPrice(
      typeID: typeID,
      server: server,
      all: resp.all,
      buy: resp.buy,
      sell: resp.sell,
    );
  }
}
