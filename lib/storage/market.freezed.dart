// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
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

 MarketPrice get price; DateTime get timestamp;
/// Create a copy of MarketPriceCache
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MarketPriceCacheCopyWith<MarketPriceCache> get copyWith => _$MarketPriceCacheCopyWithImpl<MarketPriceCache>(this as MarketPriceCache, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MarketPriceCache&&(identical(other.price, price) || other.price == price)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}


@override
int get hashCode => Object.hash(runtimeType,price,timestamp);

@override
String toString() {
  return 'MarketPriceCache(price: $price, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class $MarketPriceCacheCopyWith<$Res>  {
  factory $MarketPriceCacheCopyWith(MarketPriceCache value, $Res Function(MarketPriceCache) _then) = _$MarketPriceCacheCopyWithImpl;
@useResult
$Res call({
 MarketPrice price, DateTime timestamp
});


$MarketPriceCopyWith<$Res> get price;

}
/// @nodoc
class _$MarketPriceCacheCopyWithImpl<$Res>
    implements $MarketPriceCacheCopyWith<$Res> {
  _$MarketPriceCacheCopyWithImpl(this._self, this._then);

  final MarketPriceCache _self;
  final $Res Function(MarketPriceCache) _then;

/// Create a copy of MarketPriceCache
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? price = null,Object? timestamp = null,}) {
  return _then(_self.copyWith(
price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as MarketPrice,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
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


/// Adds pattern-matching-related methods to [MarketPriceCache].
extension MarketPriceCachePatterns on MarketPriceCache {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MarketPriceCache value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MarketPriceCache() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MarketPriceCache value)  $default,){
final _that = this;
switch (_that) {
case _MarketPriceCache():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MarketPriceCache value)?  $default,){
final _that = this;
switch (_that) {
case _MarketPriceCache() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( MarketPrice price,  DateTime timestamp)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MarketPriceCache() when $default != null:
return $default(_that.price,_that.timestamp);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( MarketPrice price,  DateTime timestamp)  $default,) {final _that = this;
switch (_that) {
case _MarketPriceCache():
return $default(_that.price,_that.timestamp);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( MarketPrice price,  DateTime timestamp)?  $default,) {final _that = this;
switch (_that) {
case _MarketPriceCache() when $default != null:
return $default(_that.price,_that.timestamp);case _:
  return null;

}
}

}

/// @nodoc


class _MarketPriceCache extends MarketPriceCache {
  const _MarketPriceCache({required this.price, required this.timestamp}): super._();
  

@override final  MarketPrice price;
@override final  DateTime timestamp;

/// Create a copy of MarketPriceCache
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MarketPriceCacheCopyWith<_MarketPriceCache> get copyWith => __$MarketPriceCacheCopyWithImpl<_MarketPriceCache>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MarketPriceCache&&(identical(other.price, price) || other.price == price)&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp));
}


@override
int get hashCode => Object.hash(runtimeType,price,timestamp);

@override
String toString() {
  return 'MarketPriceCache(price: $price, timestamp: $timestamp)';
}


}

/// @nodoc
abstract mixin class _$MarketPriceCacheCopyWith<$Res> implements $MarketPriceCacheCopyWith<$Res> {
  factory _$MarketPriceCacheCopyWith(_MarketPriceCache value, $Res Function(_MarketPriceCache) _then) = __$MarketPriceCacheCopyWithImpl;
@override @useResult
$Res call({
 MarketPrice price, DateTime timestamp
});


@override $MarketPriceCopyWith<$Res> get price;

}
/// @nodoc
class __$MarketPriceCacheCopyWithImpl<$Res>
    implements _$MarketPriceCacheCopyWith<$Res> {
  __$MarketPriceCacheCopyWithImpl(this._self, this._then);

  final _MarketPriceCache _self;
  final $Res Function(_MarketPriceCache) _then;

/// Create a copy of MarketPriceCache
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? price = null,Object? timestamp = null,}) {
  return _then(_MarketPriceCache(
price: null == price ? _self.price : price // ignore: cast_nullable_to_non_nullable
as MarketPrice,timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
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
