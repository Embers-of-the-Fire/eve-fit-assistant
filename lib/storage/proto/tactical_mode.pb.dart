//
//  Generated code. Do not modify.
//  source: tactical_mode.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'i18n.pb.dart' as $0;

class ShipTacticalMode_Ship extends $pb.GeneratedMessage {
  factory ShipTacticalMode_Ship({
    $core.Map<$core.int, ShipTacticalMode_TacticalMode>? tacticalModes,
  }) {
    final $result = create();
    if (tacticalModes != null) {
      $result.tacticalModes.addAll(tacticalModes);
    }
    return $result;
  }
  ShipTacticalMode_Ship._() : super();
  factory ShipTacticalMode_Ship.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ShipTacticalMode_Ship.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ShipTacticalMode.Ship', package: const $pb.PackageName(_omitMessageNames ? '' : 'tactical_mode'), createEmptyInstance: create)
    ..m<$core.int, ShipTacticalMode_TacticalMode>(1, _omitFieldNames ? '' : 'tacticalModes', protoName: 'tacticalModes', entryClassName: 'ShipTacticalMode.Ship.TacticalModesEntry', keyFieldType: $pb.PbFieldType.O3, valueFieldType: $pb.PbFieldType.OM, valueCreator: ShipTacticalMode_TacticalMode.create, valueDefaultOrMaker: ShipTacticalMode_TacticalMode.getDefault, packageName: const $pb.PackageName('tactical_mode'))
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ShipTacticalMode_Ship clone() => ShipTacticalMode_Ship()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ShipTacticalMode_Ship copyWith(void Function(ShipTacticalMode_Ship) updates) => super.copyWith((message) => updates(message as ShipTacticalMode_Ship)) as ShipTacticalMode_Ship;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShipTacticalMode_Ship create() => ShipTacticalMode_Ship._();
  ShipTacticalMode_Ship createEmptyInstance() => create();
  static $pb.PbList<ShipTacticalMode_Ship> createRepeated() => $pb.PbList<ShipTacticalMode_Ship>();
  @$core.pragma('dart2js:noInline')
  static ShipTacticalMode_Ship getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShipTacticalMode_Ship>(create);
  static ShipTacticalMode_Ship? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, ShipTacticalMode_TacticalMode> get tacticalModes => $_getMap(0);
}

class ShipTacticalMode_TacticalMode extends $pb.GeneratedMessage {
  factory ShipTacticalMode_TacticalMode({
    $0.I18N? name,
    $core.int? iconID,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (iconID != null) {
      $result.iconID = iconID;
    }
    return $result;
  }
  ShipTacticalMode_TacticalMode._() : super();
  factory ShipTacticalMode_TacticalMode.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ShipTacticalMode_TacticalMode.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ShipTacticalMode.TacticalMode', package: const $pb.PackageName(_omitMessageNames ? '' : 'tactical_mode'), createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'iconID', $pb.PbFieldType.Q3, protoName: 'iconID')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ShipTacticalMode_TacticalMode clone() => ShipTacticalMode_TacticalMode()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ShipTacticalMode_TacticalMode copyWith(void Function(ShipTacticalMode_TacticalMode) updates) => super.copyWith((message) => updates(message as ShipTacticalMode_TacticalMode)) as ShipTacticalMode_TacticalMode;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShipTacticalMode_TacticalMode create() => ShipTacticalMode_TacticalMode._();
  ShipTacticalMode_TacticalMode createEmptyInstance() => create();
  static $pb.PbList<ShipTacticalMode_TacticalMode> createRepeated() => $pb.PbList<ShipTacticalMode_TacticalMode>();
  @$core.pragma('dart2js:noInline')
  static ShipTacticalMode_TacticalMode getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShipTacticalMode_TacticalMode>(create);
  static ShipTacticalMode_TacticalMode? _defaultInstance;

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
  $core.int get iconID => $_getIZ(1);
  @$pb.TagNumber(2)
  set iconID($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasIconID() => $_has(1);
  @$pb.TagNumber(2)
  void clearIconID() => clearField(2);
}

class ShipTacticalMode extends $pb.GeneratedMessage {
  factory ShipTacticalMode({
    $core.Map<$core.int, ShipTacticalMode_Ship>? ships,
  }) {
    final $result = create();
    if (ships != null) {
      $result.ships.addAll(ships);
    }
    return $result;
  }
  ShipTacticalMode._() : super();
  factory ShipTacticalMode.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ShipTacticalMode.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ShipTacticalMode', package: const $pb.PackageName(_omitMessageNames ? '' : 'tactical_mode'), createEmptyInstance: create)
    ..m<$core.int, ShipTacticalMode_Ship>(1, _omitFieldNames ? '' : 'ships', entryClassName: 'ShipTacticalMode.ShipsEntry', keyFieldType: $pb.PbFieldType.O3, valueFieldType: $pb.PbFieldType.OM, valueCreator: ShipTacticalMode_Ship.create, valueDefaultOrMaker: ShipTacticalMode_Ship.getDefault, packageName: const $pb.PackageName('tactical_mode'))
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ShipTacticalMode clone() => ShipTacticalMode()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ShipTacticalMode copyWith(void Function(ShipTacticalMode) updates) => super.copyWith((message) => updates(message as ShipTacticalMode)) as ShipTacticalMode;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShipTacticalMode create() => ShipTacticalMode._();
  ShipTacticalMode createEmptyInstance() => create();
  static $pb.PbList<ShipTacticalMode> createRepeated() => $pb.PbList<ShipTacticalMode>();
  @$core.pragma('dart2js:noInline')
  static ShipTacticalMode getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ShipTacticalMode>(create);
  static ShipTacticalMode? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, ShipTacticalMode_Ship> get ships => $_getMap(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
