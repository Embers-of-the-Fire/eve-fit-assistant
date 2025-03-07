import 'dart:convert';
import 'dart:developer';

import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;

part 'market.freezed.dart';
part 'market.g.dart';
part 'market_backend_ceve.dart';
part 'market_backend_esi.dart';

enum Server {
  tranquility,
  serenity,
}

@freezed
abstract class MarketPrice with _$MarketPrice {
  const factory MarketPrice({
    required int typeID,
    required Server server,
    required PriceSummary summary,
    required OrderGroup orders,
  }) = _MarketPrice;

  factory MarketPrice.fromJson(Map<String, dynamic> json) => _$MarketPriceFromJson(json);
}

@freezed
abstract class PriceSummary with _$PriceSummary {
  const factory PriceSummary({
    required Price all,
    required Price buy,
    required Price sell,
  }) = _PriceSummary;

  factory PriceSummary.fromJson(Map<String, dynamic> json) => _$PriceSummaryFromJson(json);
}

@freezed
abstract class Price with _$Price {
  const factory Price({
    required double min,
    required double max,
    required int volume,
  }) = _Price;

  factory Price.fromJson(Map<String, dynamic> json) => _$PriceFromJson(json);
}

@freezed
abstract class OrderGroup with _$OrderGroup {
  const factory OrderGroup({
    /// `buy` orders should be sorted in descending order by price.
    required List<Order> buy,
    /// `sell` orders should be sorted in ascending order by price.
    required List<Order> sell,
  }) = _OrderGroup;

  factory OrderGroup.fromJson(Map<String, dynamic> json) => _$OrderGroupFromJson(json);
}

@freezed
abstract class Order with _$Order {
  const factory Order({
    required int volumeRemain,
    required int volumeTotal,
    required double price,
  }) = _Order;

  factory Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);
}
