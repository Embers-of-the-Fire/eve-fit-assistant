//
//  Generated code. Do not modify.
//  source: subsystem.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'i18n.pb.dart' as $0;

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
    final $result = create();
    if (offensive != null) {
      $result.offensive.addAll(offensive);
    }
    if (offensiveMarket != null) {
      $result.offensiveMarket = offensiveMarket;
    }
    if (propulsion != null) {
      $result.propulsion.addAll(propulsion);
    }
    if (propulsionMarket != null) {
      $result.propulsionMarket = propulsionMarket;
    }
    if (core != null) {
      $result.core.addAll(core);
    }
    if (coreMarket != null) {
      $result.coreMarket = coreMarket;
    }
    if (defensive != null) {
      $result.defensive.addAll(defensive);
    }
    if (defensiveMarket != null) {
      $result.defensiveMarket = defensiveMarket;
    }
    return $result;
  }
  ShipSubsystem_Ship._() : super();
  factory ShipSubsystem_Ship.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ShipSubsystem_Ship.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ShipSubsystem.Ship', package: const $pb.PackageName(_omitMessageNames ? '' : 'subsystem'), createEmptyInstance: create)
    ..p<$core.int>(1, _omitFieldNames ? '' : 'offensive', $pb.PbFieldType.P3)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'offensiveMarket', $pb.PbFieldType.Q3, protoName: 'offensiveMarket')
    ..p<$core.int>(3, _omitFieldNames ? '' : 'propulsion', $pb.PbFieldType.P3)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'propulsionMarket', $pb.PbFieldType.Q3, protoName: 'propulsionMarket')
    ..p<$core.int>(5, _omitFieldNames ? '' : 'core', $pb.PbFieldType.P3)
    ..a<$core.int>(6, _omitFieldNames ? '' : 'coreMarket', $pb.PbFieldType.Q3, protoName: 'coreMarket')
    ..p<$core.int>(7, _omitFieldNames ? '' : 'defensive', $pb.PbFieldType.P3)
    ..a<$core.int>(8, _omitFieldNames ? '' : 'defensiveMarket', $pb.PbFieldType.Q3, protoName: 'defensiveMarket')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ShipSubsystem_Ship clone() => ShipSubsystem_Ship()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ShipSubsystem_Ship copyWith(void Function(ShipSubsystem_Ship) updates) => super.copyWith((message) => updates(message as ShipSubsystem_Ship)) as ShipSubsystem_Ship;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShipSubsystem_Ship create() => ShipSubsystem_Ship._();
  ShipSubsystem_Ship createEmptyInstance() => create();
  static $pb.PbList<ShipSubsystem_Ship> createRepeated() => $pb.PbList<ShipSubsystem_Ship>();
  @$core.pragma('dart2js:noInline')
  static ShipSubsystem_Ship getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShipSubsystem_Ship>(create);
  static ShipSubsystem_Ship? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get offensive => $_getList(0);

  @$pb.TagNumber(2)
  $core.int get offensiveMarket => $_getIZ(1);
  @$pb.TagNumber(2)
  set offensiveMarket($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasOffensiveMarket() => $_has(1);
  @$pb.TagNumber(2)
  void clearOffensiveMarket() => clearField(2);

  @$pb.TagNumber(3)
  $core.List<$core.int> get propulsion => $_getList(2);

  @$pb.TagNumber(4)
  $core.int get propulsionMarket => $_getIZ(3);
  @$pb.TagNumber(4)
  set propulsionMarket($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasPropulsionMarket() => $_has(3);
  @$pb.TagNumber(4)
  void clearPropulsionMarket() => clearField(4);

  @$pb.TagNumber(5)
  $core.List<$core.int> get core => $_getList(4);

  @$pb.TagNumber(6)
  $core.int get coreMarket => $_getIZ(5);
  @$pb.TagNumber(6)
  set coreMarket($core.int v) { $_setSignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasCoreMarket() => $_has(5);
  @$pb.TagNumber(6)
  void clearCoreMarket() => clearField(6);

  @$pb.TagNumber(7)
  $core.List<$core.int> get defensive => $_getList(6);

  @$pb.TagNumber(8)
  $core.int get defensiveMarket => $_getIZ(7);
  @$pb.TagNumber(8)
  set defensiveMarket($core.int v) { $_setSignedInt32(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasDefensiveMarket() => $_has(7);
  @$pb.TagNumber(8)
  void clearDefensiveMarket() => clearField(8);
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
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (high != null) {
      $result.high = high;
    }
    if (medium != null) {
      $result.medium = medium;
    }
    if (low != null) {
      $result.low = low;
    }
    if (turret != null) {
      $result.turret = turret;
    }
    if (launcher != null) {
      $result.launcher = launcher;
    }
    return $result;
  }
  ShipSubsystem_Subsystem._() : super();
  factory ShipSubsystem_Subsystem.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ShipSubsystem_Subsystem.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ShipSubsystem.Subsystem', package: const $pb.PackageName(_omitMessageNames ? '' : 'subsystem'), createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'high', $pb.PbFieldType.O3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'medium', $pb.PbFieldType.O3)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'low', $pb.PbFieldType.O3)
    ..a<$core.int>(5, _omitFieldNames ? '' : 'turret', $pb.PbFieldType.O3)
    ..a<$core.int>(6, _omitFieldNames ? '' : 'launcher', $pb.PbFieldType.O3)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ShipSubsystem_Subsystem clone() => ShipSubsystem_Subsystem()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ShipSubsystem_Subsystem copyWith(void Function(ShipSubsystem_Subsystem) updates) => super.copyWith((message) => updates(message as ShipSubsystem_Subsystem)) as ShipSubsystem_Subsystem;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShipSubsystem_Subsystem create() => ShipSubsystem_Subsystem._();
  ShipSubsystem_Subsystem createEmptyInstance() => create();
  static $pb.PbList<ShipSubsystem_Subsystem> createRepeated() => $pb.PbList<ShipSubsystem_Subsystem>();
  @$core.pragma('dart2js:noInline')
  static ShipSubsystem_Subsystem getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShipSubsystem_Subsystem>(create);
  static ShipSubsystem_Subsystem? _defaultInstance;

  @$pb.TagNumber(1)
  $0.I18N get name => $_getN(0);
  @$pb.TagNumber(1)
  set name($0.I18N v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);
  @$pb.TagNumber(1)
  $0.I18N ensureName() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get high => $_getIZ(1);
  @$pb.TagNumber(2)
  set high($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasHigh() => $_has(1);
  @$pb.TagNumber(2)
  void clearHigh() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get medium => $_getIZ(2);
  @$pb.TagNumber(3)
  set medium($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasMedium() => $_has(2);
  @$pb.TagNumber(3)
  void clearMedium() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get low => $_getIZ(3);
  @$pb.TagNumber(4)
  set low($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasLow() => $_has(3);
  @$pb.TagNumber(4)
  void clearLow() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get turret => $_getIZ(4);
  @$pb.TagNumber(5)
  set turret($core.int v) { $_setSignedInt32(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasTurret() => $_has(4);
  @$pb.TagNumber(5)
  void clearTurret() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get launcher => $_getIZ(5);
  @$pb.TagNumber(6)
  set launcher($core.int v) { $_setSignedInt32(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasLauncher() => $_has(5);
  @$pb.TagNumber(6)
  void clearLauncher() => clearField(6);
}

class ShipSubsystem extends $pb.GeneratedMessage {
  factory ShipSubsystem({
    $core.Map<$core.int, ShipSubsystem_Ship>? ships,
    $core.Map<$core.int, ShipSubsystem_Subsystem>? subsystems,
  }) {
    final $result = create();
    if (ships != null) {
      $result.ships.addAll(ships);
    }
    if (subsystems != null) {
      $result.subsystems.addAll(subsystems);
    }
    return $result;
  }
  ShipSubsystem._() : super();
  factory ShipSubsystem.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ShipSubsystem.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ShipSubsystem', package: const $pb.PackageName(_omitMessageNames ? '' : 'subsystem'), createEmptyInstance: create)
    ..m<$core.int, ShipSubsystem_Ship>(1, _omitFieldNames ? '' : 'ships', entryClassName: 'ShipSubsystem.ShipsEntry', keyFieldType: $pb.PbFieldType.O3, valueFieldType: $pb.PbFieldType.OM, valueCreator: ShipSubsystem_Ship.create, valueDefaultOrMaker: ShipSubsystem_Ship.getDefault, packageName: const $pb.PackageName('subsystem'))
    ..m<$core.int, ShipSubsystem_Subsystem>(2, _omitFieldNames ? '' : 'subsystems', entryClassName: 'ShipSubsystem.SubsystemsEntry', keyFieldType: $pb.PbFieldType.O3, valueFieldType: $pb.PbFieldType.OM, valueCreator: ShipSubsystem_Subsystem.create, valueDefaultOrMaker: ShipSubsystem_Subsystem.getDefault, packageName: const $pb.PackageName('subsystem'))
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ShipSubsystem clone() => ShipSubsystem()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ShipSubsystem copyWith(void Function(ShipSubsystem) updates) => super.copyWith((message) => updates(message as ShipSubsystem)) as ShipSubsystem;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShipSubsystem create() => ShipSubsystem._();
  ShipSubsystem createEmptyInstance() => create();
  static $pb.PbList<ShipSubsystem> createRepeated() => $pb.PbList<ShipSubsystem>();
  @$core.pragma('dart2js:noInline')
  static ShipSubsystem getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShipSubsystem>(create);
  static ShipSubsystem? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, ShipSubsystem_Ship> get ships => $_getMap(0);

  @$pb.TagNumber(2)
  $core.Map<$core.int, ShipSubsystem_Subsystem> get subsystems => $_getMap(1);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
