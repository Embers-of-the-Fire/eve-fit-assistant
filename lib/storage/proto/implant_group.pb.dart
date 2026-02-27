// This is a generated file - do not edit.
//
// Generated from implant_group.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class ImplantGroups_ImplantGroup extends $pb.GeneratedMessage {
  factory ImplantGroups_ImplantGroup({
    $core.String? name,
    $core.Iterable<ImplantGroups_ImplantSubGroup>? groups,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (groups != null) result.groups.addAll(groups);
    return result;
  }

  ImplantGroups_ImplantGroup._();

  factory ImplantGroups_ImplantGroup.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImplantGroups_ImplantGroup.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImplantGroups.ImplantGroup',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'implant_group'),
      createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'name')
    ..pPM<ImplantGroups_ImplantSubGroup>(2, _omitFieldNames ? '' : 'groups',
        subBuilder: ImplantGroups_ImplantSubGroup.create);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImplantGroups_ImplantGroup clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImplantGroups_ImplantGroup copyWith(
          void Function(ImplantGroups_ImplantGroup) updates) =>
      super.copyWith(
              (message) => updates(message as ImplantGroups_ImplantGroup))
          as ImplantGroups_ImplantGroup;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImplantGroups_ImplantGroup create() => ImplantGroups_ImplantGroup._();
  @$core.override
  ImplantGroups_ImplantGroup createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImplantGroups_ImplantGroup getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImplantGroups_ImplantGroup>(create);
  static ImplantGroups_ImplantGroup? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<ImplantGroups_ImplantSubGroup> get groups => $_getList(1);
}

class ImplantGroups_ImplantSubGroup extends $pb.GeneratedMessage {
  factory ImplantGroups_ImplantSubGroup({
    $core.String? name,
    $core.Iterable<$core.int>? items,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (items != null) result.items.addAll(items);
    return result;
  }

  ImplantGroups_ImplantSubGroup._();

  factory ImplantGroups_ImplantSubGroup.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImplantGroups_ImplantSubGroup.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImplantGroups.ImplantSubGroup',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'implant_group'),
      createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'name')
    ..p<$core.int>(2, _omitFieldNames ? '' : 'items', $pb.PbFieldType.P3);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImplantGroups_ImplantSubGroup clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImplantGroups_ImplantSubGroup copyWith(
          void Function(ImplantGroups_ImplantSubGroup) updates) =>
      super.copyWith(
              (message) => updates(message as ImplantGroups_ImplantSubGroup))
          as ImplantGroups_ImplantSubGroup;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImplantGroups_ImplantSubGroup create() =>
      ImplantGroups_ImplantSubGroup._();
  @$core.override
  ImplantGroups_ImplantSubGroup createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImplantGroups_ImplantSubGroup getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImplantGroups_ImplantSubGroup>(create);
  static ImplantGroups_ImplantSubGroup? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.int> get items => $_getList(1);
}

class ImplantGroups extends $pb.GeneratedMessage {
  factory ImplantGroups({
    $core.Iterable<ImplantGroups_ImplantGroup>? groups,
  }) {
    final result = create();
    if (groups != null) result.groups.addAll(groups);
    return result;
  }

  ImplantGroups._();

  factory ImplantGroups.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory ImplantGroups.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'ImplantGroups',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'implant_group'),
      createEmptyInstance: create)
    ..pPM<ImplantGroups_ImplantGroup>(1, _omitFieldNames ? '' : 'groups',
        subBuilder: ImplantGroups_ImplantGroup.create);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImplantGroups clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  ImplantGroups copyWith(void Function(ImplantGroups) updates) =>
      super.copyWith((message) => updates(message as ImplantGroups))
          as ImplantGroups;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImplantGroups create() => ImplantGroups._();
  @$core.override
  ImplantGroups createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static ImplantGroups getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<ImplantGroups>(create);
  static ImplantGroups? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<ImplantGroups_ImplantGroup> get groups => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
