// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ErrorKey {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is ErrorKey);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'ErrorKey()';
  }
}

/// @nodoc
class $ErrorKeyCopyWith<$Res> {
  $ErrorKeyCopyWith(ErrorKey _, $Res Function(ErrorKey) __);
}

/// @nodoc

class ErrorKey_IncompatibleChargeSize extends ErrorKey {
  const ErrorKey_IncompatibleChargeSize(
      {required this.expected, required this.actual})
      : super._();

  final int expected;
  final int actual;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ErrorKey_IncompatibleChargeSizeCopyWith<ErrorKey_IncompatibleChargeSize>
      get copyWith => _$ErrorKey_IncompatibleChargeSizeCopyWithImpl<
          ErrorKey_IncompatibleChargeSize>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ErrorKey_IncompatibleChargeSize &&
            (identical(other.expected, expected) ||
                other.expected == expected) &&
            (identical(other.actual, actual) || other.actual == actual));
  }

  @override
  int get hashCode => Object.hash(runtimeType, expected, actual);

  @override
  String toString() {
    return 'ErrorKey.incompatibleChargeSize(expected: $expected, actual: $actual)';
  }
}

/// @nodoc
abstract mixin class $ErrorKey_IncompatibleChargeSizeCopyWith<$Res>
    implements $ErrorKeyCopyWith<$Res> {
  factory $ErrorKey_IncompatibleChargeSizeCopyWith(
          ErrorKey_IncompatibleChargeSize value,
          $Res Function(ErrorKey_IncompatibleChargeSize) _then) =
      _$ErrorKey_IncompatibleChargeSizeCopyWithImpl;
  @useResult
  $Res call({int expected, int actual});
}

/// @nodoc
class _$ErrorKey_IncompatibleChargeSizeCopyWithImpl<$Res>
    implements $ErrorKey_IncompatibleChargeSizeCopyWith<$Res> {
  _$ErrorKey_IncompatibleChargeSizeCopyWithImpl(this._self, this._then);

  final ErrorKey_IncompatibleChargeSize _self;
  final $Res Function(ErrorKey_IncompatibleChargeSize) _then;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? expected = null,
    Object? actual = null,
  }) {
    return _then(ErrorKey_IncompatibleChargeSize(
      expected: null == expected
          ? _self.expected
          : expected // ignore: cast_nullable_to_non_nullable
              as int,
      actual: null == actual
          ? _self.actual
          : actual // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class ErrorKey_IncompatibleChargeCapacity extends ErrorKey {
  const ErrorKey_IncompatibleChargeCapacity(
      {required this.max, required this.actual})
      : super._();

  final double max;
  final double actual;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ErrorKey_IncompatibleChargeCapacityCopyWith<
          ErrorKey_IncompatibleChargeCapacity>
      get copyWith => _$ErrorKey_IncompatibleChargeCapacityCopyWithImpl<
          ErrorKey_IncompatibleChargeCapacity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ErrorKey_IncompatibleChargeCapacity &&
            (identical(other.max, max) || other.max == max) &&
            (identical(other.actual, actual) || other.actual == actual));
  }

  @override
  int get hashCode => Object.hash(runtimeType, max, actual);

  @override
  String toString() {
    return 'ErrorKey.incompatibleChargeCapacity(max: $max, actual: $actual)';
  }
}

/// @nodoc
abstract mixin class $ErrorKey_IncompatibleChargeCapacityCopyWith<$Res>
    implements $ErrorKeyCopyWith<$Res> {
  factory $ErrorKey_IncompatibleChargeCapacityCopyWith(
          ErrorKey_IncompatibleChargeCapacity value,
          $Res Function(ErrorKey_IncompatibleChargeCapacity) _then) =
      _$ErrorKey_IncompatibleChargeCapacityCopyWithImpl;
  @useResult
  $Res call({double max, double actual});
}

/// @nodoc
class _$ErrorKey_IncompatibleChargeCapacityCopyWithImpl<$Res>
    implements $ErrorKey_IncompatibleChargeCapacityCopyWith<$Res> {
  _$ErrorKey_IncompatibleChargeCapacityCopyWithImpl(this._self, this._then);

  final ErrorKey_IncompatibleChargeCapacity _self;
  final $Res Function(ErrorKey_IncompatibleChargeCapacity) _then;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? max = null,
    Object? actual = null,
  }) {
    return _then(ErrorKey_IncompatibleChargeCapacity(
      max: null == max
          ? _self.max
          : max // ignore: cast_nullable_to_non_nullable
              as double,
      actual: null == actual
          ? _self.actual
          : actual // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class ErrorKey_TooMuchTurret extends ErrorKey {
  const ErrorKey_TooMuchTurret({required this.expected, required this.actual})
      : super._();

  final int expected;
  final int actual;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ErrorKey_TooMuchTurretCopyWith<ErrorKey_TooMuchTurret> get copyWith =>
      _$ErrorKey_TooMuchTurretCopyWithImpl<ErrorKey_TooMuchTurret>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ErrorKey_TooMuchTurret &&
            (identical(other.expected, expected) ||
                other.expected == expected) &&
            (identical(other.actual, actual) || other.actual == actual));
  }

  @override
  int get hashCode => Object.hash(runtimeType, expected, actual);

  @override
  String toString() {
    return 'ErrorKey.tooMuchTurret(expected: $expected, actual: $actual)';
  }
}

/// @nodoc
abstract mixin class $ErrorKey_TooMuchTurretCopyWith<$Res>
    implements $ErrorKeyCopyWith<$Res> {
  factory $ErrorKey_TooMuchTurretCopyWith(ErrorKey_TooMuchTurret value,
          $Res Function(ErrorKey_TooMuchTurret) _then) =
      _$ErrorKey_TooMuchTurretCopyWithImpl;
  @useResult
  $Res call({int expected, int actual});
}

/// @nodoc
class _$ErrorKey_TooMuchTurretCopyWithImpl<$Res>
    implements $ErrorKey_TooMuchTurretCopyWith<$Res> {
  _$ErrorKey_TooMuchTurretCopyWithImpl(this._self, this._then);

  final ErrorKey_TooMuchTurret _self;
  final $Res Function(ErrorKey_TooMuchTurret) _then;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? expected = null,
    Object? actual = null,
  }) {
    return _then(ErrorKey_TooMuchTurret(
      expected: null == expected
          ? _self.expected
          : expected // ignore: cast_nullable_to_non_nullable
              as int,
      actual: null == actual
          ? _self.actual
          : actual // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class ErrorKey_TooMuchLauncher extends ErrorKey {
  const ErrorKey_TooMuchLauncher({required this.expected, required this.actual})
      : super._();

  final int expected;
  final int actual;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ErrorKey_TooMuchLauncherCopyWith<ErrorKey_TooMuchLauncher> get copyWith =>
      _$ErrorKey_TooMuchLauncherCopyWithImpl<ErrorKey_TooMuchLauncher>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ErrorKey_TooMuchLauncher &&
            (identical(other.expected, expected) ||
                other.expected == expected) &&
            (identical(other.actual, actual) || other.actual == actual));
  }

  @override
  int get hashCode => Object.hash(runtimeType, expected, actual);

  @override
  String toString() {
    return 'ErrorKey.tooMuchLauncher(expected: $expected, actual: $actual)';
  }
}

/// @nodoc
abstract mixin class $ErrorKey_TooMuchLauncherCopyWith<$Res>
    implements $ErrorKeyCopyWith<$Res> {
  factory $ErrorKey_TooMuchLauncherCopyWith(ErrorKey_TooMuchLauncher value,
          $Res Function(ErrorKey_TooMuchLauncher) _then) =
      _$ErrorKey_TooMuchLauncherCopyWithImpl;
  @useResult
  $Res call({int expected, int actual});
}

/// @nodoc
class _$ErrorKey_TooMuchLauncherCopyWithImpl<$Res>
    implements $ErrorKey_TooMuchLauncherCopyWith<$Res> {
  _$ErrorKey_TooMuchLauncherCopyWithImpl(this._self, this._then);

  final ErrorKey_TooMuchLauncher _self;
  final $Res Function(ErrorKey_TooMuchLauncher) _then;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? expected = null,
    Object? actual = null,
  }) {
    return _then(ErrorKey_TooMuchLauncher(
      expected: null == expected
          ? _self.expected
          : expected // ignore: cast_nullable_to_non_nullable
              as int,
      actual: null == actual
          ? _self.actual
          : actual // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class ErrorKey_ConflictItem extends ErrorKey {
  const ErrorKey_ConflictItem({required this.groupId}) : super._();

  final int groupId;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ErrorKey_ConflictItemCopyWith<ErrorKey_ConflictItem> get copyWith =>
      _$ErrorKey_ConflictItemCopyWithImpl<ErrorKey_ConflictItem>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ErrorKey_ConflictItem &&
            (identical(other.groupId, groupId) || other.groupId == groupId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, groupId);

  @override
  String toString() {
    return 'ErrorKey.conflictItem(groupId: $groupId)';
  }
}

/// @nodoc
abstract mixin class $ErrorKey_ConflictItemCopyWith<$Res>
    implements $ErrorKeyCopyWith<$Res> {
  factory $ErrorKey_ConflictItemCopyWith(ErrorKey_ConflictItem value,
          $Res Function(ErrorKey_ConflictItem) _then) =
      _$ErrorKey_ConflictItemCopyWithImpl;
  @useResult
  $Res call({int groupId});
}

/// @nodoc
class _$ErrorKey_ConflictItemCopyWithImpl<$Res>
    implements $ErrorKey_ConflictItemCopyWith<$Res> {
  _$ErrorKey_ConflictItemCopyWithImpl(this._self, this._then);

  final ErrorKey_ConflictItem _self;
  final $Res Function(ErrorKey_ConflictItem) _then;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? groupId = null,
  }) {
    return _then(ErrorKey_ConflictItem(
      groupId: null == groupId
          ? _self.groupId
          : groupId // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class ErrorKey_DuplicateBooster extends ErrorKey {
  const ErrorKey_DuplicateBooster({required this.slot}) : super._();

  final int slot;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ErrorKey_DuplicateBoosterCopyWith<ErrorKey_DuplicateBooster> get copyWith =>
      _$ErrorKey_DuplicateBoosterCopyWithImpl<ErrorKey_DuplicateBooster>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ErrorKey_DuplicateBooster &&
            (identical(other.slot, slot) || other.slot == slot));
  }

  @override
  int get hashCode => Object.hash(runtimeType, slot);

  @override
  String toString() {
    return 'ErrorKey.duplicateBooster(slot: $slot)';
  }
}

/// @nodoc
abstract mixin class $ErrorKey_DuplicateBoosterCopyWith<$Res>
    implements $ErrorKeyCopyWith<$Res> {
  factory $ErrorKey_DuplicateBoosterCopyWith(ErrorKey_DuplicateBooster value,
          $Res Function(ErrorKey_DuplicateBooster) _then) =
      _$ErrorKey_DuplicateBoosterCopyWithImpl;
  @useResult
  $Res call({int slot});
}

/// @nodoc
class _$ErrorKey_DuplicateBoosterCopyWithImpl<$Res>
    implements $ErrorKey_DuplicateBoosterCopyWith<$Res> {
  _$ErrorKey_DuplicateBoosterCopyWithImpl(this._self, this._then);

  final ErrorKey_DuplicateBooster _self;
  final $Res Function(ErrorKey_DuplicateBooster) _then;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? slot = null,
  }) {
    return _then(ErrorKey_DuplicateBooster(
      slot: null == slot
          ? _self.slot
          : slot // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class ErrorKey_IncompatibleShipGroup extends ErrorKey {
  const ErrorKey_IncompatibleShipGroup({required this.expected}) : super._();

  final Int32List expected;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ErrorKey_IncompatibleShipGroupCopyWith<ErrorKey_IncompatibleShipGroup>
      get copyWith => _$ErrorKey_IncompatibleShipGroupCopyWithImpl<
          ErrorKey_IncompatibleShipGroup>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ErrorKey_IncompatibleShipGroup &&
            const DeepCollectionEquality().equals(other.expected, expected));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(expected));

  @override
  String toString() {
    return 'ErrorKey.incompatibleShipGroup(expected: $expected)';
  }
}

/// @nodoc
abstract mixin class $ErrorKey_IncompatibleShipGroupCopyWith<$Res>
    implements $ErrorKeyCopyWith<$Res> {
  factory $ErrorKey_IncompatibleShipGroupCopyWith(
          ErrorKey_IncompatibleShipGroup value,
          $Res Function(ErrorKey_IncompatibleShipGroup) _then) =
      _$ErrorKey_IncompatibleShipGroupCopyWithImpl;
  @useResult
  $Res call({Int32List expected});
}

/// @nodoc
class _$ErrorKey_IncompatibleShipGroupCopyWithImpl<$Res>
    implements $ErrorKey_IncompatibleShipGroupCopyWith<$Res> {
  _$ErrorKey_IncompatibleShipGroupCopyWithImpl(this._self, this._then);

  final ErrorKey_IncompatibleShipGroup _self;
  final $Res Function(ErrorKey_IncompatibleShipGroup) _then;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? expected = null,
  }) {
    return _then(ErrorKey_IncompatibleShipGroup(
      expected: null == expected
          ? _self.expected
          : expected // ignore: cast_nullable_to_non_nullable
              as Int32List,
    ));
  }
}

/// @nodoc

class ErrorKey_IncompatibleShipType extends ErrorKey {
  const ErrorKey_IncompatibleShipType({required this.expected}) : super._();

  final Int32List expected;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ErrorKey_IncompatibleShipTypeCopyWith<ErrorKey_IncompatibleShipType>
      get copyWith => _$ErrorKey_IncompatibleShipTypeCopyWithImpl<
          ErrorKey_IncompatibleShipType>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ErrorKey_IncompatibleShipType &&
            const DeepCollectionEquality().equals(other.expected, expected));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(expected));

  @override
  String toString() {
    return 'ErrorKey.incompatibleShipType(expected: $expected)';
  }
}

/// @nodoc
abstract mixin class $ErrorKey_IncompatibleShipTypeCopyWith<$Res>
    implements $ErrorKeyCopyWith<$Res> {
  factory $ErrorKey_IncompatibleShipTypeCopyWith(
          ErrorKey_IncompatibleShipType value,
          $Res Function(ErrorKey_IncompatibleShipType) _then) =
      _$ErrorKey_IncompatibleShipTypeCopyWithImpl;
  @useResult
  $Res call({Int32List expected});
}

/// @nodoc
class _$ErrorKey_IncompatibleShipTypeCopyWithImpl<$Res>
    implements $ErrorKey_IncompatibleShipTypeCopyWith<$Res> {
  _$ErrorKey_IncompatibleShipTypeCopyWithImpl(this._self, this._then);

  final ErrorKey_IncompatibleShipType _self;
  final $Res Function(ErrorKey_IncompatibleShipType) _then;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? expected = null,
  }) {
    return _then(ErrorKey_IncompatibleShipType(
      expected: null == expected
          ? _self.expected
          : expected // ignore: cast_nullable_to_non_nullable
              as Int32List,
    ));
  }
}

/// @nodoc

class ErrorKey_IncompatibleRigSize extends ErrorKey {
  const ErrorKey_IncompatibleRigSize(
      {required this.expected, required this.actual})
      : super._();

  final int expected;
  final int actual;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ErrorKey_IncompatibleRigSizeCopyWith<ErrorKey_IncompatibleRigSize>
      get copyWith => _$ErrorKey_IncompatibleRigSizeCopyWithImpl<
          ErrorKey_IncompatibleRigSize>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ErrorKey_IncompatibleRigSize &&
            (identical(other.expected, expected) ||
                other.expected == expected) &&
            (identical(other.actual, actual) || other.actual == actual));
  }

  @override
  int get hashCode => Object.hash(runtimeType, expected, actual);

  @override
  String toString() {
    return 'ErrorKey.incompatibleRigSize(expected: $expected, actual: $actual)';
  }
}

/// @nodoc
abstract mixin class $ErrorKey_IncompatibleRigSizeCopyWith<$Res>
    implements $ErrorKeyCopyWith<$Res> {
  factory $ErrorKey_IncompatibleRigSizeCopyWith(
          ErrorKey_IncompatibleRigSize value,
          $Res Function(ErrorKey_IncompatibleRigSize) _then) =
      _$ErrorKey_IncompatibleRigSizeCopyWithImpl;
  @useResult
  $Res call({int expected, int actual});
}

/// @nodoc
class _$ErrorKey_IncompatibleRigSizeCopyWithImpl<$Res>
    implements $ErrorKey_IncompatibleRigSizeCopyWith<$Res> {
  _$ErrorKey_IncompatibleRigSizeCopyWithImpl(this._self, this._then);

  final ErrorKey_IncompatibleRigSize _self;
  final $Res Function(ErrorKey_IncompatibleRigSize) _then;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? expected = null,
    Object? actual = null,
  }) {
    return _then(ErrorKey_IncompatibleRigSize(
      expected: null == expected
          ? _self.expected
          : expected // ignore: cast_nullable_to_non_nullable
              as int,
      actual: null == actual
          ? _self.actual
          : actual // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
mixin _$SlotInfo {
  SlotType get slot;
  int? get index;

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SlotInfoCopyWith<SlotInfo> get copyWith =>
      _$SlotInfoCopyWithImpl<SlotInfo>(this as SlotInfo, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SlotInfo &&
            (identical(other.slot, slot) || other.slot == slot) &&
            (identical(other.index, index) || other.index == index));
  }

  @override
  int get hashCode => Object.hash(runtimeType, slot, index);

  @override
  String toString() {
    return 'SlotInfo(slot: $slot, index: $index)';
  }
}

/// @nodoc
abstract mixin class $SlotInfoCopyWith<$Res> {
  factory $SlotInfoCopyWith(SlotInfo value, $Res Function(SlotInfo) _then) =
      _$SlotInfoCopyWithImpl;
  @useResult
  $Res call({SlotType slot, int? index});
}

/// @nodoc
class _$SlotInfoCopyWithImpl<$Res> implements $SlotInfoCopyWith<$Res> {
  _$SlotInfoCopyWithImpl(this._self, this._then);

  final SlotInfo _self;
  final $Res Function(SlotInfo) _then;

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? slot = null,
    Object? index = freezed,
  }) {
    return _then(_self.copyWith(
      slot: null == slot
          ? _self.slot
          : slot // ignore: cast_nullable_to_non_nullable
              as SlotType,
      index: freezed == index
          ? _self.index
          : index // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc

class SlotInfo_Error extends SlotInfo {
  const SlotInfo_Error({required this.slot, this.index, required this.errorKey})
      : super._();

  @override
  final SlotType slot;
  @override
  final int? index;
  final ErrorKey errorKey;

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SlotInfo_ErrorCopyWith<SlotInfo_Error> get copyWith =>
      _$SlotInfo_ErrorCopyWithImpl<SlotInfo_Error>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SlotInfo_Error &&
            (identical(other.slot, slot) || other.slot == slot) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.errorKey, errorKey) ||
                other.errorKey == errorKey));
  }

  @override
  int get hashCode => Object.hash(runtimeType, slot, index, errorKey);

  @override
  String toString() {
    return 'SlotInfo.error(slot: $slot, index: $index, errorKey: $errorKey)';
  }
}

/// @nodoc
abstract mixin class $SlotInfo_ErrorCopyWith<$Res>
    implements $SlotInfoCopyWith<$Res> {
  factory $SlotInfo_ErrorCopyWith(
          SlotInfo_Error value, $Res Function(SlotInfo_Error) _then) =
      _$SlotInfo_ErrorCopyWithImpl;
  @override
  @useResult
  $Res call({SlotType slot, int? index, ErrorKey errorKey});

  $ErrorKeyCopyWith<$Res> get errorKey;
}

/// @nodoc
class _$SlotInfo_ErrorCopyWithImpl<$Res>
    implements $SlotInfo_ErrorCopyWith<$Res> {
  _$SlotInfo_ErrorCopyWithImpl(this._self, this._then);

  final SlotInfo_Error _self;
  final $Res Function(SlotInfo_Error) _then;

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? slot = null,
    Object? index = freezed,
    Object? errorKey = null,
  }) {
    return _then(SlotInfo_Error(
      slot: null == slot
          ? _self.slot
          : slot // ignore: cast_nullable_to_non_nullable
              as SlotType,
      index: freezed == index
          ? _self.index
          : index // ignore: cast_nullable_to_non_nullable
              as int?,
      errorKey: null == errorKey
          ? _self.errorKey
          : errorKey // ignore: cast_nullable_to_non_nullable
              as ErrorKey,
    ));
  }

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ErrorKeyCopyWith<$Res> get errorKey {
    return $ErrorKeyCopyWith<$Res>(_self.errorKey, (value) {
      return _then(_self.copyWith(errorKey: value));
    });
  }
}

/// @nodoc

class SlotInfo_Warning extends SlotInfo {
  const SlotInfo_Warning(
      {required this.slot, this.index, required this.warningKey})
      : super._();

  @override
  final SlotType slot;
  @override
  final int? index;
  final WarningKey warningKey;

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SlotInfo_WarningCopyWith<SlotInfo_Warning> get copyWith =>
      _$SlotInfo_WarningCopyWithImpl<SlotInfo_Warning>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SlotInfo_Warning &&
            (identical(other.slot, slot) || other.slot == slot) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.warningKey, warningKey) ||
                other.warningKey == warningKey));
  }

  @override
  int get hashCode => Object.hash(runtimeType, slot, index, warningKey);

  @override
  String toString() {
    return 'SlotInfo.warning(slot: $slot, index: $index, warningKey: $warningKey)';
  }
}

/// @nodoc
abstract mixin class $SlotInfo_WarningCopyWith<$Res>
    implements $SlotInfoCopyWith<$Res> {
  factory $SlotInfo_WarningCopyWith(
          SlotInfo_Warning value, $Res Function(SlotInfo_Warning) _then) =
      _$SlotInfo_WarningCopyWithImpl;
  @override
  @useResult
  $Res call({SlotType slot, int? index, WarningKey warningKey});

  $WarningKeyCopyWith<$Res> get warningKey;
}

/// @nodoc
class _$SlotInfo_WarningCopyWithImpl<$Res>
    implements $SlotInfo_WarningCopyWith<$Res> {
  _$SlotInfo_WarningCopyWithImpl(this._self, this._then);

  final SlotInfo_Warning _self;
  final $Res Function(SlotInfo_Warning) _then;

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? slot = null,
    Object? index = freezed,
    Object? warningKey = null,
  }) {
    return _then(SlotInfo_Warning(
      slot: null == slot
          ? _self.slot
          : slot // ignore: cast_nullable_to_non_nullable
              as SlotType,
      index: freezed == index
          ? _self.index
          : index // ignore: cast_nullable_to_non_nullable
              as int?,
      warningKey: null == warningKey
          ? _self.warningKey
          : warningKey // ignore: cast_nullable_to_non_nullable
              as WarningKey,
    ));
  }

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $WarningKeyCopyWith<$Res> get warningKey {
    return $WarningKeyCopyWith<$Res>(_self.warningKey, (value) {
      return _then(_self.copyWith(warningKey: value));
    });
  }
}

/// @nodoc
mixin _$WarningKey {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is WarningKey);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'WarningKey()';
  }
}

/// @nodoc
class $WarningKeyCopyWith<$Res> {
  $WarningKeyCopyWith(WarningKey _, $Res Function(WarningKey) __);
}

/// @nodoc

class WarningKey_MissingCharge extends WarningKey {
  const WarningKey_MissingCharge() : super._();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is WarningKey_MissingCharge);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'WarningKey.missingCharge()';
  }
}

/// @nodoc

class WarningKey_Placeholder extends WarningKey {
  const WarningKey_Placeholder(this.field0) : super._();

  final int field0;

  /// Create a copy of WarningKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WarningKey_PlaceholderCopyWith<WarningKey_Placeholder> get copyWith =>
      _$WarningKey_PlaceholderCopyWithImpl<WarningKey_Placeholder>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WarningKey_Placeholder &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'WarningKey.placeholder(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $WarningKey_PlaceholderCopyWith<$Res>
    implements $WarningKeyCopyWith<$Res> {
  factory $WarningKey_PlaceholderCopyWith(WarningKey_Placeholder value,
          $Res Function(WarningKey_Placeholder) _then) =
      _$WarningKey_PlaceholderCopyWithImpl;
  @useResult
  $Res call({int field0});
}

/// @nodoc
class _$WarningKey_PlaceholderCopyWithImpl<$Res>
    implements $WarningKey_PlaceholderCopyWith<$Res> {
  _$WarningKey_PlaceholderCopyWithImpl(this._self, this._then);

  final WarningKey_Placeholder _self;
  final $Res Function(WarningKey_Placeholder) _then;

  /// Create a copy of WarningKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(WarningKey_Placeholder(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
