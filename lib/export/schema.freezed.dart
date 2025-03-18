// dart format width=80
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schema.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FitExport {
  String get name;
  String get description;
  int get shipID;
  DamageProfile get damageProfile;
  List<SlotItem?> get high;
  List<SlotItem?> get med;
  List<SlotItem?> get low;
  List<SlotItem?> get rig;
  List<SlotItem?> get subSystem;
  @JsonKey(defaultValue: [])
  List<DroneItem> get drone;
  @JsonKey(defaultValue: [])
  List<FighterItem> get fighter;
  @JsonKey(defaultValue: [])
  List<SlotItem?> get implant;
  @JsonKey(defaultValue: [])
  List<SlotItem> get booster;
  @JsonKey(defaultValue: {})
  Map<int, DynamicItem> get dynamicItems;
  int? get tacticalModeID;

  /// Create a copy of FitExport
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FitExportCopyWith<FitExport> get copyWith =>
      _$FitExportCopyWithImpl<FitExport>(this as FitExport, _$identity);

  /// Serializes this FitExport to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FitExport &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.shipID, shipID) || other.shipID == shipID) &&
            (identical(other.damageProfile, damageProfile) ||
                other.damageProfile == damageProfile) &&
            const DeepCollectionEquality().equals(other.high, high) &&
            const DeepCollectionEquality().equals(other.med, med) &&
            const DeepCollectionEquality().equals(other.low, low) &&
            const DeepCollectionEquality().equals(other.rig, rig) &&
            const DeepCollectionEquality().equals(other.subSystem, subSystem) &&
            const DeepCollectionEquality().equals(other.drone, drone) &&
            const DeepCollectionEquality().equals(other.fighter, fighter) &&
            const DeepCollectionEquality().equals(other.implant, implant) &&
            const DeepCollectionEquality().equals(other.booster, booster) &&
            const DeepCollectionEquality()
                .equals(other.dynamicItems, dynamicItems) &&
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
      const DeepCollectionEquality().hash(high),
      const DeepCollectionEquality().hash(med),
      const DeepCollectionEquality().hash(low),
      const DeepCollectionEquality().hash(rig),
      const DeepCollectionEquality().hash(subSystem),
      const DeepCollectionEquality().hash(drone),
      const DeepCollectionEquality().hash(fighter),
      const DeepCollectionEquality().hash(implant),
      const DeepCollectionEquality().hash(booster),
      const DeepCollectionEquality().hash(dynamicItems),
      tacticalModeID);

  @override
  String toString() {
    return 'FitExport(name: $name, description: $description, shipID: $shipID, damageProfile: $damageProfile, high: $high, med: $med, low: $low, rig: $rig, subSystem: $subSystem, drone: $drone, fighter: $fighter, implant: $implant, booster: $booster, dynamicItems: $dynamicItems, tacticalModeID: $tacticalModeID)';
  }
}

/// @nodoc
abstract mixin class $FitExportCopyWith<$Res> {
  factory $FitExportCopyWith(FitExport value, $Res Function(FitExport) _then) =
      _$FitExportCopyWithImpl;
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
      @JsonKey(defaultValue: []) List<DroneItem> drone,
      @JsonKey(defaultValue: []) List<FighterItem> fighter,
      @JsonKey(defaultValue: []) List<SlotItem?> implant,
      @JsonKey(defaultValue: []) List<SlotItem> booster,
      @JsonKey(defaultValue: {}) Map<int, DynamicItem> dynamicItems,
      int? tacticalModeID});

  $DamageProfileCopyWith<$Res> get damageProfile;
}

/// @nodoc
class _$FitExportCopyWithImpl<$Res> implements $FitExportCopyWith<$Res> {
  _$FitExportCopyWithImpl(this._self, this._then);

  final FitExport _self;
  final $Res Function(FitExport) _then;

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
    Object? booster = null,
    Object? dynamicItems = null,
    Object? tacticalModeID = freezed,
  }) {
    return _then(_self.copyWith(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      shipID: null == shipID
          ? _self.shipID
          : shipID // ignore: cast_nullable_to_non_nullable
              as int,
      damageProfile: null == damageProfile
          ? _self.damageProfile
          : damageProfile // ignore: cast_nullable_to_non_nullable
              as DamageProfile,
      high: null == high
          ? _self.high
          : high // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      med: null == med
          ? _self.med
          : med // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      low: null == low
          ? _self.low
          : low // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      rig: null == rig
          ? _self.rig
          : rig // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      subSystem: null == subSystem
          ? _self.subSystem
          : subSystem // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      drone: null == drone
          ? _self.drone
          : drone // ignore: cast_nullable_to_non_nullable
              as List<DroneItem>,
      fighter: null == fighter
          ? _self.fighter
          : fighter // ignore: cast_nullable_to_non_nullable
              as List<FighterItem>,
      implant: null == implant
          ? _self.implant
          : implant // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      booster: null == booster
          ? _self.booster
          : booster // ignore: cast_nullable_to_non_nullable
              as List<SlotItem>,
      dynamicItems: null == dynamicItems
          ? _self.dynamicItems
          : dynamicItems // ignore: cast_nullable_to_non_nullable
              as Map<int, DynamicItem>,
      tacticalModeID: freezed == tacticalModeID
          ? _self.tacticalModeID
          : tacticalModeID // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }

  /// Create a copy of FitExport
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DamageProfileCopyWith<$Res> get damageProfile {
    return $DamageProfileCopyWith<$Res>(_self.damageProfile, (value) {
      return _then(_self.copyWith(damageProfile: value));
    });
  }
}

/// @nodoc
@JsonSerializable()
class _FitExport extends FitExport {
  const _FitExport(
      {required this.name,
      required this.description,
      required this.shipID,
      required this.damageProfile,
      required final List<SlotItem?> high,
      required final List<SlotItem?> med,
      required final List<SlotItem?> low,
      required final List<SlotItem?> rig,
      required final List<SlotItem?> subSystem,
      @JsonKey(defaultValue: []) required final List<DroneItem> drone,
      @JsonKey(defaultValue: []) required final List<FighterItem> fighter,
      @JsonKey(defaultValue: []) required final List<SlotItem?> implant,
      @JsonKey(defaultValue: []) required final List<SlotItem> booster,
      @JsonKey(defaultValue: {})
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
        _booster = booster,
        _dynamicItems = dynamicItems,
        super._();
  factory _FitExport.fromJson(Map<String, dynamic> json) =>
      _$FitExportFromJson(json);

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
  @JsonKey(defaultValue: [])
  List<DroneItem> get drone {
    if (_drone is EqualUnmodifiableListView) return _drone;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_drone);
  }

  final List<FighterItem> _fighter;
  @override
  @JsonKey(defaultValue: [])
  List<FighterItem> get fighter {
    if (_fighter is EqualUnmodifiableListView) return _fighter;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fighter);
  }

  final List<SlotItem?> _implant;
  @override
  @JsonKey(defaultValue: [])
  List<SlotItem?> get implant {
    if (_implant is EqualUnmodifiableListView) return _implant;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_implant);
  }

  final List<SlotItem> _booster;
  @override
  @JsonKey(defaultValue: [])
  List<SlotItem> get booster {
    if (_booster is EqualUnmodifiableListView) return _booster;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_booster);
  }

  final Map<int, DynamicItem> _dynamicItems;
  @override
  @JsonKey(defaultValue: {})
  Map<int, DynamicItem> get dynamicItems {
    if (_dynamicItems is EqualUnmodifiableMapView) return _dynamicItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_dynamicItems);
  }

  @override
  final int? tacticalModeID;

  /// Create a copy of FitExport
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FitExportCopyWith<_FitExport> get copyWith =>
      __$FitExportCopyWithImpl<_FitExport>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FitExportToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FitExport &&
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
            const DeepCollectionEquality().equals(other._booster, _booster) &&
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
      const DeepCollectionEquality().hash(_booster),
      const DeepCollectionEquality().hash(_dynamicItems),
      tacticalModeID);

  @override
  String toString() {
    return 'FitExport(name: $name, description: $description, shipID: $shipID, damageProfile: $damageProfile, high: $high, med: $med, low: $low, rig: $rig, subSystem: $subSystem, drone: $drone, fighter: $fighter, implant: $implant, booster: $booster, dynamicItems: $dynamicItems, tacticalModeID: $tacticalModeID)';
  }
}

/// @nodoc
abstract mixin class _$FitExportCopyWith<$Res>
    implements $FitExportCopyWith<$Res> {
  factory _$FitExportCopyWith(
          _FitExport value, $Res Function(_FitExport) _then) =
      __$FitExportCopyWithImpl;
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
      @JsonKey(defaultValue: []) List<DroneItem> drone,
      @JsonKey(defaultValue: []) List<FighterItem> fighter,
      @JsonKey(defaultValue: []) List<SlotItem?> implant,
      @JsonKey(defaultValue: []) List<SlotItem> booster,
      @JsonKey(defaultValue: {}) Map<int, DynamicItem> dynamicItems,
      int? tacticalModeID});

  @override
  $DamageProfileCopyWith<$Res> get damageProfile;
}

/// @nodoc
class __$FitExportCopyWithImpl<$Res> implements _$FitExportCopyWith<$Res> {
  __$FitExportCopyWithImpl(this._self, this._then);

  final _FitExport _self;
  final $Res Function(_FitExport) _then;

  /// Create a copy of FitExport
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
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
    Object? booster = null,
    Object? dynamicItems = null,
    Object? tacticalModeID = freezed,
  }) {
    return _then(_FitExport(
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
      shipID: null == shipID
          ? _self.shipID
          : shipID // ignore: cast_nullable_to_non_nullable
              as int,
      damageProfile: null == damageProfile
          ? _self.damageProfile
          : damageProfile // ignore: cast_nullable_to_non_nullable
              as DamageProfile,
      high: null == high
          ? _self._high
          : high // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      med: null == med
          ? _self._med
          : med // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      low: null == low
          ? _self._low
          : low // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      rig: null == rig
          ? _self._rig
          : rig // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      subSystem: null == subSystem
          ? _self._subSystem
          : subSystem // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      drone: null == drone
          ? _self._drone
          : drone // ignore: cast_nullable_to_non_nullable
              as List<DroneItem>,
      fighter: null == fighter
          ? _self._fighter
          : fighter // ignore: cast_nullable_to_non_nullable
              as List<FighterItem>,
      implant: null == implant
          ? _self._implant
          : implant // ignore: cast_nullable_to_non_nullable
              as List<SlotItem?>,
      booster: null == booster
          ? _self._booster
          : booster // ignore: cast_nullable_to_non_nullable
              as List<SlotItem>,
      dynamicItems: null == dynamicItems
          ? _self._dynamicItems
          : dynamicItems // ignore: cast_nullable_to_non_nullable
              as Map<int, DynamicItem>,
      tacticalModeID: freezed == tacticalModeID
          ? _self.tacticalModeID
          : tacticalModeID // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }

  /// Create a copy of FitExport
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DamageProfileCopyWith<$Res> get damageProfile {
    return $DamageProfileCopyWith<$Res>(_self.damageProfile, (value) {
      return _then(_self.copyWith(damageProfile: value));
    });
  }
}

// dart format on
