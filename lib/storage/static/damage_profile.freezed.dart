// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
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
  double get em;
  double get thermal;
  double get kinetic;
  double get explosive;

  /// Create a copy of DamageProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DamageProfileCopyWith<DamageProfile> get copyWith =>
      _$DamageProfileCopyWithImpl<DamageProfile>(
          this as DamageProfile, _$identity);

  /// Serializes this DamageProfile to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DamageProfile &&
            (identical(other.em, em) || other.em == em) &&
            (identical(other.thermal, thermal) || other.thermal == thermal) &&
            (identical(other.kinetic, kinetic) || other.kinetic == kinetic) &&
            (identical(other.explosive, explosive) ||
                other.explosive == explosive));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, em, thermal, kinetic, explosive);

  @override
  String toString() {
    return 'DamageProfile(em: $em, thermal: $thermal, kinetic: $kinetic, explosive: $explosive)';
  }
}

/// @nodoc
abstract mixin class $DamageProfileCopyWith<$Res> {
  factory $DamageProfileCopyWith(
          DamageProfile value, $Res Function(DamageProfile) _then) =
      _$DamageProfileCopyWithImpl;
  @useResult
  $Res call({double em, double thermal, double kinetic, double explosive});
}

/// @nodoc
class _$DamageProfileCopyWithImpl<$Res>
    implements $DamageProfileCopyWith<$Res> {
  _$DamageProfileCopyWithImpl(this._self, this._then);

  final DamageProfile _self;
  final $Res Function(DamageProfile) _then;

  /// Create a copy of DamageProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? em = null,
    Object? thermal = null,
    Object? kinetic = null,
    Object? explosive = null,
  }) {
    return _then(_self.copyWith(
      em: null == em
          ? _self.em
          : em // ignore: cast_nullable_to_non_nullable
              as double,
      thermal: null == thermal
          ? _self.thermal
          : thermal // ignore: cast_nullable_to_non_nullable
              as double,
      kinetic: null == kinetic
          ? _self.kinetic
          : kinetic // ignore: cast_nullable_to_non_nullable
              as double,
      explosive: null == explosive
          ? _self.explosive
          : explosive // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _DamageProfile implements DamageProfile {
  const _DamageProfile(
      {required this.em,
      required this.thermal,
      required this.kinetic,
      required this.explosive});
  factory _DamageProfile.fromJson(Map<String, dynamic> json) =>
      _$DamageProfileFromJson(json);

  @override
  final double em;
  @override
  final double thermal;
  @override
  final double kinetic;
  @override
  final double explosive;

  /// Create a copy of DamageProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DamageProfileCopyWith<_DamageProfile> get copyWith =>
      __$DamageProfileCopyWithImpl<_DamageProfile>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DamageProfileToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DamageProfile &&
            (identical(other.em, em) || other.em == em) &&
            (identical(other.thermal, thermal) || other.thermal == thermal) &&
            (identical(other.kinetic, kinetic) || other.kinetic == kinetic) &&
            (identical(other.explosive, explosive) ||
                other.explosive == explosive));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, em, thermal, kinetic, explosive);

  @override
  String toString() {
    return 'DamageProfile(em: $em, thermal: $thermal, kinetic: $kinetic, explosive: $explosive)';
  }
}

/// @nodoc
abstract mixin class _$DamageProfileCopyWith<$Res>
    implements $DamageProfileCopyWith<$Res> {
  factory _$DamageProfileCopyWith(
          _DamageProfile value, $Res Function(_DamageProfile) _then) =
      __$DamageProfileCopyWithImpl;
  @override
  @useResult
  $Res call({double em, double thermal, double kinetic, double explosive});
}

/// @nodoc
class __$DamageProfileCopyWithImpl<$Res>
    implements _$DamageProfileCopyWith<$Res> {
  __$DamageProfileCopyWithImpl(this._self, this._then);

  final _DamageProfile _self;
  final $Res Function(_DamageProfile) _then;

  /// Create a copy of DamageProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? em = null,
    Object? thermal = null,
    Object? kinetic = null,
    Object? explosive = null,
  }) {
    return _then(_DamageProfile(
      em: null == em
          ? _self.em
          : em // ignore: cast_nullable_to_non_nullable
              as double,
      thermal: null == thermal
          ? _self.thermal
          : thermal // ignore: cast_nullable_to_non_nullable
              as double,
      kinetic: null == kinetic
          ? _self.kinetic
          : kinetic // ignore: cast_nullable_to_non_nullable
              as double,
      explosive: null == explosive
          ? _self.explosive
          : explosive // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

// dart format on
