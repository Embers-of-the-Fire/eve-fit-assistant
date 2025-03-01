// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'market.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$MarketPriceImpl _$$MarketPriceImplFromJson(Map<String, dynamic> json) =>
    _$MarketPriceImpl(
      typeID: (json['typeID'] as num).toInt(),
      server: $enumDecode(_$ServerEnumMap, json['server']),
      all: Price.fromJson(json['all'] as Map<String, dynamic>),
      buy: Price.fromJson(json['buy'] as Map<String, dynamic>),
      sell: Price.fromJson(json['sell'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$MarketPriceImplToJson(_$MarketPriceImpl instance) =>
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

_$PriceImpl _$$PriceImplFromJson(Map<String, dynamic> json) => _$PriceImpl(
      min: (json['min'] as num).toDouble(),
      max: (json['max'] as num).toDouble(),
      volume: (json['volume'] as num).toInt(),
    );

Map<String, dynamic> _$$PriceImplToJson(_$PriceImpl instance) =>
    <String, dynamic>{
      'min': instance.min,
      'max': instance.max,
      'volume': instance.volume,
    };

_$CEveMarketResponseImpl _$$CEveMarketResponseImplFromJson(
        Map<String, dynamic> json) =>
    _$CEveMarketResponseImpl(
      all: Price.fromJson(json['all'] as Map<String, dynamic>),
      buy: Price.fromJson(json['buy'] as Map<String, dynamic>),
      sell: Price.fromJson(json['sell'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$$CEveMarketResponseImplToJson(
        _$CEveMarketResponseImpl instance) =>
    <String, dynamic>{
      'all': instance.all,
      'buy': instance.buy,
      'sell': instance.sell,
    };
