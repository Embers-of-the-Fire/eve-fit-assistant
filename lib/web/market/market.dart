import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;

part 'market.freezed.dart';
part 'market.g.dart';
part 'market_backend_ceve.dart';

enum Server {
  tranquility,
  serenity,
}

@freezed
class MarketPrice with _$MarketPrice {
  const factory MarketPrice({
    required int typeID,
    required Server server,
    required Price all,
    required Price buy,
    required Price sell,
  }) = _MarketPrice;

  factory MarketPrice.fromJson(Map<String, dynamic> json) => _$MarketPriceFromJson(json);
}

@freezed
class Price with _$Price {
  const factory Price({
    required double min,
    required double max,
    required int volume,
  }) = _Price;

  factory Price.fromJson(Map<String, dynamic> json) => _$PriceFromJson(json);
}
