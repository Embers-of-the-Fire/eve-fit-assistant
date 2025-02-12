// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$ErrorKey {
  num get actual => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int expected, int actual) incompatibleChargeSize,
    required TResult Function(double max, double actual)
        incompatibleChargeCapacity,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int expected, int actual)? incompatibleChargeSize,
    TResult? Function(double max, double actual)? incompatibleChargeCapacity,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int expected, int actual)? incompatibleChargeSize,
    TResult Function(double max, double actual)? incompatibleChargeCapacity,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ErrorKey_IncompatibleChargeSize value)
        incompatibleChargeSize,
    required TResult Function(ErrorKey_IncompatibleChargeCapacity value)
        incompatibleChargeCapacity,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ErrorKey_IncompatibleChargeSize value)?
        incompatibleChargeSize,
    TResult? Function(ErrorKey_IncompatibleChargeCapacity value)?
        incompatibleChargeCapacity,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ErrorKey_IncompatibleChargeSize value)?
        incompatibleChargeSize,
    TResult Function(ErrorKey_IncompatibleChargeCapacity value)?
        incompatibleChargeCapacity,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ErrorKeyCopyWith<$Res> {
  factory $ErrorKeyCopyWith(ErrorKey value, $Res Function(ErrorKey) then) =
      _$ErrorKeyCopyWithImpl<$Res, ErrorKey>;
}

/// @nodoc
class _$ErrorKeyCopyWithImpl<$Res, $Val extends ErrorKey>
    implements $ErrorKeyCopyWith<$Res> {
  _$ErrorKeyCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
}

/// @nodoc
abstract class _$$ErrorKey_IncompatibleChargeSizeImplCopyWith<$Res> {
  factory _$$ErrorKey_IncompatibleChargeSizeImplCopyWith(
          _$ErrorKey_IncompatibleChargeSizeImpl value,
          $Res Function(_$ErrorKey_IncompatibleChargeSizeImpl) then) =
      __$$ErrorKey_IncompatibleChargeSizeImplCopyWithImpl<$Res>;
  @useResult
  $Res call({int expected, int actual});
}

/// @nodoc
class __$$ErrorKey_IncompatibleChargeSizeImplCopyWithImpl<$Res>
    extends _$ErrorKeyCopyWithImpl<$Res, _$ErrorKey_IncompatibleChargeSizeImpl>
    implements _$$ErrorKey_IncompatibleChargeSizeImplCopyWith<$Res> {
  __$$ErrorKey_IncompatibleChargeSizeImplCopyWithImpl(
      _$ErrorKey_IncompatibleChargeSizeImpl _value,
      $Res Function(_$ErrorKey_IncompatibleChargeSizeImpl) _then)
      : super(_value, _then);

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? expected = null,
    Object? actual = null,
  }) {
    return _then(_$ErrorKey_IncompatibleChargeSizeImpl(
      expected: null == expected
          ? _value.expected
          : expected // ignore: cast_nullable_to_non_nullable
              as int,
      actual: null == actual
          ? _value.actual
          : actual // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$ErrorKey_IncompatibleChargeSizeImpl
    extends ErrorKey_IncompatibleChargeSize {
  const _$ErrorKey_IncompatibleChargeSizeImpl(
      {required this.expected, required this.actual})
      : super._();

  @override
  final int expected;
  @override
  final int actual;

  @override
  String toString() {
    return 'ErrorKey.incompatibleChargeSize(expected: $expected, actual: $actual)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ErrorKey_IncompatibleChargeSizeImpl &&
            (identical(other.expected, expected) ||
                other.expected == expected) &&
            (identical(other.actual, actual) || other.actual == actual));
  }

  @override
  int get hashCode => Object.hash(runtimeType, expected, actual);

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ErrorKey_IncompatibleChargeSizeImplCopyWith<
          _$ErrorKey_IncompatibleChargeSizeImpl>
      get copyWith => __$$ErrorKey_IncompatibleChargeSizeImplCopyWithImpl<
          _$ErrorKey_IncompatibleChargeSizeImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int expected, int actual) incompatibleChargeSize,
    required TResult Function(double max, double actual)
        incompatibleChargeCapacity,
  }) {
    return incompatibleChargeSize(expected, actual);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int expected, int actual)? incompatibleChargeSize,
    TResult? Function(double max, double actual)? incompatibleChargeCapacity,
  }) {
    return incompatibleChargeSize?.call(expected, actual);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int expected, int actual)? incompatibleChargeSize,
    TResult Function(double max, double actual)? incompatibleChargeCapacity,
    required TResult orElse(),
  }) {
    if (incompatibleChargeSize != null) {
      return incompatibleChargeSize(expected, actual);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ErrorKey_IncompatibleChargeSize value)
        incompatibleChargeSize,
    required TResult Function(ErrorKey_IncompatibleChargeCapacity value)
        incompatibleChargeCapacity,
  }) {
    return incompatibleChargeSize(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ErrorKey_IncompatibleChargeSize value)?
        incompatibleChargeSize,
    TResult? Function(ErrorKey_IncompatibleChargeCapacity value)?
        incompatibleChargeCapacity,
  }) {
    return incompatibleChargeSize?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ErrorKey_IncompatibleChargeSize value)?
        incompatibleChargeSize,
    TResult Function(ErrorKey_IncompatibleChargeCapacity value)?
        incompatibleChargeCapacity,
    required TResult orElse(),
  }) {
    if (incompatibleChargeSize != null) {
      return incompatibleChargeSize(this);
    }
    return orElse();
  }
}

abstract class ErrorKey_IncompatibleChargeSize extends ErrorKey {
  const factory ErrorKey_IncompatibleChargeSize(
      {required final int expected,
      required final int actual}) = _$ErrorKey_IncompatibleChargeSizeImpl;
  const ErrorKey_IncompatibleChargeSize._() : super._();

  int get expected;
  @override
  int get actual;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ErrorKey_IncompatibleChargeSizeImplCopyWith<
          _$ErrorKey_IncompatibleChargeSizeImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$ErrorKey_IncompatibleChargeCapacityImplCopyWith<$Res> {
  factory _$$ErrorKey_IncompatibleChargeCapacityImplCopyWith(
          _$ErrorKey_IncompatibleChargeCapacityImpl value,
          $Res Function(_$ErrorKey_IncompatibleChargeCapacityImpl) then) =
      __$$ErrorKey_IncompatibleChargeCapacityImplCopyWithImpl<$Res>;
  @useResult
  $Res call({double max, double actual});
}

/// @nodoc
class __$$ErrorKey_IncompatibleChargeCapacityImplCopyWithImpl<$Res>
    extends _$ErrorKeyCopyWithImpl<$Res,
        _$ErrorKey_IncompatibleChargeCapacityImpl>
    implements _$$ErrorKey_IncompatibleChargeCapacityImplCopyWith<$Res> {
  __$$ErrorKey_IncompatibleChargeCapacityImplCopyWithImpl(
      _$ErrorKey_IncompatibleChargeCapacityImpl _value,
      $Res Function(_$ErrorKey_IncompatibleChargeCapacityImpl) _then)
      : super(_value, _then);

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? max = null,
    Object? actual = null,
  }) {
    return _then(_$ErrorKey_IncompatibleChargeCapacityImpl(
      max: null == max
          ? _value.max
          : max // ignore: cast_nullable_to_non_nullable
              as double,
      actual: null == actual
          ? _value.actual
          : actual // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc

class _$ErrorKey_IncompatibleChargeCapacityImpl
    extends ErrorKey_IncompatibleChargeCapacity {
  const _$ErrorKey_IncompatibleChargeCapacityImpl(
      {required this.max, required this.actual})
      : super._();

  @override
  final double max;
  @override
  final double actual;

  @override
  String toString() {
    return 'ErrorKey.incompatibleChargeCapacity(max: $max, actual: $actual)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ErrorKey_IncompatibleChargeCapacityImpl &&
            (identical(other.max, max) || other.max == max) &&
            (identical(other.actual, actual) || other.actual == actual));
  }

  @override
  int get hashCode => Object.hash(runtimeType, max, actual);

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ErrorKey_IncompatibleChargeCapacityImplCopyWith<
          _$ErrorKey_IncompatibleChargeCapacityImpl>
      get copyWith => __$$ErrorKey_IncompatibleChargeCapacityImplCopyWithImpl<
          _$ErrorKey_IncompatibleChargeCapacityImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int expected, int actual) incompatibleChargeSize,
    required TResult Function(double max, double actual)
        incompatibleChargeCapacity,
  }) {
    return incompatibleChargeCapacity(max, actual);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int expected, int actual)? incompatibleChargeSize,
    TResult? Function(double max, double actual)? incompatibleChargeCapacity,
  }) {
    return incompatibleChargeCapacity?.call(max, actual);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int expected, int actual)? incompatibleChargeSize,
    TResult Function(double max, double actual)? incompatibleChargeCapacity,
    required TResult orElse(),
  }) {
    if (incompatibleChargeCapacity != null) {
      return incompatibleChargeCapacity(max, actual);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ErrorKey_IncompatibleChargeSize value)
        incompatibleChargeSize,
    required TResult Function(ErrorKey_IncompatibleChargeCapacity value)
        incompatibleChargeCapacity,
  }) {
    return incompatibleChargeCapacity(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ErrorKey_IncompatibleChargeSize value)?
        incompatibleChargeSize,
    TResult? Function(ErrorKey_IncompatibleChargeCapacity value)?
        incompatibleChargeCapacity,
  }) {
    return incompatibleChargeCapacity?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ErrorKey_IncompatibleChargeSize value)?
        incompatibleChargeSize,
    TResult Function(ErrorKey_IncompatibleChargeCapacity value)?
        incompatibleChargeCapacity,
    required TResult orElse(),
  }) {
    if (incompatibleChargeCapacity != null) {
      return incompatibleChargeCapacity(this);
    }
    return orElse();
  }
}

abstract class ErrorKey_IncompatibleChargeCapacity extends ErrorKey {
  const factory ErrorKey_IncompatibleChargeCapacity(
          {required final double max, required final double actual}) =
      _$ErrorKey_IncompatibleChargeCapacityImpl;
  const ErrorKey_IncompatibleChargeCapacity._() : super._();

  double get max;
  @override
  double get actual;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ErrorKey_IncompatibleChargeCapacityImplCopyWith<
          _$ErrorKey_IncompatibleChargeCapacityImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SlotInfo {
  SlotType get slot => throw _privateConstructorUsedError;
  int get index => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SlotType slot, int index, ErrorKey errorKey)
        error,
    required TResult Function(SlotType slot, int index, WarningKey warningKey)
        warning,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SlotType slot, int index, ErrorKey errorKey)? error,
    TResult? Function(SlotType slot, int index, WarningKey warningKey)? warning,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SlotType slot, int index, ErrorKey errorKey)? error,
    TResult Function(SlotType slot, int index, WarningKey warningKey)? warning,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SlotInfo_Error value) error,
    required TResult Function(SlotInfo_Warning value) warning,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SlotInfo_Error value)? error,
    TResult? Function(SlotInfo_Warning value)? warning,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SlotInfo_Error value)? error,
    TResult Function(SlotInfo_Warning value)? warning,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SlotInfoCopyWith<SlotInfo> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SlotInfoCopyWith<$Res> {
  factory $SlotInfoCopyWith(SlotInfo value, $Res Function(SlotInfo) then) =
      _$SlotInfoCopyWithImpl<$Res, SlotInfo>;
  @useResult
  $Res call({SlotType slot, int index});
}

/// @nodoc
class _$SlotInfoCopyWithImpl<$Res, $Val extends SlotInfo>
    implements $SlotInfoCopyWith<$Res> {
  _$SlotInfoCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? slot = null,
    Object? index = null,
  }) {
    return _then(_value.copyWith(
      slot: null == slot
          ? _value.slot
          : slot // ignore: cast_nullable_to_non_nullable
              as SlotType,
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SlotInfo_ErrorImplCopyWith<$Res>
    implements $SlotInfoCopyWith<$Res> {
  factory _$$SlotInfo_ErrorImplCopyWith(_$SlotInfo_ErrorImpl value,
          $Res Function(_$SlotInfo_ErrorImpl) then) =
      __$$SlotInfo_ErrorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({SlotType slot, int index, ErrorKey errorKey});

  $ErrorKeyCopyWith<$Res> get errorKey;
}

/// @nodoc
class __$$SlotInfo_ErrorImplCopyWithImpl<$Res>
    extends _$SlotInfoCopyWithImpl<$Res, _$SlotInfo_ErrorImpl>
    implements _$$SlotInfo_ErrorImplCopyWith<$Res> {
  __$$SlotInfo_ErrorImplCopyWithImpl(
      _$SlotInfo_ErrorImpl _value, $Res Function(_$SlotInfo_ErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? slot = null,
    Object? index = null,
    Object? errorKey = null,
  }) {
    return _then(_$SlotInfo_ErrorImpl(
      slot: null == slot
          ? _value.slot
          : slot // ignore: cast_nullable_to_non_nullable
              as SlotType,
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
      errorKey: null == errorKey
          ? _value.errorKey
          : errorKey // ignore: cast_nullable_to_non_nullable
              as ErrorKey,
    ));
  }

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ErrorKeyCopyWith<$Res> get errorKey {
    return $ErrorKeyCopyWith<$Res>(_value.errorKey, (value) {
      return _then(_value.copyWith(errorKey: value));
    });
  }
}

/// @nodoc

class _$SlotInfo_ErrorImpl extends SlotInfo_Error {
  const _$SlotInfo_ErrorImpl(
      {required this.slot, required this.index, required this.errorKey})
      : super._();

  @override
  final SlotType slot;
  @override
  final int index;
  @override
  final ErrorKey errorKey;

  @override
  String toString() {
    return 'SlotInfo.error(slot: $slot, index: $index, errorKey: $errorKey)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SlotInfo_ErrorImpl &&
            (identical(other.slot, slot) || other.slot == slot) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.errorKey, errorKey) ||
                other.errorKey == errorKey));
  }

  @override
  int get hashCode => Object.hash(runtimeType, slot, index, errorKey);

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SlotInfo_ErrorImplCopyWith<_$SlotInfo_ErrorImpl> get copyWith =>
      __$$SlotInfo_ErrorImplCopyWithImpl<_$SlotInfo_ErrorImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SlotType slot, int index, ErrorKey errorKey)
        error,
    required TResult Function(SlotType slot, int index, WarningKey warningKey)
        warning,
  }) {
    return error(slot, index, errorKey);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SlotType slot, int index, ErrorKey errorKey)? error,
    TResult? Function(SlotType slot, int index, WarningKey warningKey)? warning,
  }) {
    return error?.call(slot, index, errorKey);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SlotType slot, int index, ErrorKey errorKey)? error,
    TResult Function(SlotType slot, int index, WarningKey warningKey)? warning,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(slot, index, errorKey);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SlotInfo_Error value) error,
    required TResult Function(SlotInfo_Warning value) warning,
  }) {
    return error(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SlotInfo_Error value)? error,
    TResult? Function(SlotInfo_Warning value)? warning,
  }) {
    return error?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SlotInfo_Error value)? error,
    TResult Function(SlotInfo_Warning value)? warning,
    required TResult orElse(),
  }) {
    if (error != null) {
      return error(this);
    }
    return orElse();
  }
}

abstract class SlotInfo_Error extends SlotInfo {
  const factory SlotInfo_Error(
      {required final SlotType slot,
      required final int index,
      required final ErrorKey errorKey}) = _$SlotInfo_ErrorImpl;
  const SlotInfo_Error._() : super._();

  @override
  SlotType get slot;
  @override
  int get index;
  ErrorKey get errorKey;

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SlotInfo_ErrorImplCopyWith<_$SlotInfo_ErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class _$$SlotInfo_WarningImplCopyWith<$Res>
    implements $SlotInfoCopyWith<$Res> {
  factory _$$SlotInfo_WarningImplCopyWith(_$SlotInfo_WarningImpl value,
          $Res Function(_$SlotInfo_WarningImpl) then) =
      __$$SlotInfo_WarningImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({SlotType slot, int index, WarningKey warningKey});
}

/// @nodoc
class __$$SlotInfo_WarningImplCopyWithImpl<$Res>
    extends _$SlotInfoCopyWithImpl<$Res, _$SlotInfo_WarningImpl>
    implements _$$SlotInfo_WarningImplCopyWith<$Res> {
  __$$SlotInfo_WarningImplCopyWithImpl(_$SlotInfo_WarningImpl _value,
      $Res Function(_$SlotInfo_WarningImpl) _then)
      : super(_value, _then);

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? slot = null,
    Object? index = null,
    Object? warningKey = null,
  }) {
    return _then(_$SlotInfo_WarningImpl(
      slot: null == slot
          ? _value.slot
          : slot // ignore: cast_nullable_to_non_nullable
              as SlotType,
      index: null == index
          ? _value.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
      warningKey: null == warningKey
          ? _value.warningKey
          : warningKey // ignore: cast_nullable_to_non_nullable
              as WarningKey,
    ));
  }
}

/// @nodoc

class _$SlotInfo_WarningImpl extends SlotInfo_Warning {
  const _$SlotInfo_WarningImpl(
      {required this.slot, required this.index, required this.warningKey})
      : super._();

  @override
  final SlotType slot;
  @override
  final int index;
  @override
  final WarningKey warningKey;

  @override
  String toString() {
    return 'SlotInfo.warning(slot: $slot, index: $index, warningKey: $warningKey)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SlotInfo_WarningImpl &&
            (identical(other.slot, slot) || other.slot == slot) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.warningKey, warningKey) ||
                other.warningKey == warningKey));
  }

  @override
  int get hashCode => Object.hash(runtimeType, slot, index, warningKey);

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SlotInfo_WarningImplCopyWith<_$SlotInfo_WarningImpl> get copyWith =>
      __$$SlotInfo_WarningImplCopyWithImpl<_$SlotInfo_WarningImpl>(
          this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(SlotType slot, int index, ErrorKey errorKey)
        error,
    required TResult Function(SlotType slot, int index, WarningKey warningKey)
        warning,
  }) {
    return warning(slot, index, warningKey);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(SlotType slot, int index, ErrorKey errorKey)? error,
    TResult? Function(SlotType slot, int index, WarningKey warningKey)? warning,
  }) {
    return warning?.call(slot, index, warningKey);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(SlotType slot, int index, ErrorKey errorKey)? error,
    TResult Function(SlotType slot, int index, WarningKey warningKey)? warning,
    required TResult orElse(),
  }) {
    if (warning != null) {
      return warning(slot, index, warningKey);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(SlotInfo_Error value) error,
    required TResult Function(SlotInfo_Warning value) warning,
  }) {
    return warning(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(SlotInfo_Error value)? error,
    TResult? Function(SlotInfo_Warning value)? warning,
  }) {
    return warning?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(SlotInfo_Error value)? error,
    TResult Function(SlotInfo_Warning value)? warning,
    required TResult orElse(),
  }) {
    if (warning != null) {
      return warning(this);
    }
    return orElse();
  }
}

abstract class SlotInfo_Warning extends SlotInfo {
  const factory SlotInfo_Warning(
      {required final SlotType slot,
      required final int index,
      required final WarningKey warningKey}) = _$SlotInfo_WarningImpl;
  const SlotInfo_Warning._() : super._();

  @override
  SlotType get slot;
  @override
  int get index;
  WarningKey get warningKey;

  /// Create a copy of SlotInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SlotInfo_WarningImplCopyWith<_$SlotInfo_WarningImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
