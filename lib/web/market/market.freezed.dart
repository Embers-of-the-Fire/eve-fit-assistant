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
mixin _$MarketPrice {
  int get typeID;
  Server get server;
  Price get all;
  Price get buy;
  Price get sell;

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MarketPriceCopyWith<MarketPrice> get copyWith =>
      _$MarketPriceCopyWithImpl<MarketPrice>(this as MarketPrice, _$identity);

  /// Serializes this MarketPrice to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MarketPrice &&
            (identical(other.typeID, typeID) || other.typeID == typeID) &&
            (identical(other.server, server) || other.server == server) &&
            (identical(other.all, all) || other.all == all) &&
            (identical(other.buy, buy) || other.buy == buy) &&
            (identical(other.sell, sell) || other.sell == sell));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, typeID, server, all, buy, sell);

  @override
  String toString() {
    return 'MarketPrice(typeID: $typeID, server: $server, all: $all, buy: $buy, sell: $sell)';
  }
}

/// @nodoc
abstract mixin class $MarketPriceCopyWith<$Res> {
  factory $MarketPriceCopyWith(
          MarketPrice value, $Res Function(MarketPrice) _then) =
      _$MarketPriceCopyWithImpl;
  @useResult
  $Res call({int typeID, Server server, Price all, Price buy, Price sell});

  $PriceCopyWith<$Res> get all;
  $PriceCopyWith<$Res> get buy;
  $PriceCopyWith<$Res> get sell;
}

/// @nodoc
class _$MarketPriceCopyWithImpl<$Res> implements $MarketPriceCopyWith<$Res> {
  _$MarketPriceCopyWithImpl(this._self, this._then);

  final MarketPrice _self;
  final $Res Function(MarketPrice) _then;

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
    return _then(_self.copyWith(
      typeID: null == typeID
          ? _self.typeID
          : typeID // ignore: cast_nullable_to_non_nullable
              as int,
      server: null == server
          ? _self.server
          : server // ignore: cast_nullable_to_non_nullable
              as Server,
      all: null == all
          ? _self.all
          : all // ignore: cast_nullable_to_non_nullable
              as Price,
      buy: null == buy
          ? _self.buy
          : buy // ignore: cast_nullable_to_non_nullable
              as Price,
      sell: null == sell
          ? _self.sell
          : sell // ignore: cast_nullable_to_non_nullable
              as Price,
    ));
  }

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get all {
    return $PriceCopyWith<$Res>(_self.all, (value) {
      return _then(_self.copyWith(all: value));
    });
  }

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get buy {
    return $PriceCopyWith<$Res>(_self.buy, (value) {
      return _then(_self.copyWith(buy: value));
    });
  }

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get sell {
    return $PriceCopyWith<$Res>(_self.sell, (value) {
      return _then(_self.copyWith(sell: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _MarketPrice implements MarketPrice {
  const _MarketPrice(
      {required this.typeID,
      required this.server,
      required this.all,
      required this.buy,
      required this.sell});
  factory _MarketPrice.fromJson(Map<String, dynamic> json) =>
      _$MarketPriceFromJson(json);

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

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MarketPriceCopyWith<_MarketPrice> get copyWith =>
      __$MarketPriceCopyWithImpl<_MarketPrice>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MarketPriceToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MarketPrice &&
            (identical(other.typeID, typeID) || other.typeID == typeID) &&
            (identical(other.server, server) || other.server == server) &&
            (identical(other.all, all) || other.all == all) &&
            (identical(other.buy, buy) || other.buy == buy) &&
            (identical(other.sell, sell) || other.sell == sell));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, typeID, server, all, buy, sell);

  @override
  String toString() {
    return 'MarketPrice(typeID: $typeID, server: $server, all: $all, buy: $buy, sell: $sell)';
  }
}

/// @nodoc
abstract mixin class _$MarketPriceCopyWith<$Res>
    implements $MarketPriceCopyWith<$Res> {
  factory _$MarketPriceCopyWith(
          _MarketPrice value, $Res Function(_MarketPrice) _then) =
      __$MarketPriceCopyWithImpl;
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
class __$MarketPriceCopyWithImpl<$Res> implements _$MarketPriceCopyWith<$Res> {
  __$MarketPriceCopyWithImpl(this._self, this._then);

  final _MarketPrice _self;
  final $Res Function(_MarketPrice) _then;

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? typeID = null,
    Object? server = null,
    Object? all = null,
    Object? buy = null,
    Object? sell = null,
  }) {
    return _then(_MarketPrice(
      typeID: null == typeID
          ? _self.typeID
          : typeID // ignore: cast_nullable_to_non_nullable
              as int,
      server: null == server
          ? _self.server
          : server // ignore: cast_nullable_to_non_nullable
              as Server,
      all: null == all
          ? _self.all
          : all // ignore: cast_nullable_to_non_nullable
              as Price,
      buy: null == buy
          ? _self.buy
          : buy // ignore: cast_nullable_to_non_nullable
              as Price,
      sell: null == sell
          ? _self.sell
          : sell // ignore: cast_nullable_to_non_nullable
              as Price,
    ));
  }

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get all {
    return $PriceCopyWith<$Res>(_self.all, (value) {
      return _then(_self.copyWith(all: value));
    });
  }

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get buy {
    return $PriceCopyWith<$Res>(_self.buy, (value) {
      return _then(_self.copyWith(buy: value));
    });
  }

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get sell {
    return $PriceCopyWith<$Res>(_self.sell, (value) {
      return _then(_self.copyWith(sell: value));
    });
  }
}

/// @nodoc
mixin _$Price {
  double get min;
  double get max;
  int get volume;

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PriceCopyWith<Price> get copyWith =>
      _$PriceCopyWithImpl<Price>(this as Price, _$identity);

  /// Serializes this Price to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Price &&
            (identical(other.min, min) || other.min == min) &&
            (identical(other.max, max) || other.max == max) &&
            (identical(other.volume, volume) || other.volume == volume));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, min, max, volume);

  @override
  String toString() {
    return 'Price(min: $min, max: $max, volume: $volume)';
  }
}

/// @nodoc
abstract mixin class $PriceCopyWith<$Res> {
  factory $PriceCopyWith(Price value, $Res Function(Price) _then) =
      _$PriceCopyWithImpl;
  @useResult
  $Res call({double min, double max, int volume});
}

/// @nodoc
class _$PriceCopyWithImpl<$Res> implements $PriceCopyWith<$Res> {
  _$PriceCopyWithImpl(this._self, this._then);

  final Price _self;
  final $Res Function(Price) _then;

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? min = null,
    Object? max = null,
    Object? volume = null,
  }) {
    return _then(_self.copyWith(
      min: null == min
          ? _self.min
          : min // ignore: cast_nullable_to_non_nullable
              as double,
      max: null == max
          ? _self.max
          : max // ignore: cast_nullable_to_non_nullable
              as double,
      volume: null == volume
          ? _self.volume
          : volume // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _Price implements Price {
  const _Price({required this.min, required this.max, required this.volume});
  factory _Price.fromJson(Map<String, dynamic> json) => _$PriceFromJson(json);

  @override
  final double min;
  @override
  final double max;
  @override
  final int volume;

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PriceCopyWith<_Price> get copyWith =>
      __$PriceCopyWithImpl<_Price>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PriceToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Price &&
            (identical(other.min, min) || other.min == min) &&
            (identical(other.max, max) || other.max == max) &&
            (identical(other.volume, volume) || other.volume == volume));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, min, max, volume);

  @override
  String toString() {
    return 'Price(min: $min, max: $max, volume: $volume)';
  }
}

/// @nodoc
abstract mixin class _$PriceCopyWith<$Res> implements $PriceCopyWith<$Res> {
  factory _$PriceCopyWith(_Price value, $Res Function(_Price) _then) =
      __$PriceCopyWithImpl;
  @override
  @useResult
  $Res call({double min, double max, int volume});
}

/// @nodoc
class __$PriceCopyWithImpl<$Res> implements _$PriceCopyWith<$Res> {
  __$PriceCopyWithImpl(this._self, this._then);

  final _Price _self;
  final $Res Function(_Price) _then;

  /// Create a copy of Price
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? min = null,
    Object? max = null,
    Object? volume = null,
  }) {
    return _then(_Price(
      min: null == min
          ? _self.min
          : min // ignore: cast_nullable_to_non_nullable
              as double,
      max: null == max
          ? _self.max
          : max // ignore: cast_nullable_to_non_nullable
              as double,
      volume: null == volume
          ? _self.volume
          : volume // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$CEveMarketResponse {
  Price get all;
  Price get buy;
  Price get sell;

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CEveMarketResponseCopyWith<CEveMarketResponse> get copyWith =>
      _$CEveMarketResponseCopyWithImpl<CEveMarketResponse>(
          this as CEveMarketResponse, _$identity);

  /// Serializes this CEveMarketResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CEveMarketResponse &&
            (identical(other.all, all) || other.all == all) &&
            (identical(other.buy, buy) || other.buy == buy) &&
            (identical(other.sell, sell) || other.sell == sell));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, all, buy, sell);

  @override
  String toString() {
    return 'CEveMarketResponse(all: $all, buy: $buy, sell: $sell)';
  }
}

/// @nodoc
abstract mixin class $CEveMarketResponseCopyWith<$Res> {
  factory $CEveMarketResponseCopyWith(
          CEveMarketResponse value, $Res Function(CEveMarketResponse) _then) =
      _$CEveMarketResponseCopyWithImpl;
  @useResult
  $Res call({Price all, Price buy, Price sell});

  $PriceCopyWith<$Res> get all;
  $PriceCopyWith<$Res> get buy;
  $PriceCopyWith<$Res> get sell;
}

/// @nodoc
class _$CEveMarketResponseCopyWithImpl<$Res>
    implements $CEveMarketResponseCopyWith<$Res> {
  _$CEveMarketResponseCopyWithImpl(this._self, this._then);

  final CEveMarketResponse _self;
  final $Res Function(CEveMarketResponse) _then;

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? all = null,
    Object? buy = null,
    Object? sell = null,
  }) {
    return _then(_self.copyWith(
      all: null == all
          ? _self.all
          : all // ignore: cast_nullable_to_non_nullable
              as Price,
      buy: null == buy
          ? _self.buy
          : buy // ignore: cast_nullable_to_non_nullable
              as Price,
      sell: null == sell
          ? _self.sell
          : sell // ignore: cast_nullable_to_non_nullable
              as Price,
    ));
  }

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get all {
    return $PriceCopyWith<$Res>(_self.all, (value) {
      return _then(_self.copyWith(all: value));
    });
  }

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get buy {
    return $PriceCopyWith<$Res>(_self.buy, (value) {
      return _then(_self.copyWith(buy: value));
    });
  }

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get sell {
    return $PriceCopyWith<$Res>(_self.sell, (value) {
      return _then(_self.copyWith(sell: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _CEveMarketResponse implements CEveMarketResponse {
  const _CEveMarketResponse(
      {required this.all, required this.buy, required this.sell});
  factory _CEveMarketResponse.fromJson(Map<String, dynamic> json) =>
      _$CEveMarketResponseFromJson(json);

  @override
  final Price all;
  @override
  final Price buy;
  @override
  final Price sell;

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CEveMarketResponseCopyWith<_CEveMarketResponse> get copyWith =>
      __$CEveMarketResponseCopyWithImpl<_CEveMarketResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CEveMarketResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CEveMarketResponse &&
            (identical(other.all, all) || other.all == all) &&
            (identical(other.buy, buy) || other.buy == buy) &&
            (identical(other.sell, sell) || other.sell == sell));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, all, buy, sell);

  @override
  String toString() {
    return 'CEveMarketResponse(all: $all, buy: $buy, sell: $sell)';
  }
}

/// @nodoc
abstract mixin class _$CEveMarketResponseCopyWith<$Res>
    implements $CEveMarketResponseCopyWith<$Res> {
  factory _$CEveMarketResponseCopyWith(
          _CEveMarketResponse value, $Res Function(_CEveMarketResponse) _then) =
      __$CEveMarketResponseCopyWithImpl;
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
class __$CEveMarketResponseCopyWithImpl<$Res>
    implements _$CEveMarketResponseCopyWith<$Res> {
  __$CEveMarketResponseCopyWithImpl(this._self, this._then);

  final _CEveMarketResponse _self;
  final $Res Function(_CEveMarketResponse) _then;

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? all = null,
    Object? buy = null,
    Object? sell = null,
  }) {
    return _then(_CEveMarketResponse(
      all: null == all
          ? _self.all
          : all // ignore: cast_nullable_to_non_nullable
              as Price,
      buy: null == buy
          ? _self.buy
          : buy // ignore: cast_nullable_to_non_nullable
              as Price,
      sell: null == sell
          ? _self.sell
          : sell // ignore: cast_nullable_to_non_nullable
              as Price,
    ));
  }

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get all {
    return $PriceCopyWith<$Res>(_self.all, (value) {
      return _then(_self.copyWith(all: value));
    });
  }

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get buy {
    return $PriceCopyWith<$Res>(_self.buy, (value) {
      return _then(_self.copyWith(buy: value));
    });
  }

  /// Create a copy of CEveMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get sell {
    return $PriceCopyWith<$Res>(_self.sell, (value) {
      return _then(_self.copyWith(sell: value));
    });
  }
}

// dart format on
