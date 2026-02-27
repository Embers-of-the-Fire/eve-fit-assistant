// This is a generated file - do not edit.
//
// Generated from subsystem.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'i18n.pb.dart' as $0;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// / all subsystems
class ShipSubsystem_Ship extends $pb.GeneratedMessage {
  factory ShipSubsystem_Ship({
    $core.Iterable<$core.int>? offensive,
    $core.int? offensiveMarket,
    $core.Iterable<$core.int>? propulsion,
    $core.int? propulsionMarket,
    $core.Iterable<$core.int>? core,
    $core.int? coreMarket,
    $core.Iterable<$core.int>? defensive,
    $core.int? defensiveMarket,
  }) {
    final result = create();
    if (offensive != null) result.offensive.addAll(offensive);
    if (offensiveMarket != null) result.offensiveMarket = offensiveMarket;
    if (propulsion != null) result.propulsion.addAll(propulsion);
    if (propulsionMarket != null) result.propulsionMarket = propulsionMarket;
    if (core != null) result.core.addAll(core);
    if (coreMarket != null) result.coreMarket = coreMarket;
    if (defensive != null) result.defensive.addAll(defensive);
    if (defensiveMarket != null) result.defensiveMarket = defensiveMarket;
    return result;
  }

  ShipSubsystem_Ship._();

  factory ShipSubsystem_Ship.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ShipSubsystem_Ship.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShipSubsystem.Ship',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'subsystem'),
      createEmptyInstance: create)
    ..p<$core.int>(1, _omitFieldNames ? '' : 'offensive', $pb.PbFieldType.P3)
    ..aI(2, _omitFieldNames ? '' : 'offensiveMarket',
        protoName: 'offensiveMarket', fieldType: $pb.PbFieldType.Q3)
    ..p<$core.int>(3, _omitFieldNames ? '' : 'propulsion', $pb.PbFieldType.P3)
    ..aI(4, _omitFieldNames ? '' : 'propulsionMarket',
        protoName: 'propulsionMarket', fieldType: $pb.PbFieldType.Q3)
    ..p<$core.int>(5, _omitFieldNames ? '' : 'core', $pb.PbFieldType.P3)
    ..aI(6, _omitFieldNames ? '' : 'coreMarket',
        protoName: 'coreMarket', fieldType: $pb.PbFieldType.Q3)
    ..p<$core.int>(7, _omitFieldNames ? '' : 'defensive', $pb.PbFieldType.P3)
    ..aI(8, _omitFieldNames ? '' : 'defensiveMarket',
        protoName: 'defensiveMarket', fieldType: $pb.PbFieldType.Q3);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShipSubsystem_Ship clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShipSubsystem_Ship copyWith(void Function(ShipSubsystem_Ship) updates) =>
      super.copyWith((message) => updates(message as ShipSubsystem_Ship))
          as ShipSubsystem_Ship;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShipSubsystem_Ship create() => ShipSubsystem_Ship._();
  @$core.override
  ShipSubsystem_Ship createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ShipSubsystem_Ship getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShipSubsystem_Ship>(create);
  static ShipSubsystem_Ship? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.int> get offensive => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get offensiveMarket => $_getIZ(1);
  @$pb.TagNumber(2)
  set offensiveMarket($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasOffensiveMarket() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffensiveMarket() => $_clearField(2);

  @$pb.TagNumber(3)
  $pb.PbList<$core.int> get propulsion => $_getList(2);

  @$pb.TagNumber(4)
  $core.int get propulsionMarket => $_getIZ(3);
  @$pb.TagNumber(4)
  set propulsionMarket($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPropulsionMarket() => $_has(3);
  @$pb.TagNumber(4)
  void clearPropulsionMarket() => $_clearField(4);

  @$pb.TagNumber(5)
  $pb.PbList<$core.int> get core => $_getList(4);

  @$pb.TagNumber(6)
  $core.int get coreMarket => $_getIZ(5);
  @$pb.TagNumber(6)
  set coreMarket($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasCoreMarket() => $_has(5);
  @$pb.TagNumber(6)
  void clearCoreMarket() => $_clearField(6);

  @$pb.TagNumber(7)
  $pb.PbList<$core.int> get defensive => $_getList(6);

  @$pb.TagNumber(8)
  $core.int get defensiveMarket => $_getIZ(7);
  @$pb.TagNumber(8)
  set defensiveMarket($core.int value) => $_setSignedInt32(7, value);
  @$pb.TagNumber(8)
  $core.bool hasDefensiveMarket() => $_has(7);
  @$pb.TagNumber(8)
  void clearDefensiveMarket() => $_clearField(8);
}

class ShipSubsystem_Subsystem extends $pb.GeneratedMessage {
  factory ShipSubsystem_Subsystem({
    $0.I18N? name,
    $core.int? high,
    $core.int? medium,
    $core.int? low,
    $core.int? turret,
    $core.int? launcher,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (high != null) result.high = high;
    if (medium != null) result.medium = medium;
    if (low != null) result.low = low;
    if (turret != null) result.turret = turret;
    if (launcher != null) result.launcher = launcher;
    return result;
  }

  ShipSubsystem_Subsystem._();

  factory ShipSubsystem_Subsystem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ShipSubsystem_Subsystem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShipSubsystem.Subsystem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'subsystem'),
      createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..aI(2, _omitFieldNames ? '' : 'high')
    ..aI(3, _omitFieldNames ? '' : 'medium')
    ..aI(4, _omitFieldNames ? '' : 'low')
    ..aI(5, _omitFieldNames ? '' : 'turret')
    ..aI(6, _omitFieldNames ? '' : 'launcher');

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShipSubsystem_Subsystem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShipSubsystem_Subsystem copyWith(
          void Function(ShipSubsystem_Subsystem) updates) =>
      super.copyWith((message) => updates(message as ShipSubsystem_Subsystem))
          as ShipSubsystem_Subsystem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShipSubsystem_Subsystem create() => ShipSubsystem_Subsystem._();
  @$core.override
  ShipSubsystem_Subsystem createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ShipSubsystem_Subsystem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShipSubsystem_Subsystem>(create);
  static ShipSubsystem_Subsystem? _defaultInstance;

  @$pb.TagNumber(1)
  $0.I18N get name => $_getN(0);
  @$pb.TagNumber(1)
  set name($0.I18N value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);
  @$pb.TagNumber(1)
  $0.I18N ensureName() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get high => $_getIZ(1);
  @$pb.TagNumber(2)
  set high($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasHigh() => $_has(1);
  @$pb.TagNumber(2)
  void clearHigh() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get medium => $_getIZ(2);
  @$pb.TagNumber(3)
  set medium($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMedium() => $_has(2);
  @$pb.TagNumber(3)
  void clearMedium() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get low => $_getIZ(3);
  @$pb.TagNumber(4)
  set low($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasLow() => $_has(3);
  @$pb.TagNumber(4)
  void clearLow() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get turret => $_getIZ(4);
  @$pb.TagNumber(5)
  set turret($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasTurret() => $_has(4);
  @$pb.TagNumber(5)
  void clearTurret() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get launcher => $_getIZ(5);
  @$pb.TagNumber(6)
  set launcher($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLauncher() => $_has(5);
  @$pb.TagNumber(6)
  void clearLauncher() => $_clearField(6);
}

class ShipSubsystem extends $pb.GeneratedMessage {
  factory ShipSubsystem({
    $core.Iterable<$core.MapEntry<$core.int, ShipSubsystem_Ship>>? ships,
    $core.Iterable<$core.MapEntry<$core.int, ShipSubsystem_Subsystem>>?
        subsystems,
  }) {
    final result = create();
    if (ships != null) result.ships.addEntries(ships);
    if (subsystems != null) result.subsystems.addEntries(subsystems);
    return result;
  }

  ShipSubsystem._();

  factory ShipSubsystem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ShipSubsystem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShipSubsystem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'subsystem'),
      createEmptyInstance: create)
    ..m<$core.int, ShipSubsystem_Ship>(1, _omitFieldNames ? '' : 'ships',
        entryClassName: 'ShipSubsystem.ShipsEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: ShipSubsystem_Ship.create,
        valueDefaultOrMaker: ShipSubsystem_Ship.getDefault,
        packageName: const $pb.PackageName('subsystem'))
    ..m<$core.int, ShipSubsystem_Subsystem>(
        2, _omitFieldNames ? '' : 'subsystems',
        entryClassName: 'ShipSubsystem.SubsystemsEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: ShipSubsystem_Subsystem.create,
        valueDefaultOrMaker: ShipSubsystem_Subsystem.getDefault,
        packageName: const $pb.PackageName('subsystem'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShipSubsystem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShipSubsystem copyWith(void Function(ShipSubsystem) updates) =>
      super.copyWith((message) => updates(message as ShipSubsystem))
          as ShipSubsystem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShipSubsystem create() => ShipSubsystem._();
  @$core.override
  ShipSubsystem createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ShipSubsystem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShipSubsystem>(create);
  static ShipSubsystem? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, ShipSubsystem_Ship> get ships => $_getMap(0);

  @$pb.TagNumber(2)
  $pb.PbMap<$core.int, ShipSubsystem_Subsystem> get subsystems => $_getMap(1);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
