// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schema.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

FitExport _$FitExportFromJson(Map<String, dynamic> json) {
  return _FitExport.fromJson(json);
}

/// @nodoc
mixin _$FitExport {
  String get name => throw _privateConstructorUsedError;
  String get description => throw _privateConstructorUsedError;
  int get shipID => throw _privateConstructorUsedError;
  DamageProfile get damageProfile => throw _privateConstructorUsedError;
  List<SlotItem?> get high => throw _privateConstructorUsedError;
  List<SlotItem?> get med => throw _privateConstructorUsedError;
  List<SlotItem?> get low => throw _privateConstructorUsedError;
  List<SlotItem?> get rig => throw _privateConstructorUsedError;
  List<SlotItem?> get subSystem => throw _privateConstructorUsedError;
  List<DroneItem> get drone => throw _privateConstructorUsedError;
  List<FighterItem> get fighter => throw _privateConstructorUsedError;
  List<SlotItem?> get implant => throw _privateConstructorUsedError;
  Map<int, DynamicItem> get dynamicItems => throw _privateConstructorUsedError;
  int? get tacticalModeID => throw _privateConstructorUsedError;

  /// Serializes this FitExport to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of FitExport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $FitExportCopyWith<FitExport> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $FitExportCopyWith<$Res> {
  factory $FitExportCopyWith(FitExport value, $Res Function(FitExport) then) =
      _$FitExportCopyWithImpl<$Res, FitExport>;
  @useResult
  $Res call(
      {String name,
      String description,
      int shipID,
      DamageProfile damageProfile,
      List<SlotItem?> high,
      List<SlotItem?> med,
      List<SlotItem?> low,
      List<SlotItem?> rig,
      List<SlotItem?> subSystem,
      List<DroneItem> drone,
      List<FighterItem> fighter,
      List<SlotItem?> implant,
      Map<int, DynamicItem> dynamicItems,
      int? tacticalModeID});

  $DamageProfileCopyWith<$Res> get damageProfile;
}

/// @nodoc
class _$FitExportCopyWithImpl<$Res, $Val extends FitExport>
    implements $FitExportCopyWith<$Res> {
  _$FitExportCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of FitExport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = null,
    Object? shipID = null,
    Object? damageProfile = null,
    Object? high = null,
    Object? med = null,
    Object? low = null,
    Object? rig = null,
    Object? subSystem = null,
    Object? drone = null,
    Object? fighter = null,
    Object? implant = null,
    Object? dynamicItems = null,
    Object? tacticalModeID = freezed,
  }) {
    return _then(_value.copyWith(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      shipID: null == shipID
          ? _value.shipID
          : shipID // ignore: cast_nullable_to_non_nullable
              as int,
      damageProfile: null == damageProfile
          ? _value.damageProfile
          : damageProfile // ignore: cast_nullable_to_non_nullable
              as DamageProfile,
      high: null == high
          ? _value.high
          : high // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      med: null == med
          ? _value.med
          : med // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      low: null == low
          ? _value.low
          : low // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      rig: null == rig
          ? _value.rig
          : rig // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      subSystem: null == subSystem
          ? _value.subSystem
          : subSystem // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      drone: null == drone
          ? _value.drone
          : drone // ignore: cast_nullable_to_non_nullable
              as List<DroneItem>,
      fighter: null == fighter
          ? _value.fighter
          : fighter // ignore: cast_nullable_to_non_nullable
              as List<FighterItem>,
      implant: null == implant
          ? _value.implant
          : implant // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      dynamicItems: null == dynamicItems
          ? _value.dynamicItems
          : dynamicItems // ignore: cast_nullable_to_non_nullable
              as Map<int, DynamicItem>,
      tacticalModeID: freezed == tacticalModeID
          ? _value.tacticalModeID
          : tacticalModeID // ignore: cast_nullable_to_non_nullable
              as int?,
    ) as $Val);
  }

  /// Create a copy of FitExport
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DamageProfileCopyWith<$Res> get damageProfile {
    return $DamageProfileCopyWith<$Res>(_value.damageProfile, (value) {
      return _then(_value.copyWith(damageProfile: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$FitExportImplCopyWith<$Res>
    implements $FitExportCopyWith<$Res> {
  factory _$$FitExportImplCopyWith(
          _$FitExportImpl value, $Res Function(_$FitExportImpl) then) =
      __$$FitExportImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String name,
      String description,
      int shipID,
      DamageProfile damageProfile,
      List<SlotItem?> high,
      List<SlotItem?> med,
      List<SlotItem?> low,
      List<SlotItem?> rig,
      List<SlotItem?> subSystem,
      List<DroneItem> drone,
      List<FighterItem> fighter,
      List<SlotItem?> implant,
      Map<int, DynamicItem> dynamicItems,
      int? tacticalModeID});

  @override
  $DamageProfileCopyWith<$Res> get damageProfile;
}

/// @nodoc
class __$$FitExportImplCopyWithImpl<$Res>
    extends _$FitExportCopyWithImpl<$Res, _$FitExportImpl>
    implements _$$FitExportImplCopyWith<$Res> {
  __$$FitExportImplCopyWithImpl(
      _$FitExportImpl _value, $Res Function(_$FitExportImpl) _then)
      : super(_value, _then);

  /// Create a copy of FitExport
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? name = null,
    Object? description = null,
    Object? shipID = null,
    Object? damageProfile = null,
    Object? high = null,
    Object? med = null,
    Object? low = null,
    Object? rig = null,
    Object? subSystem = null,
    Object? drone = null,
    Object? fighter = null,
    Object? implant = null,
    Object? dynamicItems = null,
    Object? tacticalModeID = freezed,
  }) {
    return _then(_$FitExportImpl(
      name: null == name
          ? _value.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _value.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      shipID: null == shipID
          ? _value.shipID
          : shipID // ignore: cast_nullable_to_non_nullable
              as int,
      damageProfile: null == damageProfile
          ? _value.damageProfile
          : damageProfile // ignore: cast_nullable_to_non_nullable
              as DamageProfile,
      high: null == high
          ? _value._high
          : high // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      med: null == med
          ? _value._med
          : med // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      low: null == low
          ? _value._low
          : low // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      rig: null == rig
          ? _value._rig
          : rig // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      subSystem: null == subSystem
          ? _value._subSystem
          : subSystem // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      drone: null == drone
          ? _value._drone
          : drone // ignore: cast_nullable_to_non_nullable
              as List<DroneItem>,
      fighter: null == fighter
          ? _value._fighter
          : fighter // ignore: cast_nullable_to_non_nullable
              as List<FighterItem>,
      implant: null == implant
          ? _value._implant
          : implant // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      dynamicItems: null == dynamicItems
          ? _value._dynamicItems
          : dynamicItems // ignore: cast_nullable_to_non_nullable
              as Map<int, DynamicItem>,
      tacticalModeID: freezed == tacticalModeID
          ? _value.tacticalModeID
          : tacticalModeID // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$FitExportImpl extends _FitExport {
  const _$FitExportImpl(
      {required this.name,
      required this.description,
      required this.shipID,
      required this.damageProfile,
      required final List<SlotItem?> high,
      required final List<SlotItem?> med,
      required final List<SlotItem?> low,
      required final List<SlotItem?> rig,
      required final List<SlotItem?> subSystem,
      required final List<DroneItem> drone,
      required final List<FighterItem> fighter,
      required final List<SlotItem?> implant,
      required final Map<int, DynamicItem> dynamicItems,
      this.tacticalModeID})
      : _high = high,
        _med = med,
        _low = low,
        _rig = rig,
        _subSystem = subSystem,
        _drone = drone,
        _fighter = fighter,
        _implant = implant,
        _dynamicItems = dynamicItems,
        super._();

  factory _$FitExportImpl.fromJson(Map<String, dynamic> json) =>
      _$$FitExportImplFromJson(json);

  @override
  final String name;
  @override
  final String description;
  @override
  final int shipID;
  @override
  final DamageProfile damageProfile;
  final List<SlotItem?> _high;
  @override
  List<SlotItem?> get high {
    if (_high is EqualUnmodifiableListView) return _high;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_high);
  }

  final List<SlotItem?> _med;
  @override
  List<SlotItem?> get med {
    if (_med is EqualUnmodifiableListView) return _med;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_med);
  }

  final List<SlotItem?> _low;
  @override
  List<SlotItem?> get low {
    if (_low is EqualUnmodifiableListView) return _low;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_low);
  }

  final List<SlotItem?> _rig;
  @override
  List<SlotItem?> get rig {
    if (_rig is EqualUnmodifiableListView) return _rig;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_rig);
  }

  final List<SlotItem?> _subSystem;
  @override
  List<SlotItem?> get subSystem {
    if (_subSystem is EqualUnmodifiableListView) return _subSystem;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_subSystem);
  }

  final List<DroneItem> _drone;
  @override
  List<DroneItem> get drone {
    if (_drone is EqualUnmodifiableListView) return _drone;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_drone);
  }

  final List<FighterItem> _fighter;
  @override
  List<FighterItem> get fighter {
    if (_fighter is EqualUnmodifiableListView) return _fighter;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fighter);
  }

  final List<SlotItem?> _implant;
  @override
  List<SlotItem?> get implant {
    if (_implant is EqualUnmodifiableListView) return _implant;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_implant);
  }

  final Map<int, DynamicItem> _dynamicItems;
  @override
  Map<int, DynamicItem> get dynamicItems {
    if (_dynamicItems is EqualUnmodifiableMapView) return _dynamicItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_dynamicItems);
  }

  @override
  final int? tacticalModeID;

  @override
  String toString() {
    return 'FitExport(name: $name, description: $description, shipID: $shipID, damageProfile: $damageProfile, high: $high, med: $med, low: $low, rig: $rig, subSystem: $subSystem, drone: $drone, fighter: $fighter, implant: $implant, dynamicItems: $dynamicItems, tacticalModeID: $tacticalModeID)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$FitExportImpl &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.shipID, shipID) || other.shipID == shipID) &&
            (identical(other.damageProfile, damageProfile) ||
                other.damageProfile == damageProfile) &&
            const DeepCollectionEquality().equals(other._high, _high) &&
            const DeepCollectionEquality().equals(other._med, _med) &&
            const DeepCollectionEquality().equals(other._low, _low) &&
            const DeepCollectionEquality().equals(other._rig, _rig) &&
            const DeepCollectionEquality()
                .equals(other._subSystem, _subSystem) &&
            const DeepCollectionEquality().equals(other._drone, _drone) &&
            const DeepCollectionEquality().equals(other._fighter, _fighter) &&
            const DeepCollectionEquality().equals(other._implant, _implant) &&
            const DeepCollectionEquality()
                .equals(other._dynamicItems, _dynamicItems) &&
            (identical(other.tacticalModeID, tacticalModeID) ||
                other.tacticalModeID == tacticalModeID));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      name,
      description,
      shipID,
      damageProfile,
      const DeepCollectionEquality().hash(_high),
      const DeepCollectionEquality().hash(_med),
      const DeepCollectionEquality().hash(_low),
      const DeepCollectionEquality().hash(_rig),
      const DeepCollectionEquality().hash(_subSystem),
      const DeepCollectionEquality().hash(_drone),
      const DeepCollectionEquality().hash(_fighter),
      const DeepCollectionEquality().hash(_implant),
      const DeepCollectionEquality().hash(_dynamicItems),
      tacticalModeID);

  /// Create a copy of FitExport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$FitExportImplCopyWith<_$FitExportImpl> get copyWith =>
      __$$FitExportImplCopyWithImpl<_$FitExportImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$FitExportImplToJson(
      this,
    );
  }
}

abstract class _FitExport extends FitExport {
  const factory _FitExport(
      {required final String name,
      required final String description,
      required final int shipID,
      required final DamageProfile damageProfile,
      required final List<SlotItem?> high,
      required final List<SlotItem?> med,
      required final List<SlotItem?> low,
      required final List<SlotItem?> rig,
      required final List<SlotItem?> subSystem,
      required final List<DroneItem> drone,
      required final List<FighterItem> fighter,
      required final List<SlotItem?> implant,
      required final Map<int, DynamicItem> dynamicItems,
      final int? tacticalModeID}) = _$FitExportImpl;
  const _FitExport._() : super._();

  factory _FitExport.fromJson(Map<String, dynamic> json) =
      _$FitExportImpl.fromJson;

  @override
  String get name;
  @override
  String get description;
  @override
  int get shipID;
  @override
  DamageProfile get damageProfile;
  @override
  List<SlotItem?> get high;
  @override
  List<SlotItem?> get med;
  @override
  List<SlotItem?> get low;
  @override
  List<SlotItem?> get rig;
  @override
  List<SlotItem?> get subSystem;
  @override
  List<DroneItem> get drone;
  @override
  List<FighterItem> get fighter;
  @override
  List<SlotItem?> get implant;
  @override
  Map<int, DynamicItem> get dynamicItems;
  @override
  int? get tacticalModeID;

  /// Create a copy of FitExport
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$FitExportImplCopyWith<_$FitExportImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
