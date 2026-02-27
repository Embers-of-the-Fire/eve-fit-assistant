// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'verify.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VerifyResponse {

@JsonKey(name: 'CharacterID') int get characterID;@JsonKey(name: 'CharacterName') String? get characterName;
/// Create a copy of VerifyResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VerifyResponseCopyWith<VerifyResponse> get copyWith => _$VerifyResponseCopyWithImpl<VerifyResponse>(this as VerifyResponse, _$identity);

  /// Serializes this VerifyResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VerifyResponse&&(identical(other.characterID, characterID) || other.characterID == characterID)&&(identical(other.characterName, characterName) || other.characterName == characterName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,characterID,characterName);

@override
String toString() {
  return 'VerifyResponse(characterID: $characterID, characterName: $characterName)';
}


}

/// @nodoc
abstract mixin class $VerifyResponseCopyWith<$Res>  {
  factory $VerifyResponseCopyWith(VerifyResponse value, $Res Function(VerifyResponse) _then) = _$VerifyResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'CharacterID') int characterID,@JsonKey(name: 'CharacterName') String? characterName
});




}
/// @nodoc
class _$VerifyResponseCopyWithImpl<$Res>
    implements $VerifyResponseCopyWith<$Res> {
  _$VerifyResponseCopyWithImpl(this._self, this._then);

  final VerifyResponse _self;
  final $Res Function(VerifyResponse) _then;

/// Create a copy of VerifyResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? characterID = null,Object? characterName = freezed,}) {
  return _then(_self.copyWith(
characterID: null == characterID ? _self.characterID : characterID // ignore: cast_nullable_to_non_nullable
as int,characterName: freezed == characterName ? _self.characterName : characterName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VerifyResponse].
extension VerifyResponsePatterns on VerifyResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VerifyResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VerifyResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VerifyResponse value)  $default,){
final _that = this;
switch (_that) {
case _VerifyResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VerifyResponse value)?  $default,){
final _that = this;
switch (_that) {
case _VerifyResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'CharacterID')  int characterID, @JsonKey(name: 'CharacterName')  String? characterName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VerifyResponse() when $default != null:
return $default(_that.characterID,_that.characterName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'CharacterID')  int characterID, @JsonKey(name: 'CharacterName')  String? characterName)  $default,) {final _that = this;
switch (_that) {
case _VerifyResponse():
return $default(_that.characterID,_that.characterName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'CharacterID')  int characterID, @JsonKey(name: 'CharacterName')  String? characterName)?  $default,) {final _that = this;
switch (_that) {
case _VerifyResponse() when $default != null:
return $default(_that.characterID,_that.characterName);case _:
  return null;

}
}

}

/// @nodoc

@JsonSerializable()
class _VerifyResponse implements VerifyResponse {
  const _VerifyResponse({@JsonKey(name: 'CharacterID') required this.characterID, @JsonKey(name: 'CharacterName') this.characterName});
  factory _VerifyResponse.fromJson(Map<String, dynamic> json) => _$VerifyResponseFromJson(json);

@override@JsonKey(name: 'CharacterID') final  int characterID;
@override@JsonKey(name: 'CharacterName') final  String? characterName;

/// Create a copy of VerifyResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VerifyResponseCopyWith<_VerifyResponse> get copyWith => __$VerifyResponseCopyWithImpl<_VerifyResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VerifyResponseToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VerifyResponse&&(identical(other.characterID, characterID) || other.characterID == characterID)&&(identical(other.characterName, characterName) || other.characterName == characterName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,characterID,characterName);

@override
String toString() {
  return 'VerifyResponse(characterID: $characterID, characterName: $characterName)';
}


}

/// @nodoc
abstract mixin class _$VerifyResponseCopyWith<$Res> implements $VerifyResponseCopyWith<$Res> {
  factory _$VerifyResponseCopyWith(_VerifyResponse value, $Res Function(_VerifyResponse) _then) = __$VerifyResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'CharacterID') int characterID,@JsonKey(name: 'CharacterName') String? characterName
});




}
/// @nodoc
class __$VerifyResponseCopyWithImpl<$Res>
    implements _$VerifyResponseCopyWith<$Res> {
  __$VerifyResponseCopyWithImpl(this._self, this._then);

  final _VerifyResponse _self;
  final $Res Function(_VerifyResponse) _then;

/// Create a copy of VerifyResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? characterID = null,Object? characterName = freezed,}) {
  return _then(_VerifyResponse(
characterID: null == characterID ? _self.characterID : characterID // ignore: cast_nullable_to_non_nullable
as int,characterName: freezed == characterName ? _self.characterName : characterName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
