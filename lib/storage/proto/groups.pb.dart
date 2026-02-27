// This is a generated file - do not edit.
//
// Generated from groups.proto.

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

class Groups_Group extends $pb.GeneratedMessage {
  factory Groups_Group({
    $0.I18N? name,
    $core.int? categoryID,
    $core.bool? published,
    $core.Iterable<$core.int>? types,
    $core.Iterable<$core.int>? relatedMarketGroups,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (categoryID != null) result.categoryID = categoryID;
    if (published != null) result.published = published;
    if (types != null) result.types.addAll(types);
    if (relatedMarketGroups != null)
      result.relatedMarketGroups.addAll(relatedMarketGroups);
    return result;
  }

  Groups_Group._();

  factory Groups_Group.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Groups_Group.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Groups.Group',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'groups'),
      createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..aI(2, _omitFieldNames ? '' : 'categoryID',
        protoName: 'categoryID', fieldType: $pb.PbFieldType.Q3)
    ..a<$core.bool>(3, _omitFieldNames ? '' : 'published', $pb.PbFieldType.QB)
    ..p<$core.int>(4, _omitFieldNames ? '' : 'types', $pb.PbFieldType.P3)
    ..p<$core.int>(
        5, _omitFieldNames ? '' : 'relatedMarketGroups', $pb.PbFieldType.P3,
        protoName: 'relatedMarketGroups');

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Groups_Group clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Groups_Group copyWith(void Function(Groups_Group) updates) =>
      super.copyWith((message) => updates(message as Groups_Group))
          as Groups_Group;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Groups_Group create() => Groups_Group._();
  @$core.override
  Groups_Group createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Groups_Group getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Groups_Group>(create);
  static Groups_Group? _defaultInstance;

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
  $core.int get categoryID => $_getIZ(1);
  @$pb.TagNumber(2)
  set categoryID($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasCategoryID() => $_has(1);
  @$pb.TagNumber(2)
  void clearCategoryID() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get published => $_getBF(2);
  @$pb.TagNumber(3)
  set published($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPublished() => $_has(2);
  @$pb.TagNumber(3)
  void clearPublished() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.int> get types => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<$core.int> get relatedMarketGroups => $_getList(4);
}

class Groups extends $pb.GeneratedMessage {
  factory Groups({
    $core.Iterable<$core.MapEntry<$core.int, Groups_Group>>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addEntries(entries);
    return result;
  }

  Groups._();

  factory Groups.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Groups.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Groups',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'groups'),
      createEmptyInstance: create)
    ..m<$core.int, Groups_Group>(1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'Groups.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Groups_Group.create,
        valueDefaultOrMaker: Groups_Group.getDefault,
        packageName: const $pb.PackageName('groups'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Groups clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Groups copyWith(void Function(Groups) updates) =>
      super.copyWith((message) => updates(message as Groups)) as Groups;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Groups create() => Groups._();
  @$core.override
  Groups createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Groups getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Groups>(create);
  static Groups? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, Groups_Group> get entries => $_getMap(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
