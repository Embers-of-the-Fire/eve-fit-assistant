// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'market.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MarketPrice _$MarketPriceFromJson(Map<String, dynamic> json) => _MarketPrice(
      typeID: (json['typeID'] as num).toInt(),
      server: $enumDecode(_$ServerEnumMap, json['server']),
      summary: PriceSummary.fromJson(json['summary'] as Map<String, dynamic>),
      orders: OrderGroup.fromJson(json['orders'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MarketPriceToJson(_MarketPrice instance) =>
    <String, dynamic>{
      'typeID': instance.typeID,
      'server': _$ServerEnumMap[instance.server]!,
      'summary': instance.summary,
      'orders': instance.orders,
    };

const _$ServerEnumMap = {
  Server.tranquility: 'tranquility',
  Server.serenity: 'serenity',
};

_PriceSummary _$PriceSummaryFromJson(Map<String, dynamic> json) =>
    _PriceSummary(
      all: Price.fromJson(json['all'] as Map<String, dynamic>),
      buy: Price.fromJson(json['buy'] as Map<String, dynamic>),
      sell: Price.fromJson(json['sell'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PriceSummaryToJson(_PriceSummary instance) =>
    <String, dynamic>{
      'all': instance.all,
      'buy': instance.buy,
      'sell': instance.sell,
    };

_Price _$PriceFromJson(Map<String, dynamic> json) => _Price(
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
      volume: (json['volume'] as num).toInt(),
    );

Map<String, dynamic> _$PriceToJson(_Price instance) => <String, dynamic>{
      'min': instance.min,
      'max': instance.max,
      'volume': instance.volume,
    };

_OrderGroup _$OrderGroupFromJson(Map<String, dynamic> json) => _OrderGroup(
      buy: (json['buy'] as List<dynamic>)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList(),
      sell: (json['sell'] as List<dynamic>)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$OrderGroupToJson(_OrderGroup instance) =>
    <String, dynamic>{
      'buy': instance.buy,
      'sell': instance.sell,
    };

_Order _$OrderFromJson(Map<String, dynamic> json) => _Order(
      volumeRemain: (json['volumeRemain'] as num).toInt(),
      volumeTotal: (json['volumeTotal'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
    );

Map<String, dynamic> _$OrderToJson(_Order instance) => <String, dynamic>{
      'volumeRemain': instance.volumeRemain,
      'volumeTotal': instance.volumeTotal,
      'price': instance.price,
    };

_CEveMarketResponse _$CEveMarketResponseFromJson(Map<String, dynamic> json) =>
    _CEveMarketResponse(
      all: Price.fromJson(json['all'] as Map<String, dynamic>),
      buy: Price.fromJson(json['buy'] as Map<String, dynamic>),
      sell: Price.fromJson(json['sell'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$CEveMarketResponseToJson(_CEveMarketResponse instance) =>
    <String, dynamic>{
      'all': instance.all,
      'buy': instance.buy,
      'sell': instance.sell,
    };

_ESIMarketResponse _$ESIMarketResponseFromJson(Map<String, dynamic> json) =>
    _ESIMarketResponse(
      typeID: (json['type_id'] as num).toInt(),
      volumeRemain: (json['volume_remain'] as num).toInt(),
      volumeTotal: (json['volume_total'] as num).toInt(),
      price: (json['price'] as num).toDouble(),
      isBuyOrder: json['is_buy_order'] as bool,
      locationID: (json['location_id'] as num).toInt(),
    );

Map<String, dynamic> _$ESIMarketResponseToJson(_ESIMarketResponse instance) =>
    <String, dynamic>{
      'type_id': instance.typeID,
      'volume_remain': instance.volumeRemain,
      'volume_total': instance.volumeTotal,
      'price': instance.price,
      'is_buy_order': instance.isBuyOrder,
      'location_id': instance.locationID,
    };
