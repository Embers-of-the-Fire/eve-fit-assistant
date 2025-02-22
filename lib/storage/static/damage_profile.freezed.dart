// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'damage_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DamageProfile _$DamageProfileFromJson(Map<String, dynamic> json) {
  return _DamageProfile.fromJson(json);
}

/// @nodoc
mixin _$DamageProfile {
  double get em => throw _privateConstructorUsedError;
  double get thermal => throw _privateConstructorUsedError;
  double get kinetic => throw _privateConstructorUsedError;
  double get explosive => throw _privateConstructorUsedError;

  /// Serializes this DamageProfile to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DamageProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DamageProfileCopyWith<DamageProfile> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DamageProfileCopyWith<$Res> {
  factory $DamageProfileCopyWith(
          DamageProfile value, $Res Function(DamageProfile) then) =
      _$DamageProfileCopyWithImpl<$Res, DamageProfile>;
  @useResult
  $Res call({double em, double thermal, double kinetic, double explosive});
}

/// @nodoc
class _$DamageProfileCopyWithImpl<$Res, $Val extends DamageProfile>
    implements $DamageProfileCopyWith<$Res> {
  _$DamageProfileCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

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
    return _then(_value.copyWith(
      em: null == em
          ? _value.em
          : em // ignore: cast_nullable_to_non_nullable
              as double,
      thermal: null == thermal
          ? _value.thermal
          : thermal // ignore: cast_nullable_to_non_nullable
              as double,
      kinetic: null == kinetic
          ? _value.kinetic
          : kinetic // ignore: cast_nullable_to_non_nullable
              as double,
      explosive: null == explosive
          ? _value.explosive
          : explosive // ignore: cast_nullable_to_non_nullable
              as double,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DamageProfileImplCopyWith<$Res>
    implements $DamageProfileCopyWith<$Res> {
  factory _$$DamageProfileImplCopyWith(
          _$DamageProfileImpl value, $Res Function(_$DamageProfileImpl) then) =
      __$$DamageProfileImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({double em, double thermal, double kinetic, double explosive});
}

/// @nodoc
class __$$DamageProfileImplCopyWithImpl<$Res>
    extends _$DamageProfileCopyWithImpl<$Res, _$DamageProfileImpl>
    implements _$$DamageProfileImplCopyWith<$Res> {
  __$$DamageProfileImplCopyWithImpl(
      _$DamageProfileImpl _value, $Res Function(_$DamageProfileImpl) _then)
      : super(_value, _then);

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
    return _then(_$DamageProfileImpl(
      em: null == em
          ? _value.em
          : em // ignore: cast_nullable_to_non_nullable
              as double,
      thermal: null == thermal
          ? _value.thermal
          : thermal // ignore: cast_nullable_to_non_nullable
              as double,
      kinetic: null == kinetic
          ? _value.kinetic
          : kinetic // ignore: cast_nullable_to_non_nullable
              as double,
      explosive: null == explosive
          ? _value.explosive
          : explosive // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DamageProfileImpl implements _DamageProfile {
  const _$DamageProfileImpl(
      {required this.em,
      required this.thermal,
      required this.kinetic,
      required this.explosive});

  factory _$DamageProfileImpl.fromJson(Map<String, dynamic> json) =>
      _$$DamageProfileImplFromJson(json);

  @override
  final double em;
  @override
  final double thermal;
  @override
  final double kinetic;
  @override
  final double explosive;

  @override
  String toString() {
    return 'DamageProfile(em: $em, thermal: $thermal, kinetic: $kinetic, explosive: $explosive)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DamageProfileImpl &&
            (identical(other.em, em) || other.em == em) &&
            (identical(other.thermal, thermal) || other.thermal == thermal) &&
            (identical(other.kinetic, kinetic) || other.kinetic == kinetic) &&
            (identical(other.explosive, explosive) ||
                other.explosive == explosive));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, em, thermal, kinetic, explosive);

  /// Create a copy of DamageProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DamageProfileImplCopyWith<_$DamageProfileImpl> get copyWith =>
      __$$DamageProfileImplCopyWithImpl<_$DamageProfileImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DamageProfileImplToJson(
      this,
    );
  }
}

abstract class _DamageProfile implements DamageProfile {
  const factory _DamageProfile(
      {required final double em,
      required final double thermal,
      required final double kinetic,
      required final double explosive}) = _$DamageProfileImpl;

  factory _DamageProfile.fromJson(Map<String, dynamic> json) =
      _$DamageProfileImpl.fromJson;

  @override
  double get em;
  @override
  double get thermal;
  @override
  double get kinetic;
  @override
  double get explosive;

  /// Create a copy of DamageProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DamageProfileImplCopyWith<_$DamageProfileImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
