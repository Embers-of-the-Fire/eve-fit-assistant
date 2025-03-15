// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'esi.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Character {
  int get characterID;
  String? get characterName;

  /// Create a copy of Character
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CharacterCopyWith<Character> get copyWith =>
      _$CharacterCopyWithImpl<Character>(this as Character, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Character &&
            (identical(other.characterID, characterID) ||
                other.characterID == characterID) &&
            (identical(other.characterName, characterName) ||
                other.characterName == characterName));
  }

  @override
  int get hashCode => Object.hash(runtimeType, characterID, characterName);

  @override
  String toString() {
    return 'Character(characterID: $characterID, characterName: $characterName)';
  }
}

/// @nodoc
abstract mixin class $CharacterCopyWith<$Res> {
  factory $CharacterCopyWith(Character value, $Res Function(Character) _then) =
      _$CharacterCopyWithImpl;
  @useResult
  $Res call({int characterID, String? characterName});
}

/// @nodoc
class _$CharacterCopyWithImpl<$Res> implements $CharacterCopyWith<$Res> {
  _$CharacterCopyWithImpl(this._self, this._then);

  final Character _self;
  final $Res Function(Character) _then;

  /// Create a copy of Character
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? characterID = null,
    Object? characterName = freezed,
  }) {
    return _then(_self.copyWith(
      characterID: null == characterID
          ? _self.characterID
          : characterID // ignore: cast_nullable_to_non_nullable
              as int,
      characterName: freezed == characterName
          ? _self.characterName
          : characterName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _Character extends Character {
  const _Character({required this.characterID, required this.characterName})
      : super._();

  @override
  final int characterID;
  @override
  final String? characterName;

  /// Create a copy of Character
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CharacterCopyWith<_Character> get copyWith =>
      __$CharacterCopyWithImpl<_Character>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Character &&
            (identical(other.characterID, characterID) ||
                other.characterID == characterID) &&
            (identical(other.characterName, characterName) ||
                other.characterName == characterName));
  }

  @override
  int get hashCode => Object.hash(runtimeType, characterID, characterName);

  @override
  String toString() {
    return 'Character(characterID: $characterID, characterName: $characterName)';
  }
}

/// @nodoc
abstract mixin class _$CharacterCopyWith<$Res>
    implements $CharacterCopyWith<$Res> {
  factory _$CharacterCopyWith(
          _Character value, $Res Function(_Character) _then) =
      __$CharacterCopyWithImpl;
  @override
  @useResult
  $Res call({int characterID, String? characterName});
}

/// @nodoc
class __$CharacterCopyWithImpl<$Res> implements _$CharacterCopyWith<$Res> {
  __$CharacterCopyWithImpl(this._self, this._then);

  final _Character _self;
  final $Res Function(_Character) _then;

  /// Create a copy of Character
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? characterID = null,
    Object? characterName = freezed,
  }) {
    return _then(_Character(
      characterID: null == characterID
          ? _self.characterID
          : characterID // ignore: cast_nullable_to_non_nullable
              as int,
      characterName: freezed == characterName
          ? _self.characterName
          : characterName // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
