// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fittings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Fitting {
  @JsonKey(name: 'fitting_id')
  int get fittingID;
  @JsonKey(name: 'ship_type_id')
  int get shipTypeID;
  String get name;
  String get description;
  List<FittingItem> get items;

  /// Create a copy of Fitting
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FittingCopyWith<Fitting> get copyWith =>
      _$FittingCopyWithImpl<Fitting>(this as Fitting, _$identity);

  /// Serializes this Fitting to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is Fitting &&
            (identical(other.fittingID, fittingID) ||
                other.fittingID == fittingID) &&
            (identical(other.shipTypeID, shipTypeID) ||
                other.shipTypeID == shipTypeID) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other.items, items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, fittingID, shipTypeID, name,
      description, const DeepCollectionEquality().hash(items));

  @override
  String toString() {
    return 'Fitting(fittingID: $fittingID, shipTypeID: $shipTypeID, name: $name, description: $description, items: $items)';
  }
}

/// @nodoc
abstract mixin class $FittingCopyWith<$Res> {
  factory $FittingCopyWith(Fitting value, $Res Function(Fitting) _then) =
      _$FittingCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'fitting_id') int fittingID,
      @JsonKey(name: 'ship_type_id') int shipTypeID,
      String name,
      String description,
      List<FittingItem> items});
}

/// @nodoc
class _$FittingCopyWithImpl<$Res> implements $FittingCopyWith<$Res> {
  _$FittingCopyWithImpl(this._self, this._then);

  final Fitting _self;
  final $Res Function(Fitting) _then;

  /// Create a copy of Fitting
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? fittingID = null,
    Object? shipTypeID = null,
    Object? name = null,
    Object? description = null,
    Object? items = null,
  }) {
    return _then(_self.copyWith(
      fittingID: null == fittingID
          ? _self.fittingID
          : fittingID // ignore: cast_nullable_to_non_nullable
              as int,
      shipTypeID: null == shipTypeID
          ? _self.shipTypeID
          : shipTypeID // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FittingItem>,
    ));
  }
}

/// @nodoc

@JsonSerializable()
class _Fitting extends Fitting {
  const _Fitting(
      {@JsonKey(name: 'fitting_id') required this.fittingID,
      @JsonKey(name: 'ship_type_id') required this.shipTypeID,
      required this.name,
      required this.description,
      required final List<FittingItem> items})
      : _items = items,
        super._();
  factory _Fitting.fromJson(Map<String, dynamic> json) =>
      _$FittingFromJson(json);

  @override
  @JsonKey(name: 'fitting_id')
  final int fittingID;
  @override
  @JsonKey(name: 'ship_type_id')
  final int shipTypeID;
  @override
  final String name;
  @override
  final String description;
  final List<FittingItem> _items;
  @override
  List<FittingItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  /// Create a copy of Fitting
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FittingCopyWith<_Fitting> get copyWith =>
      __$FittingCopyWithImpl<_Fitting>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FittingToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Fitting &&
            (identical(other.fittingID, fittingID) ||
                other.fittingID == fittingID) &&
            (identical(other.shipTypeID, shipTypeID) ||
                other.shipTypeID == shipTypeID) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, fittingID, shipTypeID, name,
      description, const DeepCollectionEquality().hash(_items));

  @override
  String toString() {
    return 'Fitting(fittingID: $fittingID, shipTypeID: $shipTypeID, name: $name, description: $description, items: $items)';
  }
}

/// @nodoc
abstract mixin class _$FittingCopyWith<$Res> implements $FittingCopyWith<$Res> {
  factory _$FittingCopyWith(_Fitting value, $Res Function(_Fitting) _then) =
      __$FittingCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'fitting_id') int fittingID,
      @JsonKey(name: 'ship_type_id') int shipTypeID,
      String name,
      String description,
      List<FittingItem> items});
}

/// @nodoc
class __$FittingCopyWithImpl<$Res> implements _$FittingCopyWith<$Res> {
  __$FittingCopyWithImpl(this._self, this._then);

  final _Fitting _self;
  final $Res Function(_Fitting) _then;

  /// Create a copy of Fitting
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? fittingID = null,
    Object? shipTypeID = null,
    Object? name = null,
    Object? description = null,
    Object? items = null,
  }) {
    return _then(_Fitting(
      fittingID: null == fittingID
          ? _self.fittingID
          : fittingID // ignore: cast_nullable_to_non_nullable
              as int,
      shipTypeID: null == shipTypeID
          ? _self.shipTypeID
          : shipTypeID // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FittingItem>,
    ));
  }
}

/// @nodoc
mixin _$FittingPost {
  @JsonKey(name: 'ship_type_id')
  int get shipTypeID;
  String get name;
  String get description;
  List<FittingItem> get items;

  /// Create a copy of FittingPost
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FittingPostCopyWith<FittingPost> get copyWith =>
      _$FittingPostCopyWithImpl<FittingPost>(this as FittingPost, _$identity);

  /// Serializes this FittingPost to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FittingPost &&
            (identical(other.shipTypeID, shipTypeID) ||
                other.shipTypeID == shipTypeID) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other.items, items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, shipTypeID, name, description,
      const DeepCollectionEquality().hash(items));

  @override
  String toString() {
    return 'FittingPost(shipTypeID: $shipTypeID, name: $name, description: $description, items: $items)';
  }
}

/// @nodoc
abstract mixin class $FittingPostCopyWith<$Res> {
  factory $FittingPostCopyWith(
          FittingPost value, $Res Function(FittingPost) _then) =
      _$FittingPostCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'ship_type_id') int shipTypeID,
      String name,
      String description,
      List<FittingItem> items});
}

/// @nodoc
class _$FittingPostCopyWithImpl<$Res> implements $FittingPostCopyWith<$Res> {
  _$FittingPostCopyWithImpl(this._self, this._then);

  final FittingPost _self;
  final $Res Function(FittingPost) _then;

  /// Create a copy of FittingPost
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? shipTypeID = null,
    Object? name = null,
    Object? description = null,
    Object? items = null,
  }) {
    return _then(_self.copyWith(
      shipTypeID: null == shipTypeID
          ? _self.shipTypeID
          : shipTypeID // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FittingItem>,
    ));
  }
}

/// @nodoc

@JsonSerializable()
class _FittingPost extends FittingPost {
  const _FittingPost(
      {@JsonKey(name: 'ship_type_id') required this.shipTypeID,
      required this.name,
      required this.description,
      required final List<FittingItem> items})
      : _items = items,
        super._();
  factory _FittingPost.fromJson(Map<String, dynamic> json) =>
      _$FittingPostFromJson(json);

  @override
  @JsonKey(name: 'ship_type_id')
  final int shipTypeID;
  @override
  final String name;
  @override
  final String description;
  final List<FittingItem> _items;
  @override
  List<FittingItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  /// Create a copy of FittingPost
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FittingPostCopyWith<_FittingPost> get copyWith =>
      __$FittingPostCopyWithImpl<_FittingPost>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FittingPostToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FittingPost &&
            (identical(other.shipTypeID, shipTypeID) ||
                other.shipTypeID == shipTypeID) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, shipTypeID, name, description,
      const DeepCollectionEquality().hash(_items));

  @override
  String toString() {
    return 'FittingPost(shipTypeID: $shipTypeID, name: $name, description: $description, items: $items)';
  }
}

/// @nodoc
abstract mixin class _$FittingPostCopyWith<$Res>
    implements $FittingPostCopyWith<$Res> {
  factory _$FittingPostCopyWith(
          _FittingPost value, $Res Function(_FittingPost) _then) =
      __$FittingPostCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'ship_type_id') int shipTypeID,
      String name,
      String description,
      List<FittingItem> items});
}

/// @nodoc
class __$FittingPostCopyWithImpl<$Res> implements _$FittingPostCopyWith<$Res> {
  __$FittingPostCopyWithImpl(this._self, this._then);

  final _FittingPost _self;
  final $Res Function(_FittingPost) _then;

  /// Create a copy of FittingPost
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? shipTypeID = null,
    Object? name = null,
    Object? description = null,
    Object? items = null,
  }) {
    return _then(_FittingPost(
      shipTypeID: null == shipTypeID
          ? _self.shipTypeID
          : shipTypeID // ignore: cast_nullable_to_non_nullable
              as int,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<FittingItem>,
    ));
  }
}

/// @nodoc
mixin _$FittingItem {
  @JsonKey(name: 'type_id')
  int get typeID;
  int get quantity;
  @JsonKey(fromJson: FittingItemFlag.fromJson, toJson: FittingItemFlag.toJson)
  FittingItemFlag get flag;

  /// Create a copy of FittingItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FittingItemCopyWith<FittingItem> get copyWith =>
      _$FittingItemCopyWithImpl<FittingItem>(this as FittingItem, _$identity);

  /// Serializes this FittingItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FittingItem &&
            (identical(other.typeID, typeID) || other.typeID == typeID) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.flag, flag) || other.flag == flag));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, typeID, quantity, flag);

  @override
  String toString() {
    return 'FittingItem(typeID: $typeID, quantity: $quantity, flag: $flag)';
  }
}

/// @nodoc
abstract mixin class $FittingItemCopyWith<$Res> {
  factory $FittingItemCopyWith(
          FittingItem value, $Res Function(FittingItem) _then) =
      _$FittingItemCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(name: 'type_id') int typeID,
      int quantity,
      @JsonKey(
          fromJson: FittingItemFlag.fromJson, toJson: FittingItemFlag.toJson)
      FittingItemFlag flag});
}

/// @nodoc
class _$FittingItemCopyWithImpl<$Res> implements $FittingItemCopyWith<$Res> {
  _$FittingItemCopyWithImpl(this._self, this._then);

  final FittingItem _self;
  final $Res Function(FittingItem) _then;

  /// Create a copy of FittingItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? typeID = null,
    Object? quantity = null,
    Object? flag = null,
  }) {
    return _then(_self.copyWith(
      typeID: null == typeID
          ? _self.typeID
          : typeID // ignore: cast_nullable_to_non_nullable
              as int,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      flag: null == flag
          ? _self.flag
          : flag // ignore: cast_nullable_to_non_nullable
              as FittingItemFlag,
    ));
  }
}

/// @nodoc

@JsonSerializable()
class _FittingItem implements FittingItem {
  const _FittingItem(
      {@JsonKey(name: 'type_id') required this.typeID,
      required this.quantity,
      @JsonKey(
          fromJson: FittingItemFlag.fromJson, toJson: FittingItemFlag.toJson)
      required this.flag});
  factory _FittingItem.fromJson(Map<String, dynamic> json) =>
      _$FittingItemFromJson(json);

  @override
  @JsonKey(name: 'type_id')
  final int typeID;
  @override
  final int quantity;
  @override
  @JsonKey(fromJson: FittingItemFlag.fromJson, toJson: FittingItemFlag.toJson)
  final FittingItemFlag flag;

  /// Create a copy of FittingItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FittingItemCopyWith<_FittingItem> get copyWith =>
      __$FittingItemCopyWithImpl<_FittingItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FittingItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FittingItem &&
            (identical(other.typeID, typeID) || other.typeID == typeID) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.flag, flag) || other.flag == flag));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, typeID, quantity, flag);

  @override
  String toString() {
    return 'FittingItem(typeID: $typeID, quantity: $quantity, flag: $flag)';
  }
}

/// @nodoc
abstract mixin class _$FittingItemCopyWith<$Res>
    implements $FittingItemCopyWith<$Res> {
  factory _$FittingItemCopyWith(
          _FittingItem value, $Res Function(_FittingItem) _then) =
      __$FittingItemCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(name: 'type_id') int typeID,
      int quantity,
      @JsonKey(
          fromJson: FittingItemFlag.fromJson, toJson: FittingItemFlag.toJson)
      FittingItemFlag flag});
}

/// @nodoc
class __$FittingItemCopyWithImpl<$Res> implements _$FittingItemCopyWith<$Res> {
  __$FittingItemCopyWithImpl(this._self, this._then);

  final _FittingItem _self;
  final $Res Function(_FittingItem) _then;

  /// Create a copy of FittingItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? typeID = null,
    Object? quantity = null,
    Object? flag = null,
  }) {
    return _then(_FittingItem(
      typeID: null == typeID
          ? _self.typeID
          : typeID // ignore: cast_nullable_to_non_nullable
              as int,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      flag: null == flag
          ? _self.flag
          : flag // ignore: cast_nullable_to_non_nullable
              as FittingItemFlag,
    ));
  }
}

// dart format on
