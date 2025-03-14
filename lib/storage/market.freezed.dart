// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'market.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MarketPriceCache {
  MarketPrice get price;
  DateTime get timestamp;

  /// Create a copy of MarketPriceCache
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MarketPriceCacheCopyWith<MarketPriceCache> get copyWith =>
      _$MarketPriceCacheCopyWithImpl<MarketPriceCache>(this as MarketPriceCache, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MarketPriceCache &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.timestamp, timestamp) || other.timestamp == timestamp));
  }

  @override
  int get hashCode => Object.hash(runtimeType, price, timestamp);

  @override
  String toString() {
    return 'MarketPriceCache(price: $price, timestamp: $timestamp)';
  }
}

/// @nodoc
abstract mixin class $MarketPriceCacheCopyWith<$Res> {
  factory $MarketPriceCacheCopyWith(MarketPriceCache value, $Res Function(MarketPriceCache) _then) =
      _$MarketPriceCacheCopyWithImpl;
  @useResult
  $Res call({MarketPrice price, DateTime timestamp});

  $MarketPriceCopyWith<$Res> get price;
}

/// @nodoc
class _$MarketPriceCacheCopyWithImpl<$Res> implements $MarketPriceCacheCopyWith<$Res> {
  _$MarketPriceCacheCopyWithImpl(this._self, this._then);

  final MarketPriceCache _self;
  final $Res Function(MarketPriceCache) _then;

  /// Create a copy of MarketPriceCache
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? price = null,
    Object? timestamp = null,
  }) {
    return _then(_self.copyWith(
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as MarketPrice,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }

  /// Create a copy of MarketPriceCache
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MarketPriceCopyWith<$Res> get price {
    return $MarketPriceCopyWith<$Res>(_self.price, (value) {
      return _then(_self.copyWith(price: value));
    });
  }
}

/// @nodoc

class _MarketPriceCache extends MarketPriceCache {
  const _MarketPriceCache({required this.price, required this.timestamp}) : super._();

  @override
  final MarketPrice price;
  @override
  final DateTime timestamp;

  /// Create a copy of MarketPriceCache
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MarketPriceCacheCopyWith<_MarketPriceCache> get copyWith =>
      __$MarketPriceCacheCopyWithImpl<_MarketPriceCache>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MarketPriceCache &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.timestamp, timestamp) || other.timestamp == timestamp));
  }

  @override
  int get hashCode => Object.hash(runtimeType, price, timestamp);

  @override
  String toString() {
    return 'MarketPriceCache(price: $price, timestamp: $timestamp)';
  }
}

/// @nodoc
abstract mixin class _$MarketPriceCacheCopyWith<$Res> implements $MarketPriceCacheCopyWith<$Res> {
  factory _$MarketPriceCacheCopyWith(
          _MarketPriceCache value, $Res Function(_MarketPriceCache) _then) =
      __$MarketPriceCacheCopyWithImpl;
  @override
  @useResult
  $Res call({MarketPrice price, DateTime timestamp});

  @override
  $MarketPriceCopyWith<$Res> get price;
}

/// @nodoc
class __$MarketPriceCacheCopyWithImpl<$Res> implements _$MarketPriceCacheCopyWith<$Res> {
  __$MarketPriceCacheCopyWithImpl(this._self, this._then);

  final _MarketPriceCache _self;
  final $Res Function(_MarketPriceCache) _then;

  /// Create a copy of MarketPriceCache
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? price = null,
    Object? timestamp = null,
  }) {
    return _then(_MarketPriceCache(
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as MarketPrice,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }

  /// Create a copy of MarketPriceCache
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MarketPriceCopyWith<$Res> get price {
    return $MarketPriceCopyWith<$Res>(_self.price, (value) {
      return _then(_self.copyWith(price: value));
    });
  }
}

// dart format on
