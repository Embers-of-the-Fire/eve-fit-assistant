// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'damage_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DamageProfile {

 double get em; double get thermal; double get kinetic; double get explosive;
/// Create a copy of DamageProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DamageProfileCopyWith<DamageProfile> get copyWith => _$DamageProfileCopyWithImpl<DamageProfile>(this as DamageProfile, _$identity);

  /// Serializes this DamageProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DamageProfile&&(identical(other.em, em) || other.em == em)&&(identical(other.thermal, thermal) || other.thermal == thermal)&&(identical(other.kinetic, kinetic) || other.kinetic == kinetic)&&(identical(other.explosive, explosive) || other.explosive == explosive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,em,thermal,kinetic,explosive);

@override
String toString() {
  return 'DamageProfile(em: $em, thermal: $thermal, kinetic: $kinetic, explosive: $explosive)';
}


}

/// @nodoc
abstract mixin class $DamageProfileCopyWith<$Res>  {
  factory $DamageProfileCopyWith(DamageProfile value, $Res Function(DamageProfile) _then) = _$DamageProfileCopyWithImpl;
@useResult
$Res call({
 double em, double thermal, double kinetic, double explosive
});




}
/// @nodoc
class _$DamageProfileCopyWithImpl<$Res>
    implements $DamageProfileCopyWith<$Res> {
  _$DamageProfileCopyWithImpl(this._self, this._then);

  final DamageProfile _self;
  final $Res Function(DamageProfile) _then;

/// Create a copy of DamageProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? em = null,Object? thermal = null,Object? kinetic = null,Object? explosive = null,}) {
  return _then(_self.copyWith(
em: null == em ? _self.em : em // ignore: cast_nullable_to_non_nullable
as double,thermal: null == thermal ? _self.thermal : thermal // ignore: cast_nullable_to_non_nullable
as double,kinetic: null == kinetic ? _self.kinetic : kinetic // ignore: cast_nullable_to_non_nullable
as double,explosive: null == explosive ? _self.explosive : explosive // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [DamageProfile].
extension DamageProfilePatterns on DamageProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DamageProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DamageProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DamageProfile value)  $default,){
final _that = this;
switch (_that) {
case _DamageProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DamageProfile value)?  $default,){
final _that = this;
switch (_that) {
case _DamageProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double em,  double thermal,  double kinetic,  double explosive)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DamageProfile() when $default != null:
return $default(_that.em,_that.thermal,_that.kinetic,_that.explosive);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double em,  double thermal,  double kinetic,  double explosive)  $default,) {final _that = this;
switch (_that) {
case _DamageProfile():
return $default(_that.em,_that.thermal,_that.kinetic,_that.explosive);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double em,  double thermal,  double kinetic,  double explosive)?  $default,) {final _that = this;
switch (_that) {
case _DamageProfile() when $default != null:
return $default(_that.em,_that.thermal,_that.kinetic,_that.explosive);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DamageProfile implements DamageProfile {
  const _DamageProfile({required this.em, required this.thermal, required this.kinetic, required this.explosive});
  factory _DamageProfile.fromJson(Map<String, dynamic> json) => _$DamageProfileFromJson(json);

@override final  double em;
@override final  double thermal;
@override final  double kinetic;
@override final  double explosive;

/// Create a copy of DamageProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DamageProfileCopyWith<_DamageProfile> get copyWith => __$DamageProfileCopyWithImpl<_DamageProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DamageProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DamageProfile&&(identical(other.em, em) || other.em == em)&&(identical(other.thermal, thermal) || other.thermal == thermal)&&(identical(other.kinetic, kinetic) || other.kinetic == kinetic)&&(identical(other.explosive, explosive) || other.explosive == explosive));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,em,thermal,kinetic,explosive);

@override
String toString() {
  return 'DamageProfile(em: $em, thermal: $thermal, kinetic: $kinetic, explosive: $explosive)';
}


}

/// @nodoc
abstract mixin class _$DamageProfileCopyWith<$Res> implements $DamageProfileCopyWith<$Res> {
  factory _$DamageProfileCopyWith(_DamageProfile value, $Res Function(_DamageProfile) _then) = __$DamageProfileCopyWithImpl;
@override @useResult
$Res call({
 double em, double thermal, double kinetic, double explosive
});




}
/// @nodoc
class __$DamageProfileCopyWithImpl<$Res>
    implements _$DamageProfileCopyWith<$Res> {
  __$DamageProfileCopyWithImpl(this._self, this._then);

  final _DamageProfile _self;
  final $Res Function(_DamageProfile) _then;

/// Create a copy of DamageProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? em = null,Object? thermal = null,Object? kinetic = null,Object? explosive = null,}) {
  return _then(_DamageProfile(
em: null == em ? _self.em : em // ignore: cast_nullable_to_non_nullable
as double,thermal: null == thermal ? _self.thermal : thermal // ignore: cast_nullable_to_non_nullable
as double,kinetic: null == kinetic ? _self.kinetic : kinetic // ignore: cast_nullable_to_non_nullable
as double,explosive: null == explosive ? _self.explosive : explosive // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
