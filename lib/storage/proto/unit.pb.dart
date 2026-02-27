// This is a generated file - do not edit.
//
// Generated from unit.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Units_Unit extends $pb.GeneratedMessage {
  factory Units_Unit({
    $core.String? name,
    $core.int? id,
    $core.String? displayName,
    $core.String? description,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (id != null) result.id = id;
    if (displayName != null) result.displayName = displayName;
    if (description != null) result.description = description;
    return result;
  }

  Units_Unit._();

  factory Units_Unit.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Units_Unit.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Units.Unit',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'unit'),
      createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'name')
    ..aI(2, _omitFieldNames ? '' : 'id', fieldType: $pb.PbFieldType.Q3)
    ..aQS(3, _omitFieldNames ? '' : 'displayName', protoName: 'displayName')
    ..aQS(4, _omitFieldNames ? '' : 'description');

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Units_Unit clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Units_Unit copyWith(void Function(Units_Unit) updates) =>
      super.copyWith((message) => updates(message as Units_Unit)) as Units_Unit;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Units_Unit create() => Units_Unit._();
  @$core.override
  Units_Unit createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Units_Unit getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Units_Unit>(create);
  static Units_Unit? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get id => $_getIZ(1);
  @$pb.TagNumber(2)
  set id($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasId() => $_has(1);
  @$pb.TagNumber(2)
  void clearId() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.String get displayName => $_getSZ(2);
  @$pb.TagNumber(3)
  set displayName($core.String value) => $_setString(2, value);
  @$pb.TagNumber(3)
  $core.bool hasDisplayName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayName() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get description => $_getSZ(3);
  @$pb.TagNumber(4)
  set description($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDescription() => $_has(3);
  @$pb.TagNumber(4)
  void clearDescription() => $_clearField(4);
}

class Units extends $pb.GeneratedMessage {
  factory Units({
    $core.Iterable<$core.MapEntry<$core.int, Units_Unit>>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addEntries(entries);
    return result;
  }

  Units._();

  factory Units.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Units.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Units',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'unit'),
      createEmptyInstance: create)
    ..m<$core.int, Units_Unit>(1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'Units.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Units_Unit.create,
        valueDefaultOrMaker: Units_Unit.getDefault,
        packageName: const $pb.PackageName('unit'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Units clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Units copyWith(void Function(Units) updates) =>
      super.copyWith((message) => updates(message as Units)) as Units;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Units create() => Units._();
  @$core.override
  Units createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Units getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Units>(create);
  static Units? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, Units_Unit> get entries => $_getMap(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
