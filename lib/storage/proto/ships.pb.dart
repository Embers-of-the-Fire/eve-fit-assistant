//
//  Generated code. Do not modify.
//  source: ships.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'i18n.pb.dart' as $0;

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
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (groupID != null) {
      $result.groupID = groupID;
    }
    if (published != null) {
      $result.published = published;
    }
    if (highSlotNum != null) {
      $result.highSlotNum = highSlotNum;
    }
    if (medSlotNum != null) {
      $result.medSlotNum = medSlotNum;
    }
    if (lowSlotNum != null) {
      $result.lowSlotNum = lowSlotNum;
    }
    if (rigSlotNum != null) {
      $result.rigSlotNum = rigSlotNum;
    }
    if (hasSubsystem != null) {
      $result.hasSubsystem = hasSubsystem;
    }
    if (turretSlotNum != null) {
      $result.turretSlotNum = turretSlotNum;
    }
    if (launcherSlotNum != null) {
      $result.launcherSlotNum = launcherSlotNum;
    }
    if (droneBandwidth != null) {
      $result.droneBandwidth = droneBandwidth;
    }
    if (hasTacticalMode != null) {
      $result.hasTacticalMode = hasTacticalMode;
    }
    return $result;
  }
  Ships_Ship._() : super();
  factory Ships_Ship.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Ships_Ship.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Ships.Ship',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ships'), createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'groupID', $pb.PbFieldType.Q3, protoName: 'groupID')
    ..a<$core.bool>(3, _omitFieldNames ? '' : 'published', $pb.PbFieldType.QB)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'highSlotNum', $pb.PbFieldType.Q3,
        protoName: 'highSlotNum')
    ..a<$core.int>(5, _omitFieldNames ? '' : 'medSlotNum', $pb.PbFieldType.Q3,
        protoName: 'medSlotNum')
    ..a<$core.int>(6, _omitFieldNames ? '' : 'lowSlotNum', $pb.PbFieldType.Q3,
        protoName: 'lowSlotNum')
    ..a<$core.int>(7, _omitFieldNames ? '' : 'rigSlotNum', $pb.PbFieldType.Q3,
        protoName: 'rigSlotNum')
    ..a<$core.bool>(8, _omitFieldNames ? '' : 'hasSubsystem', $pb.PbFieldType.QB,
        protoName: 'hasSubsystem')
    ..a<$core.int>(9, _omitFieldNames ? '' : 'turretSlotNum', $pb.PbFieldType.Q3,
        protoName: 'turretSlotNum')
    ..a<$core.int>(10, _omitFieldNames ? '' : 'launcherSlotNum', $pb.PbFieldType.Q3,
        protoName: 'launcherSlotNum')
    ..a<$core.int>(11, _omitFieldNames ? '' : 'droneBandwidth', $pb.PbFieldType.Q3,
        protoName: 'droneBandwidth')
    ..a<$core.bool>(12, _omitFieldNames ? '' : 'hasTacticalMode', $pb.PbFieldType.QB,
        protoName: 'hasTacticalMode');

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Ships_Ship clone() => Ships_Ship()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Ships_Ship copyWith(void Function(Ships_Ship) updates) =>
      super.copyWith((message) => updates(message as Ships_Ship)) as Ships_Ship;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Ships_Ship create() => Ships_Ship._();
  Ships_Ship createEmptyInstance() => create();
  static $pb.PbList<Ships_Ship> createRepeated() => $pb.PbList<Ships_Ship>();
  @$core.pragma('dart2js:noInline')
  static Ships_Ship getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Ships_Ship>(create);
  static Ships_Ship? _defaultInstance;

  @$pb.TagNumber(1)
  $0.I18N get name => $_getN(0);
  @$pb.TagNumber(1)
  set name($0.I18N v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);
  @$pb.TagNumber(1)
  $0.I18N ensureName() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get groupID => $_getIZ(1);
  @$pb.TagNumber(2)
  set groupID($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasGroupID() => $_has(1);
  @$pb.TagNumber(2)
  void clearGroupID() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get published => $_getBF(2);
  @$pb.TagNumber(3)
  set published($core.bool v) {
    $_setBool(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasPublished() => $_has(2);
  @$pb.TagNumber(3)
  void clearPublished() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get highSlotNum => $_getIZ(3);
  @$pb.TagNumber(4)
  set highSlotNum($core.int v) {
    $_setSignedInt32(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasHighSlotNum() => $_has(3);
  @$pb.TagNumber(4)
  void clearHighSlotNum() => clearField(4);

  @$pb.TagNumber(5)
  $core.int get medSlotNum => $_getIZ(4);
  @$pb.TagNumber(5)
  set medSlotNum($core.int v) {
    $_setSignedInt32(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasMedSlotNum() => $_has(4);
  @$pb.TagNumber(5)
  void clearMedSlotNum() => clearField(5);

  @$pb.TagNumber(6)
  $core.int get lowSlotNum => $_getIZ(5);
  @$pb.TagNumber(6)
  set lowSlotNum($core.int v) {
    $_setSignedInt32(5, v);
  }

  @$pb.TagNumber(6)
  $core.bool hasLowSlotNum() => $_has(5);
  @$pb.TagNumber(6)
  void clearLowSlotNum() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get rigSlotNum => $_getIZ(6);
  @$pb.TagNumber(7)
  set rigSlotNum($core.int v) {
    $_setSignedInt32(6, v);
  }

  @$pb.TagNumber(7)
  $core.bool hasRigSlotNum() => $_has(6);
  @$pb.TagNumber(7)
  void clearRigSlotNum() => clearField(7);

  @$pb.TagNumber(8)
  $core.bool get hasSubsystem => $_getBF(7);
  @$pb.TagNumber(8)
  set hasSubsystem($core.bool v) {
    $_setBool(7, v);
  }

  @$pb.TagNumber(8)
  $core.bool hasHasSubsystem() => $_has(7);
  @$pb.TagNumber(8)
  void clearHasSubsystem() => clearField(8);

  @$pb.TagNumber(9)
  $core.int get turretSlotNum => $_getIZ(8);
  @$pb.TagNumber(9)
  set turretSlotNum($core.int v) {
    $_setSignedInt32(8, v);
  }

  @$pb.TagNumber(9)
  $core.bool hasTurretSlotNum() => $_has(8);
  @$pb.TagNumber(9)
  void clearTurretSlotNum() => clearField(9);

  @$pb.TagNumber(10)
  $core.int get launcherSlotNum => $_getIZ(9);
  @$pb.TagNumber(10)
  set launcherSlotNum($core.int v) {
    $_setSignedInt32(9, v);
  }

  @$pb.TagNumber(10)
  $core.bool hasLauncherSlotNum() => $_has(9);
  @$pb.TagNumber(10)
  void clearLauncherSlotNum() => clearField(10);

  @$pb.TagNumber(11)
  $core.int get droneBandwidth => $_getIZ(10);
  @$pb.TagNumber(11)
  set droneBandwidth($core.int v) {
    $_setSignedInt32(10, v);
  }

  @$pb.TagNumber(11)
  $core.bool hasDroneBandwidth() => $_has(10);
  @$pb.TagNumber(11)
  void clearDroneBandwidth() => clearField(11);

  @$pb.TagNumber(12)
  $core.bool get hasTacticalMode => $_getBF(11);
  @$pb.TagNumber(12)
  set hasTacticalMode($core.bool v) {
    $_setBool(11, v);
  }

  @$pb.TagNumber(12)
  $core.bool hasHasTacticalMode() => $_has(11);
  @$pb.TagNumber(12)
  void clearHasTacticalMode() => clearField(12);
}

class Ships extends $pb.GeneratedMessage {
  factory Ships({
    $core.Map<$core.int, Ships_Ship>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  Ships._() : super();
  factory Ships.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Ships.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Ships',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'ships'), createEmptyInstance: create)
    ..m<$core.int, Ships_Ship>(1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'Ships.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Ships_Ship.create,
        valueDefaultOrMaker: Ships_Ship.getDefault,
        packageName: const $pb.PackageName('ships'));

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Ships clone() => Ships()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Ships copyWith(void Function(Ships) updates) =>
      super.copyWith((message) => updates(message as Ships)) as Ships;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Ships create() => Ships._();
  Ships createEmptyInstance() => create();
  static $pb.PbList<Ships> createRepeated() => $pb.PbList<Ships>();
  @$core.pragma('dart2js:noInline')
  static Ships getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Ships>(create);
  static Ships? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, Ships_Ship> get entries => $_getMap(0);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
