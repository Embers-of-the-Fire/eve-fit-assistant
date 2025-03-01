// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'market.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_MarketPrice _$MarketPriceFromJson(Map<String, dynamic> json) => _MarketPrice(
      typeID: (json['typeID'] as num).toInt(),
      server: $enumDecode(_$ServerEnumMap, json['server']),
      all: Price.fromJson(json['all'] as Map<String, dynamic>),
      buy: Price.fromJson(json['buy'] as Map<String, dynamic>),
      sell: Price.fromJson(json['sell'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$MarketPriceToJson(_MarketPrice instance) =>
    <String, dynamic>{
      'typeID': instance.typeID,
      'server': _$ServerEnumMap[instance.server]!,
      'all': instance.all,
      'buy': instance.buy,
      'sell': instance.sell,
    };

const _$ServerEnumMap = {
  Server.tranquility: 'tranquility',
  Server.serenity: 'serenity',
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
