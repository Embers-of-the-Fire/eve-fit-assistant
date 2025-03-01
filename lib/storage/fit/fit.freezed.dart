// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SlotItem {
  int get itemID;
  bool get isDynamic;
  int? get chargeID;
  SlotState get state;

  /// Create a copy of SlotItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SlotItemCopyWith<SlotItem> get copyWith =>
      _$SlotItemCopyWithImpl<SlotItem>(this as SlotItem, _$identity);

  /// Serializes this SlotItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SlotItem &&
            (identical(other.itemID, itemID) || other.itemID == itemID) &&
            (identical(other.isDynamic, isDynamic) ||
                other.isDynamic == isDynamic) &&
            (identical(other.chargeID, chargeID) ||
                other.chargeID == chargeID) &&
            (identical(other.state, state) || other.state == state));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, itemID, isDynamic, chargeID, state);

  @override
  String toString() {
    return 'SlotItem(itemID: $itemID, isDynamic: $isDynamic, chargeID: $chargeID, state: $state)';
  }
}

/// @nodoc
abstract mixin class $SlotItemCopyWith<$Res> {
  factory $SlotItemCopyWith(SlotItem value, $Res Function(SlotItem) _then) =
      _$SlotItemCopyWithImpl;
  @useResult
  $Res call({int itemID, bool isDynamic, int? chargeID, SlotState state});
}

/// @nodoc
class _$SlotItemCopyWithImpl<$Res> implements $SlotItemCopyWith<$Res> {
  _$SlotItemCopyWithImpl(this._self, this._then);

  final SlotItem _self;
  final $Res Function(SlotItem) _then;

  /// Create a copy of SlotItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? itemID = null,
    Object? isDynamic = null,
    Object? chargeID = freezed,
    Object? state = null,
  }) {
    return _then(_self.copyWith(
      itemID: null == itemID
          ? _self.itemID
          : itemID // ignore: cast_nullable_to_non_nullable
              as int,
      isDynamic: null == isDynamic
          ? _self.isDynamic
          : isDynamic // ignore: cast_nullable_to_non_nullable
              as bool,
      chargeID: freezed == chargeID
          ? _self.chargeID
          : chargeID // ignore: cast_nullable_to_non_nullable
              as int?,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as SlotState,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _SlotItem implements SlotItem {
  const _SlotItem(
      {required this.itemID,
      this.isDynamic = false,
      required this.chargeID,
      required this.state});
  factory _SlotItem.fromJson(Map<String, dynamic> json) =>
      _$SlotItemFromJson(json);

  @override
  final int itemID;
  @override
  @JsonKey()
  final bool isDynamic;
  @override
  final int? chargeID;
  @override
  final SlotState state;

  /// Create a copy of SlotItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SlotItemCopyWith<_SlotItem> get copyWith =>
      __$SlotItemCopyWithImpl<_SlotItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SlotItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SlotItem &&
            (identical(other.itemID, itemID) || other.itemID == itemID) &&
            (identical(other.isDynamic, isDynamic) ||
                other.isDynamic == isDynamic) &&
            (identical(other.chargeID, chargeID) ||
                other.chargeID == chargeID) &&
            (identical(other.state, state) || other.state == state));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, itemID, isDynamic, chargeID, state);

  @override
  String toString() {
    return 'SlotItem(itemID: $itemID, isDynamic: $isDynamic, chargeID: $chargeID, state: $state)';
  }
}

/// @nodoc
abstract mixin class _$SlotItemCopyWith<$Res>
    implements $SlotItemCopyWith<$Res> {
  factory _$SlotItemCopyWith(_SlotItem value, $Res Function(_SlotItem) _then) =
      __$SlotItemCopyWithImpl;
  @override
  @useResult
  $Res call({int itemID, bool isDynamic, int? chargeID, SlotState state});
}

/// @nodoc
class __$SlotItemCopyWithImpl<$Res> implements _$SlotItemCopyWith<$Res> {
  __$SlotItemCopyWithImpl(this._self, this._then);

  final _SlotItem _self;
  final $Res Function(_SlotItem) _then;

  /// Create a copy of SlotItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? itemID = null,
    Object? isDynamic = null,
    Object? chargeID = freezed,
    Object? state = null,
  }) {
    return _then(_SlotItem(
      itemID: null == itemID
          ? _self.itemID
          : itemID // ignore: cast_nullable_to_non_nullable
              as int,
      isDynamic: null == isDynamic
          ? _self.isDynamic
          : isDynamic // ignore: cast_nullable_to_non_nullable
              as bool,
      chargeID: freezed == chargeID
          ? _self.chargeID
          : chargeID // ignore: cast_nullable_to_non_nullable
              as int?,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as SlotState,
    ));
  }
}

/// @nodoc
mixin _$DroneItem {
  int get itemID;
  int get amount;
  DroneState get state;

  /// Create a copy of DroneItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DroneItemCopyWith<DroneItem> get copyWith =>
      _$DroneItemCopyWithImpl<DroneItem>(this as DroneItem, _$identity);

  /// Serializes this DroneItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DroneItem &&
            (identical(other.itemID, itemID) || other.itemID == itemID) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.state, state) || other.state == state));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, itemID, amount, state);

  @override
  String toString() {
    return 'DroneItem(itemID: $itemID, amount: $amount, state: $state)';
  }
}

/// @nodoc
abstract mixin class $DroneItemCopyWith<$Res> {
  factory $DroneItemCopyWith(DroneItem value, $Res Function(DroneItem) _then) =
      _$DroneItemCopyWithImpl;
  @useResult
  $Res call({int itemID, int amount, DroneState state});
}

/// @nodoc
class _$DroneItemCopyWithImpl<$Res> implements $DroneItemCopyWith<$Res> {
  _$DroneItemCopyWithImpl(this._self, this._then);

  final DroneItem _self;
  final $Res Function(DroneItem) _then;

  /// Create a copy of DroneItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? itemID = null,
    Object? amount = null,
    Object? state = null,
  }) {
    return _then(_self.copyWith(
      itemID: null == itemID
          ? _self.itemID
          : itemID // ignore: cast_nullable_to_non_nullable
              as int,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as DroneState,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _DroneItem implements DroneItem {
  const _DroneItem(
      {required this.itemID, required this.amount, required this.state});
  factory _DroneItem.fromJson(Map<String, dynamic> json) =>
      _$DroneItemFromJson(json);

  @override
  final int itemID;
  @override
  final int amount;
  @override
  final DroneState state;

  /// Create a copy of DroneItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DroneItemCopyWith<_DroneItem> get copyWith =>
      __$DroneItemCopyWithImpl<_DroneItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DroneItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DroneItem &&
            (identical(other.itemID, itemID) || other.itemID == itemID) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.state, state) || other.state == state));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, itemID, amount, state);

  @override
  String toString() {
    return 'DroneItem(itemID: $itemID, amount: $amount, state: $state)';
  }
}

/// @nodoc
abstract mixin class _$DroneItemCopyWith<$Res>
    implements $DroneItemCopyWith<$Res> {
  factory _$DroneItemCopyWith(
          _DroneItem value, $Res Function(_DroneItem) _then) =
      __$DroneItemCopyWithImpl;
  @override
  @useResult
  $Res call({int itemID, int amount, DroneState state});
}

/// @nodoc
class __$DroneItemCopyWithImpl<$Res> implements _$DroneItemCopyWith<$Res> {
  __$DroneItemCopyWithImpl(this._self, this._then);

  final _DroneItem _self;
  final $Res Function(_DroneItem) _then;

  /// Create a copy of DroneItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? itemID = null,
    Object? amount = null,
    Object? state = null,
  }) {
    return _then(_DroneItem(
      itemID: null == itemID
          ? _self.itemID
          : itemID // ignore: cast_nullable_to_non_nullable
              as int,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as DroneState,
    ));
  }
}

/// @nodoc
mixin _$FighterItem {
  int get itemID;
  int get amount;
  int get ability;
  DroneState get state;

  /// Create a copy of FighterItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FighterItemCopyWith<FighterItem> get copyWith =>
      _$FighterItemCopyWithImpl<FighterItem>(this as FighterItem, _$identity);

  /// Serializes this FighterItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FighterItem &&
            (identical(other.itemID, itemID) || other.itemID == itemID) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.ability, ability) || other.ability == ability) &&
            (identical(other.state, state) || other.state == state));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, itemID, amount, ability, state);

  @override
  String toString() {
    return 'FighterItem(itemID: $itemID, amount: $amount, ability: $ability, state: $state)';
  }
}

/// @nodoc
abstract mixin class $FighterItemCopyWith<$Res> {
  factory $FighterItemCopyWith(
          FighterItem value, $Res Function(FighterItem) _then) =
      _$FighterItemCopyWithImpl;
  @useResult
  $Res call({int itemID, int amount, int ability, DroneState state});
}

/// @nodoc
class _$FighterItemCopyWithImpl<$Res> implements $FighterItemCopyWith<$Res> {
  _$FighterItemCopyWithImpl(this._self, this._then);

  final FighterItem _self;
  final $Res Function(FighterItem) _then;

  /// Create a copy of FighterItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? itemID = null,
    Object? amount = null,
    Object? ability = null,
    Object? state = null,
  }) {
    return _then(_self.copyWith(
      itemID: null == itemID
          ? _self.itemID
          : itemID // ignore: cast_nullable_to_non_nullable
              as int,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      ability: null == ability
          ? _self.ability
          : ability // ignore: cast_nullable_to_non_nullable
              as int,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as DroneState,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _FighterItem implements FighterItem {
  const _FighterItem(
      {required this.itemID,
      required this.amount,
      required this.ability,
      required this.state});
  factory _FighterItem.fromJson(Map<String, dynamic> json) =>
      _$FighterItemFromJson(json);

  @override
  final int itemID;
  @override
  final int amount;
  @override
  final int ability;
  @override
  final DroneState state;

  /// Create a copy of FighterItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FighterItemCopyWith<_FighterItem> get copyWith =>
      __$FighterItemCopyWithImpl<_FighterItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FighterItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FighterItem &&
            (identical(other.itemID, itemID) || other.itemID == itemID) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.ability, ability) || other.ability == ability) &&
            (identical(other.state, state) || other.state == state));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, itemID, amount, ability, state);

  @override
  String toString() {
    return 'FighterItem(itemID: $itemID, amount: $amount, ability: $ability, state: $state)';
  }
}

/// @nodoc
abstract mixin class _$FighterItemCopyWith<$Res>
    implements $FighterItemCopyWith<$Res> {
  factory _$FighterItemCopyWith(
          _FighterItem value, $Res Function(_FighterItem) _then) =
      __$FighterItemCopyWithImpl;
  @override
  @useResult
  $Res call({int itemID, int amount, int ability, DroneState state});
}

/// @nodoc
class __$FighterItemCopyWithImpl<$Res> implements _$FighterItemCopyWith<$Res> {
  __$FighterItemCopyWithImpl(this._self, this._then);

  final _FighterItem _self;
  final $Res Function(_FighterItem) _then;

  /// Create a copy of FighterItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? itemID = null,
    Object? amount = null,
    Object? ability = null,
    Object? state = null,
  }) {
    return _then(_FighterItem(
      itemID: null == itemID
          ? _self.itemID
          : itemID // ignore: cast_nullable_to_non_nullable
              as int,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      ability: null == ability
          ? _self.ability
          : ability // ignore: cast_nullable_to_non_nullable
              as int,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as DroneState,
    ));
  }
}

/// @nodoc
mixin _$DynamicItem {
  int get mutaplasmidID;
  int get baseType;
  int get outType;
  Map<int, double> get dynamicAttributes;

  /// Create a copy of DynamicItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DynamicItemCopyWith<DynamicItem> get copyWith =>
      _$DynamicItemCopyWithImpl<DynamicItem>(this as DynamicItem, _$identity);

  /// Serializes this DynamicItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DynamicItem &&
            (identical(other.mutaplasmidID, mutaplasmidID) ||
                other.mutaplasmidID == mutaplasmidID) &&
            (identical(other.baseType, baseType) ||
                other.baseType == baseType) &&
            (identical(other.outType, outType) || other.outType == outType) &&
            const DeepCollectionEquality()
                .equals(other.dynamicAttributes, dynamicAttributes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, mutaplasmidID, baseType, outType,
      const DeepCollectionEquality().hash(dynamicAttributes));

  @override
  String toString() {
    return 'DynamicItem(mutaplasmidID: $mutaplasmidID, baseType: $baseType, outType: $outType, dynamicAttributes: $dynamicAttributes)';
  }
}

/// @nodoc
abstract mixin class $DynamicItemCopyWith<$Res> {
  factory $DynamicItemCopyWith(
          DynamicItem value, $Res Function(DynamicItem) _then) =
      _$DynamicItemCopyWithImpl;
  @useResult
  $Res call(
      {int mutaplasmidID,
      int baseType,
      int outType,
      Map<int, double> dynamicAttributes});
}

/// @nodoc
class _$DynamicItemCopyWithImpl<$Res> implements $DynamicItemCopyWith<$Res> {
  _$DynamicItemCopyWithImpl(this._self, this._then);

  final DynamicItem _self;
  final $Res Function(DynamicItem) _then;

  /// Create a copy of DynamicItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mutaplasmidID = null,
    Object? baseType = null,
    Object? outType = null,
    Object? dynamicAttributes = null,
  }) {
    return _then(_self.copyWith(
      mutaplasmidID: null == mutaplasmidID
          ? _self.mutaplasmidID
          : mutaplasmidID // ignore: cast_nullable_to_non_nullable
              as int,
      baseType: null == baseType
          ? _self.baseType
          : baseType // ignore: cast_nullable_to_non_nullable
              as int,
      outType: null == outType
          ? _self.outType
          : outType // ignore: cast_nullable_to_non_nullable
              as int,
      dynamicAttributes: null == dynamicAttributes
          ? _self.dynamicAttributes
          : dynamicAttributes // ignore: cast_nullable_to_non_nullable
              as Map<int, double>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _DynamicItem implements DynamicItem {
  const _DynamicItem(
      {required this.mutaplasmidID,
      required this.baseType,
      required this.outType,
      required final Map<int, double> dynamicAttributes})
      : _dynamicAttributes = dynamicAttributes;
  factory _DynamicItem.fromJson(Map<String, dynamic> json) =>
      _$DynamicItemFromJson(json);

  @override
  final int mutaplasmidID;
  @override
  final int baseType;
  @override
  final int outType;
  final Map<int, double> _dynamicAttributes;
  @override
  Map<int, double> get dynamicAttributes {
    if (_dynamicAttributes is EqualUnmodifiableMapView)
      return _dynamicAttributes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_dynamicAttributes);
  }

  /// Create a copy of DynamicItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DynamicItemCopyWith<_DynamicItem> get copyWith =>
      __$DynamicItemCopyWithImpl<_DynamicItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DynamicItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DynamicItem &&
            (identical(other.mutaplasmidID, mutaplasmidID) ||
                other.mutaplasmidID == mutaplasmidID) &&
            (identical(other.baseType, baseType) ||
                other.baseType == baseType) &&
            (identical(other.outType, outType) || other.outType == outType) &&
            const DeepCollectionEquality()
                .equals(other._dynamicAttributes, _dynamicAttributes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, mutaplasmidID, baseType, outType,
      const DeepCollectionEquality().hash(_dynamicAttributes));

  @override
  String toString() {
    return 'DynamicItem(mutaplasmidID: $mutaplasmidID, baseType: $baseType, outType: $outType, dynamicAttributes: $dynamicAttributes)';
  }
}

/// @nodoc
abstract mixin class _$DynamicItemCopyWith<$Res>
    implements $DynamicItemCopyWith<$Res> {
  factory _$DynamicItemCopyWith(
          _DynamicItem value, $Res Function(_DynamicItem) _then) =
      __$DynamicItemCopyWithImpl;
  @override
  @useResult
  $Res call(
      {int mutaplasmidID,
      int baseType,
      int outType,
      Map<int, double> dynamicAttributes});
}

/// @nodoc
class __$DynamicItemCopyWithImpl<$Res> implements _$DynamicItemCopyWith<$Res> {
  __$DynamicItemCopyWithImpl(this._self, this._then);

  final _DynamicItem _self;
  final $Res Function(_DynamicItem) _then;

  /// Create a copy of DynamicItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? mutaplasmidID = null,
    Object? baseType = null,
    Object? outType = null,
    Object? dynamicAttributes = null,
  }) {
    return _then(_DynamicItem(
      mutaplasmidID: null == mutaplasmidID
          ? _self.mutaplasmidID
          : mutaplasmidID // ignore: cast_nullable_to_non_nullable
              as int,
      baseType: null == baseType
          ? _self.baseType
          : baseType // ignore: cast_nullable_to_non_nullable
              as int,
      outType: null == outType
          ? _self.outType
          : outType // ignore: cast_nullable_to_non_nullable
              as int,
      dynamicAttributes: null == dynamicAttributes
          ? _self._dynamicAttributes
          : dynamicAttributes // ignore: cast_nullable_to_non_nullable
              as Map<int, double>,
    ));
  }
}

// dart format on
