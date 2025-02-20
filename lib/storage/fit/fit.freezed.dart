// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fit.dart';

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

SlotItem _$SlotItemFromJson(Map<String, dynamic> json) {
  return _SlotItem.fromJson(json);
}

/// @nodoc
mixin _$SlotItem {
  int get itemID => throw _privateConstructorUsedError;
  int? get chargeID => throw _privateConstructorUsedError;
  SlotState get state => throw _privateConstructorUsedError;

  /// Serializes this SlotItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SlotItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SlotItemCopyWith<SlotItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SlotItemCopyWith<$Res> {
  factory $SlotItemCopyWith(SlotItem value, $Res Function(SlotItem) then) =
      _$SlotItemCopyWithImpl<$Res, SlotItem>;
  @useResult
  $Res call({int itemID, int? chargeID, SlotState state});
}

/// @nodoc
class _$SlotItemCopyWithImpl<$Res, $Val extends SlotItem>
    implements $SlotItemCopyWith<$Res> {
  _$SlotItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SlotItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? itemID = null,
    Object? chargeID = freezed,
    Object? state = null,
  }) {
    return _then(_value.copyWith(
      itemID: null == itemID
          ? _value.itemID
          : itemID // ignore: cast_nullable_to_non_nullable
              as int,
      chargeID: freezed == chargeID
          ? _value.chargeID
          : chargeID // ignore: cast_nullable_to_non_nullable
              as int?,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as SlotState,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SlotItemImplCopyWith<$Res>
    implements $SlotItemCopyWith<$Res> {
  factory _$$SlotItemImplCopyWith(
          _$SlotItemImpl value, $Res Function(_$SlotItemImpl) then) =
      __$$SlotItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int itemID, int? chargeID, SlotState state});
}

/// @nodoc
class __$$SlotItemImplCopyWithImpl<$Res>
    extends _$SlotItemCopyWithImpl<$Res, _$SlotItemImpl>
    implements _$$SlotItemImplCopyWith<$Res> {
  __$$SlotItemImplCopyWithImpl(
      _$SlotItemImpl _value, $Res Function(_$SlotItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of SlotItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? itemID = null,
    Object? chargeID = freezed,
    Object? state = null,
  }) {
    return _then(_$SlotItemImpl(
      itemID: null == itemID
          ? _value.itemID
          : itemID // ignore: cast_nullable_to_non_nullable
              as int,
      chargeID: freezed == chargeID
          ? _value.chargeID
          : chargeID // ignore: cast_nullable_to_non_nullable
              as int?,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as SlotState,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SlotItemImpl implements _SlotItem {
  const _$SlotItemImpl(
      {required this.itemID, required this.chargeID, required this.state});

  factory _$SlotItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$SlotItemImplFromJson(json);

  @override
  final int itemID;
  @override
  final int? chargeID;
  @override
  final SlotState state;

  @override
  String toString() {
    return 'SlotItem(itemID: $itemID, chargeID: $chargeID, state: $state)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SlotItemImpl &&
            (identical(other.itemID, itemID) || other.itemID == itemID) &&
            (identical(other.chargeID, chargeID) ||
                other.chargeID == chargeID) &&
            (identical(other.state, state) || other.state == state));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, itemID, chargeID, state);

  /// Create a copy of SlotItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SlotItemImplCopyWith<_$SlotItemImpl> get copyWith =>
      __$$SlotItemImplCopyWithImpl<_$SlotItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SlotItemImplToJson(
      this,
    );
  }
}

abstract class _SlotItem implements SlotItem {
  const factory _SlotItem(
      {required final int itemID,
      required final int? chargeID,
      required final SlotState state}) = _$SlotItemImpl;

  factory _SlotItem.fromJson(Map<String, dynamic> json) =
      _$SlotItemImpl.fromJson;

  @override
  int get itemID;
  @override
  int? get chargeID;
  @override
  SlotState get state;

  /// Create a copy of SlotItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SlotItemImplCopyWith<_$SlotItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

DroneItem _$DroneItemFromJson(Map<String, dynamic> json) {
  return _DroneItem.fromJson(json);
}

/// @nodoc
mixin _$DroneItem {
  int get itemID => throw _privateConstructorUsedError;
  int get amount => throw _privateConstructorUsedError;
  DroneState get state => throw _privateConstructorUsedError;

  /// Serializes this DroneItem to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DroneItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DroneItemCopyWith<DroneItem> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DroneItemCopyWith<$Res> {
  factory $DroneItemCopyWith(DroneItem value, $Res Function(DroneItem) then) =
      _$DroneItemCopyWithImpl<$Res, DroneItem>;
  @useResult
  $Res call({int itemID, int amount, DroneState state});
}

/// @nodoc
class _$DroneItemCopyWithImpl<$Res, $Val extends DroneItem>
    implements $DroneItemCopyWith<$Res> {
  _$DroneItemCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DroneItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? itemID = null,
    Object? amount = null,
    Object? state = null,
  }) {
    return _then(_value.copyWith(
      itemID: null == itemID
          ? _value.itemID
          : itemID // ignore: cast_nullable_to_non_nullable
              as int,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as DroneState,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DroneItemImplCopyWith<$Res>
    implements $DroneItemCopyWith<$Res> {
  factory _$$DroneItemImplCopyWith(
          _$DroneItemImpl value, $Res Function(_$DroneItemImpl) then) =
      __$$DroneItemImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int itemID, int amount, DroneState state});
}

/// @nodoc
class __$$DroneItemImplCopyWithImpl<$Res>
    extends _$DroneItemCopyWithImpl<$Res, _$DroneItemImpl>
    implements _$$DroneItemImplCopyWith<$Res> {
  __$$DroneItemImplCopyWithImpl(
      _$DroneItemImpl _value, $Res Function(_$DroneItemImpl) _then)
      : super(_value, _then);

  /// Create a copy of DroneItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? itemID = null,
    Object? amount = null,
    Object? state = null,
  }) {
    return _then(_$DroneItemImpl(
      itemID: null == itemID
          ? _value.itemID
          : itemID // ignore: cast_nullable_to_non_nullable
              as int,
      amount: null == amount
          ? _value.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as DroneState,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DroneItemImpl implements _DroneItem {
  const _$DroneItemImpl(
      {required this.itemID, required this.amount, required this.state});

  factory _$DroneItemImpl.fromJson(Map<String, dynamic> json) =>
      _$$DroneItemImplFromJson(json);

  @override
  final int itemID;
  @override
  final int amount;
  @override
  final DroneState state;

  @override
  String toString() {
    return 'DroneItem(itemID: $itemID, amount: $amount, state: $state)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DroneItemImpl &&
            (identical(other.itemID, itemID) || other.itemID == itemID) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.state, state) || other.state == state));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, itemID, amount, state);

  /// Create a copy of DroneItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DroneItemImplCopyWith<_$DroneItemImpl> get copyWith =>
      __$$DroneItemImplCopyWithImpl<_$DroneItemImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DroneItemImplToJson(
      this,
    );
  }
}

abstract class _DroneItem implements DroneItem {
  const factory _DroneItem(
      {required final int itemID,
      required final int amount,
      required final DroneState state}) = _$DroneItemImpl;

  factory _DroneItem.fromJson(Map<String, dynamic> json) =
      _$DroneItemImpl.fromJson;

  @override
  int get itemID;
  @override
  int get amount;
  @override
  DroneState get state;

  /// Create a copy of DroneItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DroneItemImplCopyWith<_$DroneItemImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
