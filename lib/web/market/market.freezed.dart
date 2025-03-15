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
  PriceSummary get summary;
  OrderGroup get orders;

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
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.orders, orders) || other.orders == orders));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, typeID, server, summary, orders);

  @override
  String toString() {
    return 'MarketPrice(typeID: $typeID, server: $server, summary: $summary, orders: $orders)';
  }
}

/// @nodoc
abstract mixin class $MarketPriceCopyWith<$Res> {
  factory $MarketPriceCopyWith(
          MarketPrice value, $Res Function(MarketPrice) _then) =
      _$MarketPriceCopyWithImpl;
  @useResult
  $Res call(
      {int typeID, Server server, PriceSummary summary, OrderGroup orders});

  $PriceSummaryCopyWith<$Res> get summary;
  $OrderGroupCopyWith<$Res> get orders;
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
    Object? summary = null,
    Object? orders = null,
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
      summary: null == summary
          ? _self.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as PriceSummary,
      orders: null == orders
          ? _self.orders
          : orders // ignore: cast_nullable_to_non_nullable
              as OrderGroup,
    ));
  }

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceSummaryCopyWith<$Res> get summary {
    return $PriceSummaryCopyWith<$Res>(_self.summary, (value) {
      return _then(_self.copyWith(summary: value));
    });
  }

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $OrderGroupCopyWith<$Res> get orders {
    return $OrderGroupCopyWith<$Res>(_self.orders, (value) {
      return _then(_self.copyWith(orders: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _MarketPrice implements MarketPrice {
  const _MarketPrice(
      {required this.typeID,
      required this.server,
      required this.summary,
      required this.orders});
  factory _MarketPrice.fromJson(Map<String, dynamic> json) =>
      _$MarketPriceFromJson(json);

  @override
  final int typeID;
  @override
  final Server server;
  @override
  final PriceSummary summary;
  @override
  final OrderGroup orders;

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
            (identical(other.summary, summary) || other.summary == summary) &&
            (identical(other.orders, orders) || other.orders == orders));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, typeID, server, summary, orders);

  @override
  String toString() {
    return 'MarketPrice(typeID: $typeID, server: $server, summary: $summary, orders: $orders)';
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
  $Res call(
      {int typeID, Server server, PriceSummary summary, OrderGroup orders});

  @override
  $PriceSummaryCopyWith<$Res> get summary;
  @override
  $OrderGroupCopyWith<$Res> get orders;
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
    Object? summary = null,
    Object? orders = null,
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
      summary: null == summary
          ? _self.summary
          : summary // ignore: cast_nullable_to_non_nullable
              as PriceSummary,
      orders: null == orders
          ? _self.orders
          : orders // ignore: cast_nullable_to_non_nullable
              as OrderGroup,
    ));
  }

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceSummaryCopyWith<$Res> get summary {
    return $PriceSummaryCopyWith<$Res>(_self.summary, (value) {
      return _then(_self.copyWith(summary: value));
    });
  }

  /// Create a copy of MarketPrice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $OrderGroupCopyWith<$Res> get orders {
    return $OrderGroupCopyWith<$Res>(_self.orders, (value) {
      return _then(_self.copyWith(orders: value));
    });
  }
}

/// @nodoc
mixin _$PriceSummary {
  Price get all;
  Price get buy;
  Price get sell;

  /// Create a copy of PriceSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PriceSummaryCopyWith<PriceSummary> get copyWith =>
      _$PriceSummaryCopyWithImpl<PriceSummary>(
          this as PriceSummary, _$identity);

  /// Serializes this PriceSummary to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PriceSummary &&
            (identical(other.all, all) || other.all == all) &&
            (identical(other.buy, buy) || other.buy == buy) &&
            (identical(other.sell, sell) || other.sell == sell));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, all, buy, sell);

  @override
  String toString() {
    return 'PriceSummary(all: $all, buy: $buy, sell: $sell)';
  }
}

/// @nodoc
abstract mixin class $PriceSummaryCopyWith<$Res> {
  factory $PriceSummaryCopyWith(
          PriceSummary value, $Res Function(PriceSummary) _then) =
      _$PriceSummaryCopyWithImpl;
  @useResult
  $Res call({Price all, Price buy, Price sell});

  $PriceCopyWith<$Res> get all;
  $PriceCopyWith<$Res> get buy;
  $PriceCopyWith<$Res> get sell;
}

/// @nodoc
class _$PriceSummaryCopyWithImpl<$Res> implements $PriceSummaryCopyWith<$Res> {
  _$PriceSummaryCopyWithImpl(this._self, this._then);

  final PriceSummary _self;
  final $Res Function(PriceSummary) _then;

  /// Create a copy of PriceSummary
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

  /// Create a copy of PriceSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get all {
    return $PriceCopyWith<$Res>(_self.all, (value) {
      return _then(_self.copyWith(all: value));
    });
  }

  /// Create a copy of PriceSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get buy {
    return $PriceCopyWith<$Res>(_self.buy, (value) {
      return _then(_self.copyWith(buy: value));
    });
  }

  /// Create a copy of PriceSummary
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
class _PriceSummary implements PriceSummary {
  const _PriceSummary(
      {required this.all, required this.buy, required this.sell});
  factory _PriceSummary.fromJson(Map<String, dynamic> json) =>
      _$PriceSummaryFromJson(json);

  @override
  final Price all;
  @override
  final Price buy;
  @override
  final Price sell;

  /// Create a copy of PriceSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PriceSummaryCopyWith<_PriceSummary> get copyWith =>
      __$PriceSummaryCopyWithImpl<_PriceSummary>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PriceSummaryToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PriceSummary &&
            (identical(other.all, all) || other.all == all) &&
            (identical(other.buy, buy) || other.buy == buy) &&
            (identical(other.sell, sell) || other.sell == sell));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, all, buy, sell);

  @override
  String toString() {
    return 'PriceSummary(all: $all, buy: $buy, sell: $sell)';
  }
}

/// @nodoc
abstract mixin class _$PriceSummaryCopyWith<$Res>
    implements $PriceSummaryCopyWith<$Res> {
  factory _$PriceSummaryCopyWith(
          _PriceSummary value, $Res Function(_PriceSummary) _then) =
      __$PriceSummaryCopyWithImpl;
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
class __$PriceSummaryCopyWithImpl<$Res>
    implements _$PriceSummaryCopyWith<$Res> {
  __$PriceSummaryCopyWithImpl(this._self, this._then);

  final _PriceSummary _self;
  final $Res Function(_PriceSummary) _then;

  /// Create a copy of PriceSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? all = null,
    Object? buy = null,
    Object? sell = null,
  }) {
    return _then(_PriceSummary(
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

  /// Create a copy of PriceSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get all {
    return $PriceCopyWith<$Res>(_self.all, (value) {
      return _then(_self.copyWith(all: value));
    });
  }

  /// Create a copy of PriceSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PriceCopyWith<$Res> get buy {
    return $PriceCopyWith<$Res>(_self.buy, (value) {
      return _then(_self.copyWith(buy: value));
    });
  }

  /// Create a copy of PriceSummary
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
mixin _$OrderGroup {
  /// `buy` orders should be sorted in descending order by price.
  List<Order> get buy;

  /// `sell` orders should be sorted in ascending order by price.
  List<Order> get sell;

  /// Create a copy of OrderGroup
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $OrderGroupCopyWith<OrderGroup> get copyWith =>
      _$OrderGroupCopyWithImpl<OrderGroup>(this as OrderGroup, _$identity);

  /// Serializes this OrderGroup to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is OrderGroup &&
            const DeepCollectionEquality().equals(other.buy, buy) &&
            const DeepCollectionEquality().equals(other.sell, sell));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(buy),
      const DeepCollectionEquality().hash(sell));

  @override
  String toString() {
    return 'OrderGroup(buy: $buy, sell: $sell)';
  }
}

/// @nodoc
abstract mixin class $OrderGroupCopyWith<$Res> {
  factory $OrderGroupCopyWith(
          OrderGroup value, $Res Function(OrderGroup) _then) =
      _$OrderGroupCopyWithImpl;
  @useResult
  $Res call({List<Order> buy, List<Order> sell});
}

/// @nodoc
class _$OrderGroupCopyWithImpl<$Res> implements $OrderGroupCopyWith<$Res> {
  _$OrderGroupCopyWithImpl(this._self, this._then);

  final OrderGroup _self;
  final $Res Function(OrderGroup) _then;

  /// Create a copy of OrderGroup
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? buy = null,
    Object? sell = null,
  }) {
    return _then(_self.copyWith(
      buy: null == buy
          ? _self.buy
          : buy // ignore: cast_nullable_to_non_nullable
              as List<Order>,
      sell: null == sell
          ? _self.sell
          : sell // ignore: cast_nullable_to_non_nullable
              as List<Order>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _OrderGroup implements OrderGroup {
  const _OrderGroup(
      {required final List<Order> buy, required final List<Order> sell})
      : _buy = buy,
        _sell = sell;
  factory _OrderGroup.fromJson(Map<String, dynamic> json) =>
      _$OrderGroupFromJson(json);

  /// `buy` orders should be sorted in descending order by price.
  final List<Order> _buy;

  /// `buy` orders should be sorted in descending order by price.
  @override
  List<Order> get buy {
    if (_buy is EqualUnmodifiableListView) return _buy;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_buy);
  }

  /// `sell` orders should be sorted in ascending order by price.
  final List<Order> _sell;

  /// `sell` orders should be sorted in ascending order by price.
  @override
  List<Order> get sell {
    if (_sell is EqualUnmodifiableListView) return _sell;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_sell);
  }

  /// Create a copy of OrderGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$OrderGroupCopyWith<_OrderGroup> get copyWith =>
      __$OrderGroupCopyWithImpl<_OrderGroup>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$OrderGroupToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _OrderGroup &&
            const DeepCollectionEquality().equals(other._buy, _buy) &&
            const DeepCollectionEquality().equals(other._sell, _sell));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_buy),
      const DeepCollectionEquality().hash(_sell));

  @override
  String toString() {
    return 'OrderGroup(buy: $buy, sell: $sell)';
  }
}

/// @nodoc
abstract mixin class _$OrderGroupCopyWith<$Res>
    implements $OrderGroupCopyWith<$Res> {
  factory _$OrderGroupCopyWith(
          _OrderGroup value, $Res Function(_OrderGroup) _then) =
      __$OrderGroupCopyWithImpl;
  @override
  @useResult
  $Res call({List<Order> buy, List<Order> sell});
}

/// @nodoc
class __$OrderGroupCopyWithImpl<$Res> implements _$OrderGroupCopyWith<$Res> {
  __$OrderGroupCopyWithImpl(this._self, this._then);

  final _OrderGroup _self;
  final $Res Function(_OrderGroup) _then;

  /// Create a copy of OrderGroup
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? buy = null,
    Object? sell = null,
  }) {
    return _then(_OrderGroup(
      buy: null == buy
          ? _self._buy
          : buy // ignore: cast_nullable_to_non_nullable
              as List<Order>,
      sell: null == sell
          ? _self._sell
          : sell // ignore: cast_nullable_to_non_nullable
              as List<Order>,
    ));
  }
}

/// @nodoc
mixin _$Order {
  int get volumeRemain;
  int get volumeTotal;
  double get price;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $OrderCopyWith<Order> get copyWith =>
      _$OrderCopyWithImpl<Order>(this as Order, _$identity);

  /// Serializes this Order to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Order &&
            (identical(other.volumeRemain, volumeRemain) ||
                other.volumeRemain == volumeRemain) &&
            (identical(other.volumeTotal, volumeTotal) ||
                other.volumeTotal == volumeTotal) &&
            (identical(other.price, price) || other.price == price));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, volumeRemain, volumeTotal, price);

  @override
  String toString() {
    return 'Order(volumeRemain: $volumeRemain, volumeTotal: $volumeTotal, price: $price)';
  }
}

/// @nodoc
abstract mixin class $OrderCopyWith<$Res> {
  factory $OrderCopyWith(Order value, $Res Function(Order) _then) =
      _$OrderCopyWithImpl;
  @useResult
  $Res call({int volumeRemain, int volumeTotal, double price});
}

/// @nodoc
class _$OrderCopyWithImpl<$Res> implements $OrderCopyWith<$Res> {
  _$OrderCopyWithImpl(this._self, this._then);

  final Order _self;
  final $Res Function(Order) _then;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? volumeRemain = null,
    Object? volumeTotal = null,
    Object? price = null,
  }) {
    return _then(_self.copyWith(
      volumeRemain: null == volumeRemain
          ? _self.volumeRemain
          : volumeRemain // ignore: cast_nullable_to_non_nullable
              as int,
      volumeTotal: null == volumeTotal
          ? _self.volumeTotal
          : volumeTotal // ignore: cast_nullable_to_non_nullable
              as int,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _Order implements Order {
  const _Order(
      {required this.volumeRemain,
      required this.volumeTotal,
      required this.price});
  factory _Order.fromJson(Map<String, dynamic> json) => _$OrderFromJson(json);

  @override
  final int volumeRemain;
  @override
  final int volumeTotal;
  @override
  final double price;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$OrderCopyWith<_Order> get copyWith =>
      __$OrderCopyWithImpl<_Order>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$OrderToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Order &&
            (identical(other.volumeRemain, volumeRemain) ||
                other.volumeRemain == volumeRemain) &&
            (identical(other.volumeTotal, volumeTotal) ||
                other.volumeTotal == volumeTotal) &&
            (identical(other.price, price) || other.price == price));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, volumeRemain, volumeTotal, price);

  @override
  String toString() {
    return 'Order(volumeRemain: $volumeRemain, volumeTotal: $volumeTotal, price: $price)';
  }
}

/// @nodoc
abstract mixin class _$OrderCopyWith<$Res> implements $OrderCopyWith<$Res> {
  factory _$OrderCopyWith(_Order value, $Res Function(_Order) _then) =
      __$OrderCopyWithImpl;
  @override
  @useResult
  $Res call({int volumeRemain, int volumeTotal, double price});
}

/// @nodoc
class __$OrderCopyWithImpl<$Res> implements _$OrderCopyWith<$Res> {
  __$OrderCopyWithImpl(this._self, this._then);

  final _Order _self;
  final $Res Function(_Order) _then;

  /// Create a copy of Order
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? volumeRemain = null,
    Object? volumeTotal = null,
    Object? price = null,
  }) {
    return _then(_Order(
      volumeRemain: null == volumeRemain
          ? _self.volumeRemain
          : volumeRemain // ignore: cast_nullable_to_non_nullable
              as int,
      volumeTotal: null == volumeTotal
          ? _self.volumeTotal
          : volumeTotal // ignore: cast_nullable_to_non_nullable
              as int,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
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

/// @nodoc
mixin _$ESIMarketResponse {
// ignore: invalid_annotation_target
  @JsonKey(name: 'type_id')
  int get typeID;
  int get volumeRemain;
  int get volumeTotal;
  double get price;
  bool get isBuyOrder; // ignore: invalid_annotation_target
  @JsonKey(name: 'location_id')
  int get locationID;

  /// Create a copy of ESIMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ESIMarketResponseCopyWith<ESIMarketResponse> get copyWith =>
      _$ESIMarketResponseCopyWithImpl<ESIMarketResponse>(
          this as ESIMarketResponse, _$identity);

  /// Serializes this ESIMarketResponse to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ESIMarketResponse &&
            (identical(other.typeID, typeID) || other.typeID == typeID) &&
            (identical(other.volumeRemain, volumeRemain) ||
                other.volumeRemain == volumeRemain) &&
            (identical(other.volumeTotal, volumeTotal) ||
                other.volumeTotal == volumeTotal) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.isBuyOrder, isBuyOrder) ||
                other.isBuyOrder == isBuyOrder) &&
            (identical(other.locationID, locationID) ||
                other.locationID == locationID));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, typeID, volumeRemain,
      volumeTotal, price, isBuyOrder, locationID);

  @override
  String toString() {
    return 'ESIMarketResponse(typeID: $typeID, volumeRemain: $volumeRemain, volumeTotal: $volumeTotal, price: $price, isBuyOrder: $isBuyOrder, locationID: $locationID)';
  }
}

/// @nodoc
abstract mixin class $ESIMarketResponseCopyWith<$Res> {
  factory $ESIMarketResponseCopyWith(
          ESIMarketResponse value, $Res Function(ESIMarketResponse) _then) =
      _$ESIMarketResponseCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'type_id') int typeID,
      int volumeRemain,
      int volumeTotal,
      double price,
      bool isBuyOrder,
      @JsonKey(name: 'location_id') int locationID});
}

/// @nodoc
class _$ESIMarketResponseCopyWithImpl<$Res>
    implements $ESIMarketResponseCopyWith<$Res> {
  _$ESIMarketResponseCopyWithImpl(this._self, this._then);

  final ESIMarketResponse _self;
  final $Res Function(ESIMarketResponse) _then;

  /// Create a copy of ESIMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? typeID = null,
    Object? volumeRemain = null,
    Object? volumeTotal = null,
    Object? price = null,
    Object? isBuyOrder = null,
    Object? locationID = null,
  }) {
    return _then(_self.copyWith(
      typeID: null == typeID
          ? _self.typeID
          : typeID // ignore: cast_nullable_to_non_nullable
              as int,
      volumeRemain: null == volumeRemain
          ? _self.volumeRemain
          : volumeRemain // ignore: cast_nullable_to_non_nullable
              as int,
      volumeTotal: null == volumeTotal
          ? _self.volumeTotal
          : volumeTotal // ignore: cast_nullable_to_non_nullable
              as int,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      isBuyOrder: null == isBuyOrder
          ? _self.isBuyOrder
          : isBuyOrder // ignore: cast_nullable_to_non_nullable
              as bool,
      locationID: null == locationID
          ? _self.locationID
          : locationID // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

@JsonSerializable(fieldRename: FieldRename.snake)
class _ESIMarketResponse implements ESIMarketResponse {
  const _ESIMarketResponse(
      {@JsonKey(name: 'type_id') required this.typeID,
      required this.volumeRemain,
      required this.volumeTotal,
      required this.price,
      required this.isBuyOrder,
      @JsonKey(name: 'location_id') required this.locationID});
  factory _ESIMarketResponse.fromJson(Map<String, dynamic> json) =>
      _$ESIMarketResponseFromJson(json);

// ignore: invalid_annotation_target
  @override
  @JsonKey(name: 'type_id')
  final int typeID;
  @override
  final int volumeRemain;
  @override
  final int volumeTotal;
  @override
  final double price;
  @override
  final bool isBuyOrder;
// ignore: invalid_annotation_target
  @override
  @JsonKey(name: 'location_id')
  final int locationID;

  /// Create a copy of ESIMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ESIMarketResponseCopyWith<_ESIMarketResponse> get copyWith =>
      __$ESIMarketResponseCopyWithImpl<_ESIMarketResponse>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ESIMarketResponseToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ESIMarketResponse &&
            (identical(other.typeID, typeID) || other.typeID == typeID) &&
            (identical(other.volumeRemain, volumeRemain) ||
                other.volumeRemain == volumeRemain) &&
            (identical(other.volumeTotal, volumeTotal) ||
                other.volumeTotal == volumeTotal) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.isBuyOrder, isBuyOrder) ||
                other.isBuyOrder == isBuyOrder) &&
            (identical(other.locationID, locationID) ||
                other.locationID == locationID));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, typeID, volumeRemain,
      volumeTotal, price, isBuyOrder, locationID);

  @override
  String toString() {
    return 'ESIMarketResponse(typeID: $typeID, volumeRemain: $volumeRemain, volumeTotal: $volumeTotal, price: $price, isBuyOrder: $isBuyOrder, locationID: $locationID)';
  }
}

/// @nodoc
abstract mixin class _$ESIMarketResponseCopyWith<$Res>
    implements $ESIMarketResponseCopyWith<$Res> {
  factory _$ESIMarketResponseCopyWith(
          _ESIMarketResponse value, $Res Function(_ESIMarketResponse) _then) =
      __$ESIMarketResponseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'type_id') int typeID,
      int volumeRemain,
      int volumeTotal,
      double price,
      bool isBuyOrder,
      @JsonKey(name: 'location_id') int locationID});
}

/// @nodoc
class __$ESIMarketResponseCopyWithImpl<$Res>
    implements _$ESIMarketResponseCopyWith<$Res> {
  __$ESIMarketResponseCopyWithImpl(this._self, this._then);

  final _ESIMarketResponse _self;
  final $Res Function(_ESIMarketResponse) _then;

  /// Create a copy of ESIMarketResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? typeID = null,
    Object? volumeRemain = null,
    Object? volumeTotal = null,
    Object? price = null,
    Object? isBuyOrder = null,
    Object? locationID = null,
  }) {
    return _then(_ESIMarketResponse(
      typeID: null == typeID
          ? _self.typeID
          : typeID // ignore: cast_nullable_to_non_nullable
              as int,
      volumeRemain: null == volumeRemain
          ? _self.volumeRemain
          : volumeRemain // ignore: cast_nullable_to_non_nullable
              as int,
      volumeTotal: null == volumeTotal
          ? _self.volumeTotal
          : volumeTotal // ignore: cast_nullable_to_non_nullable
              as int,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      isBuyOrder: null == isBuyOrder
          ? _self.isBuyOrder
          : isBuyOrder // ignore: cast_nullable_to_non_nullable
              as bool,
      locationID: null == locationID
          ? _self.locationID
          : locationID // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
