// This is a generated file - do not edit.
//
// Generated from market_group.proto.

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

class MarketGroups_MarketGroup extends $pb.GeneratedMessage {
  factory MarketGroups_MarketGroup({
    $0.I18N? name,
    $core.int? parentGroup,
    $core.int? iconID,
    $core.Iterable<$core.int>? types,
    $core.Iterable<$core.int>? childGroups,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (parentGroup != null) result.parentGroup = parentGroup;
    if (iconID != null) result.iconID = iconID;
    if (types != null) result.types.addAll(types);
    if (childGroups != null) result.childGroups.addAll(childGroups);
    return result;
  }

  MarketGroups_MarketGroup._();

  factory MarketGroups_MarketGroup.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MarketGroups_MarketGroup.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MarketGroups.MarketGroup',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'market_group'),
      createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..aI(2, _omitFieldNames ? '' : 'parentGroup', protoName: 'parentGroup')
    ..aI(3, _omitFieldNames ? '' : 'iconID', protoName: 'iconID')
    ..p<$core.int>(4, _omitFieldNames ? '' : 'types', $pb.PbFieldType.P3)
    ..p<$core.int>(5, _omitFieldNames ? '' : 'childGroups', $pb.PbFieldType.P3,
        protoName: 'childGroups');

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarketGroups_MarketGroup clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarketGroups_MarketGroup copyWith(
          void Function(MarketGroups_MarketGroup) updates) =>
      super.copyWith((message) => updates(message as MarketGroups_MarketGroup))
          as MarketGroups_MarketGroup;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarketGroups_MarketGroup create() => MarketGroups_MarketGroup._();
  @$core.override
  MarketGroups_MarketGroup createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MarketGroups_MarketGroup getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MarketGroups_MarketGroup>(create);
  static MarketGroups_MarketGroup? _defaultInstance;

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
  $core.int get parentGroup => $_getIZ(1);
  @$pb.TagNumber(2)
  set parentGroup($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasParentGroup() => $_has(1);
  @$pb.TagNumber(2)
  void clearParentGroup() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get iconID => $_getIZ(2);
  @$pb.TagNumber(3)
  set iconID($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasIconID() => $_has(2);
  @$pb.TagNumber(3)
  void clearIconID() => $_clearField(3);

  @$pb.TagNumber(4)
  $pb.PbList<$core.int> get types => $_getList(3);

  @$pb.TagNumber(5)
  $pb.PbList<$core.int> get childGroups => $_getList(4);
}

class MarketGroups extends $pb.GeneratedMessage {
  factory MarketGroups({
    $core.Iterable<$core.MapEntry<$core.int, MarketGroups_MarketGroup>>?
        entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addEntries(entries);
    return result;
  }

  MarketGroups._();

  factory MarketGroups.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory MarketGroups.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MarketGroups',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'market_group'),
      createEmptyInstance: create)
    ..m<$core.int, MarketGroups_MarketGroup>(
        1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'MarketGroups.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: MarketGroups_MarketGroup.create,
        valueDefaultOrMaker: MarketGroups_MarketGroup.getDefault,
        packageName: const $pb.PackageName('market_group'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarketGroups clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  MarketGroups copyWith(void Function(MarketGroups) updates) =>
      super.copyWith((message) => updates(message as MarketGroups))
          as MarketGroups;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarketGroups create() => MarketGroups._();
  @$core.override
  MarketGroups createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static MarketGroups getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<MarketGroups>(create);
  static MarketGroups? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, MarketGroups_MarketGroup> get entries => $_getMap(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
