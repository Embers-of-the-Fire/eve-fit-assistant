// This is a generated file - do not edit.
//
// Generated from tactical_mode.proto.

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

class ShipTacticalMode_Ship extends $pb.GeneratedMessage {
  factory ShipTacticalMode_Ship({
    $core.Iterable<$core.MapEntry<$core.int, ShipTacticalMode_TacticalMode>>?
        tacticalModes,
  }) {
    final result = create();
    if (tacticalModes != null) result.tacticalModes.addEntries(tacticalModes);
    return result;
  }

  ShipTacticalMode_Ship._();

  factory ShipTacticalMode_Ship.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ShipTacticalMode_Ship.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShipTacticalMode.Ship',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tactical_mode'),
      createEmptyInstance: create)
    ..m<$core.int, ShipTacticalMode_TacticalMode>(
        1, _omitFieldNames ? '' : 'tacticalModes',
        protoName: 'tacticalModes',
        entryClassName: 'ShipTacticalMode.Ship.TacticalModesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: ShipTacticalMode_TacticalMode.create,
        valueDefaultOrMaker: ShipTacticalMode_TacticalMode.getDefault,
        packageName: const $pb.PackageName('tactical_mode'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShipTacticalMode_Ship clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShipTacticalMode_Ship copyWith(
          void Function(ShipTacticalMode_Ship) updates) =>
      super.copyWith((message) => updates(message as ShipTacticalMode_Ship))
          as ShipTacticalMode_Ship;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShipTacticalMode_Ship create() => ShipTacticalMode_Ship._();
  @$core.override
  ShipTacticalMode_Ship createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ShipTacticalMode_Ship getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShipTacticalMode_Ship>(create);
  static ShipTacticalMode_Ship? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, ShipTacticalMode_TacticalMode> get tacticalModes =>
      $_getMap(0);
}

class ShipTacticalMode_TacticalMode extends $pb.GeneratedMessage {
  factory ShipTacticalMode_TacticalMode({
    $0.I18N? name,
    $core.int? iconID,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (iconID != null) result.iconID = iconID;
    return result;
  }

  ShipTacticalMode_TacticalMode._();

  factory ShipTacticalMode_TacticalMode.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ShipTacticalMode_TacticalMode.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShipTacticalMode.TacticalMode',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tactical_mode'),
      createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..aI(2, _omitFieldNames ? '' : 'iconID',
        protoName: 'iconID', fieldType: $pb.PbFieldType.Q3);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShipTacticalMode_TacticalMode clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShipTacticalMode_TacticalMode copyWith(
          void Function(ShipTacticalMode_TacticalMode) updates) =>
      super.copyWith(
              (message) => updates(message as ShipTacticalMode_TacticalMode))
          as ShipTacticalMode_TacticalMode;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShipTacticalMode_TacticalMode create() =>
      ShipTacticalMode_TacticalMode._();
  @$core.override
  ShipTacticalMode_TacticalMode createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ShipTacticalMode_TacticalMode getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShipTacticalMode_TacticalMode>(create);
  static ShipTacticalMode_TacticalMode? _defaultInstance;

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
  $core.int get iconID => $_getIZ(1);
  @$pb.TagNumber(2)
  set iconID($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasIconID() => $_has(1);
  @$pb.TagNumber(2)
  void clearIconID() => $_clearField(2);
}

class ShipTacticalMode extends $pb.GeneratedMessage {
  factory ShipTacticalMode({
    $core.Iterable<$core.MapEntry<$core.int, ShipTacticalMode_Ship>>? ships,
  }) {
    final result = create();
    if (ships != null) result.ships.addEntries(ships);
    return result;
  }

  ShipTacticalMode._();

  factory ShipTacticalMode.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ShipTacticalMode.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ShipTacticalMode',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'tactical_mode'),
      createEmptyInstance: create)
    ..m<$core.int, ShipTacticalMode_Ship>(1, _omitFieldNames ? '' : 'ships',
        entryClassName: 'ShipTacticalMode.ShipsEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: ShipTacticalMode_Ship.create,
        valueDefaultOrMaker: ShipTacticalMode_Ship.getDefault,
        packageName: const $pb.PackageName('tactical_mode'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShipTacticalMode clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ShipTacticalMode copyWith(void Function(ShipTacticalMode) updates) =>
      super.copyWith((message) => updates(message as ShipTacticalMode))
          as ShipTacticalMode;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ShipTacticalMode create() => ShipTacticalMode._();
  @$core.override
  ShipTacticalMode createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ShipTacticalMode getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ShipTacticalMode>(create);
  static ShipTacticalMode? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, ShipTacticalMode_Ship> get ships => $_getMap(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
