// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'market.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$MarketPriceCache {
  MarketPrice get price => throw _privateConstructorUsedError;
  DateTime get timestamp => throw _privateConstructorUsedError;

  /// Create a copy of MarketPriceCache
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MarketPriceCacheCopyWith<MarketPriceCache> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MarketPriceCacheCopyWith<$Res> {
  factory $MarketPriceCacheCopyWith(
          MarketPriceCache value, $Res Function(MarketPriceCache) then) =
      _$MarketPriceCacheCopyWithImpl<$Res, MarketPriceCache>;
  @useResult
  $Res call({MarketPrice price, DateTime timestamp});

  $MarketPriceCopyWith<$Res> get price;
}

/// @nodoc
class _$MarketPriceCacheCopyWithImpl<$Res, $Val extends MarketPriceCache>
    implements $MarketPriceCacheCopyWith<$Res> {
  _$MarketPriceCacheCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MarketPriceCache
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? price = null,
    Object? timestamp = null,
  }) {
    return _then(_value.copyWith(
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as MarketPrice,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }

  /// Create a copy of MarketPriceCache
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MarketPriceCopyWith<$Res> get price {
    return $MarketPriceCopyWith<$Res>(_value.price, (value) {
      return _then(_value.copyWith(price: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MarketPriceCacheImplCopyWith<$Res>
    implements $MarketPriceCacheCopyWith<$Res> {
  factory _$$MarketPriceCacheImplCopyWith(_$MarketPriceCacheImpl value,
          $Res Function(_$MarketPriceCacheImpl) then) =
      __$$MarketPriceCacheImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({MarketPrice price, DateTime timestamp});

  @override
  $MarketPriceCopyWith<$Res> get price;
}

/// @nodoc
class __$$MarketPriceCacheImplCopyWithImpl<$Res>
    extends _$MarketPriceCacheCopyWithImpl<$Res, _$MarketPriceCacheImpl>
    implements _$$MarketPriceCacheImplCopyWith<$Res> {
  __$$MarketPriceCacheImplCopyWithImpl(_$MarketPriceCacheImpl _value,
      $Res Function(_$MarketPriceCacheImpl) _then)
      : super(_value, _then);

  /// Create a copy of MarketPriceCache
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? price = null,
    Object? timestamp = null,
  }) {
    return _then(_$MarketPriceCacheImpl(
      price: null == price
          ? _value.price
          : price // ignore: cast_nullable_to_non_nullable
              as MarketPrice,
      timestamp: null == timestamp
          ? _value.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc

class _$MarketPriceCacheImpl extends _MarketPriceCache {
  const _$MarketPriceCacheImpl({required this.price, required this.timestamp})
      : super._();

  @override
  final MarketPrice price;
  @override
  final DateTime timestamp;

  @override
  String toString() {
    return 'MarketPriceCache(price: $price, timestamp: $timestamp)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MarketPriceCacheImpl &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp));
  }

  @override
  int get hashCode => Object.hash(runtimeType, price, timestamp);

  /// Create a copy of MarketPriceCache
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MarketPriceCacheImplCopyWith<_$MarketPriceCacheImpl> get copyWith =>
      __$$MarketPriceCacheImplCopyWithImpl<_$MarketPriceCacheImpl>(
          this, _$identity);
}

abstract class _MarketPriceCache extends MarketPriceCache {
  const factory _MarketPriceCache(
      {required final MarketPrice price,
      required final DateTime timestamp}) = _$MarketPriceCacheImpl;
  const _MarketPriceCache._() : super._();

  @override
  MarketPrice get price;
  @override
  DateTime get timestamp;

  /// Create a copy of MarketPriceCache
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MarketPriceCacheImplCopyWith<_$MarketPriceCacheImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
