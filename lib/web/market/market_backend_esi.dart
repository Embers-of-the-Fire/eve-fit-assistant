part of 'market.dart';

@freezed
abstract class ESIMarketResponse with _$ESIMarketResponse {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory ESIMarketResponse({
    // ignore: invalid_annotation_target
    @JsonKey(name: 'type_id') required int typeID,
    required int volumeRemain,
    required int volumeTotal,
    required double price,
    required bool isBuyOrder,
    // ignore: invalid_annotation_target
    @JsonKey(name: 'location_id') required int locationID,
  }) = _ESIMarketResponse;

  factory ESIMarketResponse.fromJson(Map<String, dynamic> json) =>
      _$ESIMarketResponseFromJson(json);

  static Future<List<ESIMarketResponse>> _request(int typeID, Server server) async {
    final apiRoot = switch (server) {
      Server.tranquility => 'esi.evetech.net',
      Server.serenity => 'ali-esi.evepc.163.com',
    };
    Uri getUrl(int page) => Uri.parse(
          'https://$apiRoot/latest/markets/10000002/orders/'
          '?order_type=all&page=$page&type_id=$typeID',
        );
    final firstPage = await http.get(getUrl(1));
    final pages = firstPage.headers['x-pages'].andThen(int.parse).unwrapOr(1);
    final futures = <Future<http.Response>>[
      Future.value(firstPage),
      for (var i = 2; i <= pages; i++) http.get(getUrl(i)),
    ].map((fut) async => (jsonDecode((await fut).body) as List<dynamic>)
        .map((u) => ESIMarketResponse.fromJson(u as Map<String, dynamic>)));
    final fut = await Future.wait(futures);
    return fut.flatten().toList();
  }

  static Future<MarketPrice> request(int typeID, Server server) async {
    final raw = await _request(typeID, server);
    final (rawBuy, rawSell) =
        raw.filter((u) => u.locationID == 60003760).partition((u) => u.isBuyOrder);
    final buy = rawBuy
        .map((u) => Order(
              volumeRemain: u.volumeRemain,
              volumeTotal: u.volumeTotal,
              price: u.price,
            ))
        .sortedByKey<Reversed<num>>((u) => Reversed(u.price))
        .toList();
    final sell = rawSell
        .map((u) => Order(
              volumeRemain: u.volumeRemain,
              volumeTotal: u.volumeTotal,
              price: u.price,
            ))
        .sortedByKey<num>((u) => u.price)
        .toList();
    final summary = PriceSummary(
      all: Price(
        min: raw.map((u) => u.price).min ?? 0,
        max: raw.map((u) => u.price).max ?? 0,
        volume: raw.map((u) => u.volumeTotal).sum(),
      ),
      buy: Price(
        min: buy.map((u) => u.price).min ?? 0,
        max: buy.map((u) => u.price).max ?? 0,
        volume: buy.map((u) => u.volumeTotal).sum(),
      ),
      sell: Price(
        min: sell.map((u) => u.price).min ?? 0,
        max: sell.map((u) => u.price).max ?? 0,
        volume: sell.map((u) => u.volumeTotal).sum(),
      ),
    );
    log('$typeID, $server');
    final orders = OrderGroup(buy: buy, sell: sell);
    return MarketPrice(
      typeID: typeID,
      server: server,
      summary: summary,
      orders: orders,
    );
  }
}
