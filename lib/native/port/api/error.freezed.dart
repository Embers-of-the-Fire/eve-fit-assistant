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
  int get charge => throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int charge) incompatibleCharge,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int charge)? incompatibleCharge,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int charge)? incompatibleCharge,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ErrorKey_IncompatibleCharge value)
        incompatibleCharge,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ErrorKey_IncompatibleCharge value)? incompatibleCharge,
  }) =>
      throw _privateConstructorUsedError;
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ErrorKey_IncompatibleCharge value)? incompatibleCharge,
    required TResult orElse(),
  }) =>
      throw _privateConstructorUsedError;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ErrorKeyCopyWith<ErrorKey> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ErrorKeyCopyWith<$Res> {
  factory $ErrorKeyCopyWith(ErrorKey value, $Res Function(ErrorKey) then) =
      _$ErrorKeyCopyWithImpl<$Res, ErrorKey>;
  @useResult
  $Res call({int charge});
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
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? charge = null,
  }) {
    return _then(_value.copyWith(
      charge: null == charge
          ? _value.charge
          : charge // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$ErrorKey_IncompatibleChargeImplCopyWith<$Res>
    implements $ErrorKeyCopyWith<$Res> {
  factory _$$ErrorKey_IncompatibleChargeImplCopyWith(
          _$ErrorKey_IncompatibleChargeImpl value,
          $Res Function(_$ErrorKey_IncompatibleChargeImpl) then) =
      __$$ErrorKey_IncompatibleChargeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({int charge});
}

/// @nodoc
class __$$ErrorKey_IncompatibleChargeImplCopyWithImpl<$Res>
    extends _$ErrorKeyCopyWithImpl<$Res, _$ErrorKey_IncompatibleChargeImpl>
    implements _$$ErrorKey_IncompatibleChargeImplCopyWith<$Res> {
  __$$ErrorKey_IncompatibleChargeImplCopyWithImpl(
      _$ErrorKey_IncompatibleChargeImpl _value,
      $Res Function(_$ErrorKey_IncompatibleChargeImpl) _then)
      : super(_value, _then);

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? charge = null,
  }) {
    return _then(_$ErrorKey_IncompatibleChargeImpl(
      charge: null == charge
          ? _value.charge
          : charge // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$ErrorKey_IncompatibleChargeImpl extends ErrorKey_IncompatibleCharge {
  const _$ErrorKey_IncompatibleChargeImpl({required this.charge}) : super._();

  @override
  final int charge;

  @override
  String toString() {
    return 'ErrorKey.incompatibleCharge(charge: $charge)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ErrorKey_IncompatibleChargeImpl &&
            (identical(other.charge, charge) || other.charge == charge));
  }

  @override
  int get hashCode => Object.hash(runtimeType, charge);

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ErrorKey_IncompatibleChargeImplCopyWith<_$ErrorKey_IncompatibleChargeImpl>
      get copyWith => __$$ErrorKey_IncompatibleChargeImplCopyWithImpl<
          _$ErrorKey_IncompatibleChargeImpl>(this, _$identity);

  @override
  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(int charge) incompatibleCharge,
  }) {
    return incompatibleCharge(charge);
  }

  @override
  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(int charge)? incompatibleCharge,
  }) {
    return incompatibleCharge?.call(charge);
  }

  @override
  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(int charge)? incompatibleCharge,
    required TResult orElse(),
  }) {
    if (incompatibleCharge != null) {
      return incompatibleCharge(charge);
    }
    return orElse();
  }

  @override
  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(ErrorKey_IncompatibleCharge value)
        incompatibleCharge,
  }) {
    return incompatibleCharge(this);
  }

  @override
  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(ErrorKey_IncompatibleCharge value)? incompatibleCharge,
  }) {
    return incompatibleCharge?.call(this);
  }

  @override
  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(ErrorKey_IncompatibleCharge value)? incompatibleCharge,
    required TResult orElse(),
  }) {
    if (incompatibleCharge != null) {
      return incompatibleCharge(this);
    }
    return orElse();
  }
}

abstract class ErrorKey_IncompatibleCharge extends ErrorKey {
  const factory ErrorKey_IncompatibleCharge({required final int charge}) =
      _$ErrorKey_IncompatibleChargeImpl;
  const ErrorKey_IncompatibleCharge._() : super._();

  @override
  int get charge;

  /// Create a copy of ErrorKey
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ErrorKey_IncompatibleChargeImplCopyWith<_$ErrorKey_IncompatibleChargeImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$SlotError {
  SlotType get slot => throw _privateConstructorUsedError;
  int get index => throw _privateConstructorUsedError;
  ErrorKey get errorKey => throw _privateConstructorUsedError;

  /// Create a copy of SlotError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SlotErrorCopyWith<SlotError> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SlotErrorCopyWith<$Res> {
  factory $SlotErrorCopyWith(SlotError value, $Res Function(SlotError) then) =
      _$SlotErrorCopyWithImpl<$Res, SlotError>;
  @useResult
  $Res call({SlotType slot, int index, ErrorKey errorKey});

  $ErrorKeyCopyWith<$Res> get errorKey;
}

/// @nodoc
class _$SlotErrorCopyWithImpl<$Res, $Val extends SlotError>
    implements $SlotErrorCopyWith<$Res> {
  _$SlotErrorCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SlotError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? slot = null,
    Object? index = null,
    Object? errorKey = null,
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
      errorKey: null == errorKey
          ? _value.errorKey
          : errorKey // ignore: cast_nullable_to_non_nullable
              as ErrorKey,
    ) as $Val);
  }

  /// Create a copy of SlotError
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ErrorKeyCopyWith<$Res> get errorKey {
    return $ErrorKeyCopyWith<$Res>(_value.errorKey, (value) {
      return _then(_value.copyWith(errorKey: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$SlotErrorImplCopyWith<$Res>
    implements $SlotErrorCopyWith<$Res> {
  factory _$$SlotErrorImplCopyWith(
          _$SlotErrorImpl value, $Res Function(_$SlotErrorImpl) then) =
      __$$SlotErrorImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({SlotType slot, int index, ErrorKey errorKey});

  @override
  $ErrorKeyCopyWith<$Res> get errorKey;
}

/// @nodoc
class __$$SlotErrorImplCopyWithImpl<$Res>
    extends _$SlotErrorCopyWithImpl<$Res, _$SlotErrorImpl>
    implements _$$SlotErrorImplCopyWith<$Res> {
  __$$SlotErrorImplCopyWithImpl(
      _$SlotErrorImpl _value, $Res Function(_$SlotErrorImpl) _then)
      : super(_value, _then);

  /// Create a copy of SlotError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? slot = null,
    Object? index = null,
    Object? errorKey = null,
  }) {
    return _then(_$SlotErrorImpl(
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
}

/// @nodoc

class _$SlotErrorImpl implements _SlotError {
  const _$SlotErrorImpl(
      {required this.slot, required this.index, required this.errorKey});

  @override
  final SlotType slot;
  @override
  final int index;
  @override
  final ErrorKey errorKey;

  @override
  String toString() {
    return 'SlotError(slot: $slot, index: $index, errorKey: $errorKey)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SlotErrorImpl &&
            (identical(other.slot, slot) || other.slot == slot) &&
            (identical(other.index, index) || other.index == index) &&
            (identical(other.errorKey, errorKey) ||
                other.errorKey == errorKey));
  }

  @override
  int get hashCode => Object.hash(runtimeType, slot, index, errorKey);

  /// Create a copy of SlotError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SlotErrorImplCopyWith<_$SlotErrorImpl> get copyWith =>
      __$$SlotErrorImplCopyWithImpl<_$SlotErrorImpl>(this, _$identity);
}

abstract class _SlotError implements SlotError {
  const factory _SlotError(
      {required final SlotType slot,
      required final int index,
      required final ErrorKey errorKey}) = _$SlotErrorImpl;

  @override
  SlotType get slot;
  @override
  int get index;
  @override
  ErrorKey get errorKey;

  /// Create a copy of SlotError
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SlotErrorImplCopyWith<_$SlotErrorImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
