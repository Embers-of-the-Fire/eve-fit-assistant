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

MarketPrice _$MarketPriceFromJson(Map<String, dynamic> json) {
  return _MarketPrice.fromJson(json);
}

/// @nodoc
mixin _$MarketPrice {
  int get typeID => throw _privateConstructorUsedError;
  Server get server => throw _privateConstructorUsedError;
  Price get all => throw _privateConstructorUsedError;
  Price get buy => throw _privateConstructorUsedError;
  Price get sell => throw _privateConstructorUsedError;

  /// Serializes this MarketPrice to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $MarketPriceCopyWith<MarketPrice> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $MarketPriceCopyWith<$Res> {
  factory $MarketPriceCopyWith(
          MarketPrice value, $Res Function(MarketPrice) then) =
      _$MarketPriceCopyWithImpl<$Res, MarketPrice>;
  @useResult
  $Res call({int typeID, Server server, Price all, Price buy, Price sell});

  $PriceCopyWith<$Res> get all;
  $PriceCopyWith<$Res> get buy;
  $PriceCopyWith<$Res> get sell;
}

/// @nodoc
class _$MarketPriceCopyWithImpl<$Res, $Val extends MarketPrice>
    implements $MarketPriceCopyWith<$Res> {
  _$MarketPriceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? typeID = null,
    Object? server = null,
    Object? all = null,
    Object? buy = null,
    Object? sell = null,
  }) {
    return _then(_value.copyWith(
      typeID: null == typeID
          ? _value.typeID
          : typeID // ignore: cast_nullable_to_non_nullable
              as int,
      server: null == server
          ? _value.server
          : server // ignore: cast_nullable_to_non_nullable
              as Server,
      all: null == all
          ? _value.all
          : all // ignore: cast_nullable_to_non_nullable
              as Price,
      buy: null == buy
          ? _value.buy
          : buy // ignore: cast_nullable_to_non_nullable
              as Price,
      sell: null == sell
          ? _value.sell
          : sell // ignore: cast_nullable_to_non_nullable
              as Price,
    ) as $Val);
  }

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get all {
    return $PriceCopyWith<$Res>(_value.all, (value) {
      return _then(_value.copyWith(all: value) as $Val);
    });
  }

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get buy {
    return $PriceCopyWith<$Res>(_value.buy, (value) {
      return _then(_value.copyWith(buy: value) as $Val);
    });
  }

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get sell {
    return $PriceCopyWith<$Res>(_value.sell, (value) {
      return _then(_value.copyWith(sell: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$MarketPriceImplCopyWith<$Res>
    implements $MarketPriceCopyWith<$Res> {
  factory _$$MarketPriceImplCopyWith(
          _$MarketPriceImpl value, $Res Function(_$MarketPriceImpl) then) =
      __$$MarketPriceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int typeID, Server server, Price all, Price buy, Price sell});

  @override
  $PriceCopyWith<$Res> get all;
  @override
  $PriceCopyWith<$Res> get buy;
  @override
  $PriceCopyWith<$Res> get sell;
}

/// @nodoc
class __$$MarketPriceImplCopyWithImpl<$Res>
    extends _$MarketPriceCopyWithImpl<$Res, _$MarketPriceImpl>
    implements _$$MarketPriceImplCopyWith<$Res> {
  __$$MarketPriceImplCopyWithImpl(
      _$MarketPriceImpl _value, $Res Function(_$MarketPriceImpl) _then)
      : super(_value, _then);

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? typeID = null,
    Object? server = null,
    Object? all = null,
    Object? buy = null,
    Object? sell = null,
  }) {
    return _then(_$MarketPriceImpl(
      typeID: null == typeID
          ? _value.typeID
          : typeID // ignore: cast_nullable_to_non_nullable
              as int,
      server: null == server
          ? _value.server
          : server // ignore: cast_nullable_to_non_nullable
              as Server,
      all: null == all
          ? _value.all
          : all // ignore: cast_nullable_to_non_nullable
              as Price,
      buy: null == buy
          ? _value.buy
          : buy // ignore: cast_nullable_to_non_nullable
              as Price,
      sell: null == sell
          ? _value.sell
          : sell // ignore: cast_nullable_to_non_nullable
              as Price,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$MarketPriceImpl implements _MarketPrice {
  const _$MarketPriceImpl(
      {required this.typeID,
      required this.server,
      required this.all,
      required this.buy,
      required this.sell});

  factory _$MarketPriceImpl.fromJson(Map<String, dynamic> json) =>
      _$$MarketPriceImplFromJson(json);

  @override
  final int typeID;
  @override
  final Server server;
  @override
  final Price all;
  @override
  final Price buy;
  @override
  final Price sell;

  @override
  String toString() {
    return 'MarketPrice(typeID: $typeID, server: $server, all: $all, buy: $buy, sell: $sell)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$MarketPriceImpl &&
            (identical(other.typeID, typeID) || other.typeID == typeID) &&
            (identical(other.server, server) || other.server == server) &&
            (identical(other.all, all) || other.all == all) &&
            (identical(other.buy, buy) || other.buy == buy) &&
            (identical(other.sell, sell) || other.sell == sell));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, typeID, server, all, buy, sell);

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$MarketPriceImplCopyWith<_$MarketPriceImpl> get copyWith =>
      __$$MarketPriceImplCopyWithImpl<_$MarketPriceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$MarketPriceImplToJson(
      this,
    );
  }
}

abstract class _MarketPrice implements MarketPrice {
  const factory _MarketPrice(
      {required final int typeID,
      required final Server server,
      required final Price all,
      required final Price buy,
      required final Price sell}) = _$MarketPriceImpl;

  factory _MarketPrice.fromJson(Map<String, dynamic> json) =
      _$MarketPriceImpl.fromJson;

  @override
  int get typeID;
  @override
  Server get server;
  @override
  Price get all;
  @override
  Price get buy;
  @override
  Price get sell;

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$MarketPriceImplCopyWith<_$MarketPriceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

Price _$PriceFromJson(Map<String, dynamic> json) {
  return _Price.fromJson(json);
}

/// @nodoc
mixin _$Price {
  double get min => throw _privateConstructorUsedError;
  double get max => throw _privateConstructorUsedError;
  int get volume => throw _privateConstructorUsedError;

  /// Serializes this Price to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $PriceCopyWith<Price> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $PriceCopyWith<$Res> {
  factory $PriceCopyWith(Price value, $Res Function(Price) then) =
      _$PriceCopyWithImpl<$Res, Price>;
  @useResult
  $Res call({double min, double max, int volume});
}

/// @nodoc
class _$PriceCopyWithImpl<$Res, $Val extends Price>
    implements $PriceCopyWith<$Res> {
  _$PriceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? min = null,
    Object? max = null,
    Object? volume = null,
  }) {
    return _then(_value.copyWith(
      min: null == min
          ? _value.min
          : min // ignore: cast_nullable_to_non_nullable
              as double,
      max: null == max
          ? _value.max
          : max // ignore: cast_nullable_to_non_nullable
              as double,
      volume: null == volume
          ? _value.volume
          : volume // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$PriceImplCopyWith<$Res> implements $PriceCopyWith<$Res> {
  factory _$$PriceImplCopyWith(
          _$PriceImpl value, $Res Function(_$PriceImpl) then) =
      __$$PriceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double min, double max, int volume});
}

/// @nodoc
class __$$PriceImplCopyWithImpl<$Res>
    extends _$PriceCopyWithImpl<$Res, _$PriceImpl>
    implements _$$PriceImplCopyWith<$Res> {
  __$$PriceImplCopyWithImpl(
      _$PriceImpl _value, $Res Function(_$PriceImpl) _then)
      : super(_value, _then);

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? min = null,
    Object? max = null,
    Object? volume = null,
  }) {
    return _then(_$PriceImpl(
      min: null == min
          ? _value.min
          : min // ignore: cast_nullable_to_non_nullable
              as double,
      max: null == max
          ? _value.max
          : max // ignore: cast_nullable_to_non_nullable
              as double,
      volume: null == volume
          ? _value.volume
          : volume // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$PriceImpl implements _Price {
  const _$PriceImpl(
      {required this.min, required this.max, required this.volume});

  factory _$PriceImpl.fromJson(Map<String, dynamic> json) =>
      _$$PriceImplFromJson(json);

  @override
  final double min;
  @override
  final double max;
  @override
  final int volume;

  @override
  String toString() {
    return 'Price(min: $min, max: $max, volume: $volume)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$PriceImpl &&
            (identical(other.min, min) || other.min == min) &&
            (identical(other.max, max) || other.max == max) &&
            (identical(other.volume, volume) || other.volume == volume));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, min, max, volume);

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$PriceImplCopyWith<_$PriceImpl> get copyWith =>
      __$$PriceImplCopyWithImpl<_$PriceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$PriceImplToJson(
      this,
    );
  }
}

abstract class _Price implements Price {
  const factory _Price(
      {required final double min,
      required final double max,
      required final int volume}) = _$PriceImpl;

  factory _Price.fromJson(Map<String, dynamic> json) = _$PriceImpl.fromJson;

  @override
  double get min;
  @override
  double get max;
  @override
  int get volume;

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$PriceImplCopyWith<_$PriceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

CEveMarketResponse _$CEveMarketResponseFromJson(Map<String, dynamic> json) {
  return _CEveMarketResponse.fromJson(json);
}

/// @nodoc
mixin _$CEveMarketResponse {
  Price get all => throw _privateConstructorUsedError;
  Price get buy => throw _privateConstructorUsedError;
  Price get sell => throw _privateConstructorUsedError;

  /// Serializes this CEveMarketResponse to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CEveMarketResponseCopyWith<CEveMarketResponse> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CEveMarketResponseCopyWith<$Res> {
  factory $CEveMarketResponseCopyWith(
          CEveMarketResponse value, $Res Function(CEveMarketResponse) then) =
      _$CEveMarketResponseCopyWithImpl<$Res, CEveMarketResponse>;
  @useResult
  $Res call({Price all, Price buy, Price sell});

  $PriceCopyWith<$Res> get all;
  $PriceCopyWith<$Res> get buy;
  $PriceCopyWith<$Res> get sell;
}

/// @nodoc
class _$CEveMarketResponseCopyWithImpl<$Res, $Val extends CEveMarketResponse>
    implements $CEveMarketResponseCopyWith<$Res> {
  _$CEveMarketResponseCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? all = null,
    Object? buy = null,
    Object? sell = null,
  }) {
    return _then(_value.copyWith(
      all: null == all
          ? _value.all
          : all // ignore: cast_nullable_to_non_nullable
              as Price,
      buy: null == buy
          ? _value.buy
          : buy // ignore: cast_nullable_to_non_nullable
              as Price,
      sell: null == sell
          ? _value.sell
          : sell // ignore: cast_nullable_to_non_nullable
              as Price,
    ) as $Val);
  }

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get all {
    return $PriceCopyWith<$Res>(_value.all, (value) {
      return _then(_value.copyWith(all: value) as $Val);
    });
  }

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get buy {
    return $PriceCopyWith<$Res>(_value.buy, (value) {
      return _then(_value.copyWith(buy: value) as $Val);
    });
  }

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get sell {
    return $PriceCopyWith<$Res>(_value.sell, (value) {
      return _then(_value.copyWith(sell: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$CEveMarketResponseImplCopyWith<$Res>
    implements $CEveMarketResponseCopyWith<$Res> {
  factory _$$CEveMarketResponseImplCopyWith(_$CEveMarketResponseImpl value,
          $Res Function(_$CEveMarketResponseImpl) then) =
      __$$CEveMarketResponseImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({Price all, Price buy, Price sell});

  @override
  $PriceCopyWith<$Res> get all;
  @override
  $PriceCopyWith<$Res> get buy;
  @override
  $PriceCopyWith<$Res> get sell;
}

/// @nodoc
class __$$CEveMarketResponseImplCopyWithImpl<$Res>
    extends _$CEveMarketResponseCopyWithImpl<$Res, _$CEveMarketResponseImpl>
    implements _$$CEveMarketResponseImplCopyWith<$Res> {
  __$$CEveMarketResponseImplCopyWithImpl(_$CEveMarketResponseImpl _value,
      $Res Function(_$CEveMarketResponseImpl) _then)
      : super(_value, _then);

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? all = null,
    Object? buy = null,
    Object? sell = null,
  }) {
    return _then(_$CEveMarketResponseImpl(
      all: null == all
          ? _value.all
          : all // ignore: cast_nullable_to_non_nullable
              as Price,
      buy: null == buy
          ? _value.buy
          : buy // ignore: cast_nullable_to_non_nullable
              as Price,
      sell: null == sell
          ? _value.sell
          : sell // ignore: cast_nullable_to_non_nullable
              as Price,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$CEveMarketResponseImpl implements _CEveMarketResponse {
  const _$CEveMarketResponseImpl(
      {required this.all, required this.buy, required this.sell});

  factory _$CEveMarketResponseImpl.fromJson(Map<String, dynamic> json) =>
      _$$CEveMarketResponseImplFromJson(json);

  @override
  final Price all;
  @override
  final Price buy;
  @override
  final Price sell;

  @override
  String toString() {
    return 'CEveMarketResponse(all: $all, buy: $buy, sell: $sell)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CEveMarketResponseImpl &&
            (identical(other.all, all) || other.all == all) &&
            (identical(other.buy, buy) || other.buy == buy) &&
            (identical(other.sell, sell) || other.sell == sell));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, all, buy, sell);

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CEveMarketResponseImplCopyWith<_$CEveMarketResponseImpl> get copyWith =>
      __$$CEveMarketResponseImplCopyWithImpl<_$CEveMarketResponseImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$CEveMarketResponseImplToJson(
      this,
    );
  }
}

abstract class _CEveMarketResponse implements CEveMarketResponse {
  const factory _CEveMarketResponse(
      {required final Price all,
      required final Price buy,
      required final Price sell}) = _$CEveMarketResponseImpl;

  factory _CEveMarketResponse.fromJson(Map<String, dynamic> json) =
      _$CEveMarketResponseImpl.fromJson;

  @override
  Price get all;
  @override
  Price get buy;
  @override
  Price get sell;

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CEveMarketResponseImplCopyWith<_$CEveMarketResponseImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
