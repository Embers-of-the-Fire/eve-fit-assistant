// This is a generated file - do not edit.
//
// Generated from ships.proto.

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

class Ships_Ship extends $pb.GeneratedMessage {
  factory Ships_Ship({
    $0.I18N? name,
    $core.int? groupID,
    $core.bool? published,
    $core.int? highSlotNum,
    $core.int? medSlotNum,
    $core.int? lowSlotNum,
    $core.int? rigSlotNum,
    $core.bool? hasSubsystem,
    $core.int? turretSlotNum,
    $core.int? launcherSlotNum,
    $core.int? droneBandwidth,
    $core.bool? hasTacticalMode,
    $core.bool? hasFighter,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (groupID != null) result.groupID = groupID;
    if (published != null) result.published = published;
    if (highSlotNum != null) result.highSlotNum = highSlotNum;
    if (medSlotNum != null) result.medSlotNum = medSlotNum;
    if (lowSlotNum != null) result.lowSlotNum = lowSlotNum;
    if (rigSlotNum != null) result.rigSlotNum = rigSlotNum;
    if (hasSubsystem != null) result.hasSubsystem = hasSubsystem;
    if (turretSlotNum != null) result.turretSlotNum = turretSlotNum;
    if (launcherSlotNum != null) result.launcherSlotNum = launcherSlotNum;
    if (droneBandwidth != null) result.droneBandwidth = droneBandwidth;
    if (hasTacticalMode != null) result.hasTacticalMode = hasTacticalMode;
    if (hasFighter != null) result.hasFighter = hasFighter;
    return result;
  }

  Ships_Ship._();

  factory Ships_Ship.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Ships_Ship.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ships.Ship',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ships'),
      createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..aI(2, _omitFieldNames ? '' : 'groupID',
        protoName: 'groupID', fieldType: $pb.PbFieldType.Q3)
    ..a<$core.bool>(3, _omitFieldNames ? '' : 'published', $pb.PbFieldType.QB)
    ..aI(4, _omitFieldNames ? '' : 'highSlotNum',
        protoName: 'highSlotNum', fieldType: $pb.PbFieldType.Q3)
    ..aI(5, _omitFieldNames ? '' : 'medSlotNum',
        protoName: 'medSlotNum', fieldType: $pb.PbFieldType.Q3)
    ..aI(6, _omitFieldNames ? '' : 'lowSlotNum',
        protoName: 'lowSlotNum', fieldType: $pb.PbFieldType.Q3)
    ..aI(7, _omitFieldNames ? '' : 'rigSlotNum',
        protoName: 'rigSlotNum', fieldType: $pb.PbFieldType.Q3)
    ..a<$core.bool>(
        8, _omitFieldNames ? '' : 'hasSubsystem', $pb.PbFieldType.QB,
        protoName: 'hasSubsystem')
    ..aI(9, _omitFieldNames ? '' : 'turretSlotNum',
        protoName: 'turretSlotNum', fieldType: $pb.PbFieldType.Q3)
    ..aI(10, _omitFieldNames ? '' : 'launcherSlotNum',
        protoName: 'launcherSlotNum', fieldType: $pb.PbFieldType.Q3)
    ..aI(11, _omitFieldNames ? '' : 'droneBandwidth',
        protoName: 'droneBandwidth', fieldType: $pb.PbFieldType.Q3)
    ..a<$core.bool>(
        12, _omitFieldNames ? '' : 'hasTacticalMode', $pb.PbFieldType.QB,
        protoName: 'hasTacticalMode')
    ..a<$core.bool>(13, _omitFieldNames ? '' : 'hasFighter', $pb.PbFieldType.QB,
        protoName: 'hasFighter');

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ships_Ship clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ships_Ship copyWith(void Function(Ships_Ship) updates) =>
      super.copyWith((message) => updates(message as Ships_Ship)) as Ships_Ship;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Ships_Ship create() => Ships_Ship._();
  @$core.override
  Ships_Ship createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Ships_Ship getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Ships_Ship>(create);
  static Ships_Ship? _defaultInstance;

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
  $core.int get groupID => $_getIZ(1);
  @$pb.TagNumber(2)
  set groupID($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGroupID() => $_has(1);
  @$pb.TagNumber(2)
  void clearGroupID() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get published => $_getBF(2);
  @$pb.TagNumber(3)
  set published($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPublished() => $_has(2);
  @$pb.TagNumber(3)
  void clearPublished() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get highSlotNum => $_getIZ(3);
  @$pb.TagNumber(4)
  set highSlotNum($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasHighSlotNum() => $_has(3);
  @$pb.TagNumber(4)
  void clearHighSlotNum() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get medSlotNum => $_getIZ(4);
  @$pb.TagNumber(5)
  set medSlotNum($core.int value) => $_setSignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasMedSlotNum() => $_has(4);
  @$pb.TagNumber(5)
  void clearMedSlotNum() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.int get lowSlotNum => $_getIZ(5);
  @$pb.TagNumber(6)
  set lowSlotNum($core.int value) => $_setSignedInt32(5, value);
  @$pb.TagNumber(6)
  $core.bool hasLowSlotNum() => $_has(5);
  @$pb.TagNumber(6)
  void clearLowSlotNum() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get rigSlotNum => $_getIZ(6);
  @$pb.TagNumber(7)
  set rigSlotNum($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasRigSlotNum() => $_has(6);
  @$pb.TagNumber(7)
  void clearRigSlotNum() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get hasSubsystem => $_getBF(7);
  @$pb.TagNumber(8)
  set hasSubsystem($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasHasSubsystem() => $_has(7);
  @$pb.TagNumber(8)
  void clearHasSubsystem() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get turretSlotNum => $_getIZ(8);
  @$pb.TagNumber(9)
  set turretSlotNum($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTurretSlotNum() => $_has(8);
  @$pb.TagNumber(9)
  void clearTurretSlotNum() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.int get launcherSlotNum => $_getIZ(9);
  @$pb.TagNumber(10)
  set launcherSlotNum($core.int value) => $_setSignedInt32(9, value);
  @$pb.TagNumber(10)
  $core.bool hasLauncherSlotNum() => $_has(9);
  @$pb.TagNumber(10)
  void clearLauncherSlotNum() => $_clearField(10);

  @$pb.TagNumber(11)
  $core.int get droneBandwidth => $_getIZ(10);
  @$pb.TagNumber(11)
  set droneBandwidth($core.int value) => $_setSignedInt32(10, value);
  @$pb.TagNumber(11)
  $core.bool hasDroneBandwidth() => $_has(10);
  @$pb.TagNumber(11)
  void clearDroneBandwidth() => $_clearField(11);

  @$pb.TagNumber(12)
  $core.bool get hasTacticalMode => $_getBF(11);
  @$pb.TagNumber(12)
  set hasTacticalMode($core.bool value) => $_setBool(11, value);
  @$pb.TagNumber(12)
  $core.bool hasHasTacticalMode() => $_has(11);
  @$pb.TagNumber(12)
  void clearHasTacticalMode() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.bool get hasFighter => $_getBF(12);
  @$pb.TagNumber(13)
  set hasFighter($core.bool value) => $_setBool(12, value);
  @$pb.TagNumber(13)
  $core.bool hasHasFighter() => $_has(12);
  @$pb.TagNumber(13)
  void clearHasFighter() => $_clearField(13);
}

class Ships extends $pb.GeneratedMessage {
  factory Ships({
    $core.Iterable<$core.MapEntry<$core.int, Ships_Ship>>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addEntries(entries);
    return result;
  }

  Ships._();

  factory Ships.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Ships.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Ships',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ships'),
      createEmptyInstance: create)
    ..m<$core.int, Ships_Ship>(1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'Ships.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Ships_Ship.create,
        valueDefaultOrMaker: Ships_Ship.getDefault,
        packageName: const $pb.PackageName('ships'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ships clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Ships copyWith(void Function(Ships) updates) =>
      super.copyWith((message) => updates(message as Ships)) as Ships;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Ships create() => Ships._();
  @$core.override
  Ships createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Ships getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Ships>(create);
  static Ships? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, Ships_Ship> get entries => $_getMap(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
