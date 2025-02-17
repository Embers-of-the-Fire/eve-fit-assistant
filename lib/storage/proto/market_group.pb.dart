//
//  Generated code. Do not modify.
//  source: market_group.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'i18n.pb.dart' as $0;

class MarketGroups_MarketGroup extends $pb.GeneratedMessage {
  factory MarketGroups_MarketGroup({
    $0.I18N? name,
    $core.int? parentGroup,
    $core.int? iconID,
    $core.Iterable<$core.int>? types,
    $core.Iterable<$core.int>? childGroups,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (parentGroup != null) {
      $result.parentGroup = parentGroup;
    }
    if (iconID != null) {
      $result.iconID = iconID;
    }
    if (types != null) {
      $result.types.addAll(types);
    }
    if (childGroups != null) {
      $result.childGroups.addAll(childGroups);
    }
    return $result;
  }

  MarketGroups_MarketGroup._() : super();

  factory MarketGroups_MarketGroup.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  factory MarketGroups_MarketGroup.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'MarketGroups.MarketGroup',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'market_group'),
      createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'parentGroup', $pb.PbFieldType.O3,
        protoName: 'parentGroup')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'iconID', $pb.PbFieldType.O3, protoName: 'iconID')
    ..p<$core.int>(4, _omitFieldNames ? '' : 'types', $pb.PbFieldType.P3)
    ..p<$core.int>(5, _omitFieldNames ? '' : 'childGroups', $pb.PbFieldType.P3,
        protoName: 'childGroups');

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  MarketGroups_MarketGroup clone() => MarketGroups_MarketGroup()..mergeFromMessage(this);

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  MarketGroups_MarketGroup copyWith(void Function(MarketGroups_MarketGroup) updates) =>
      super.copyWith((message) => updates(message as MarketGroups_MarketGroup))
          as MarketGroups_MarketGroup;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarketGroups_MarketGroup create() => MarketGroups_MarketGroup._();

  MarketGroups_MarketGroup createEmptyInstance() => create();

  static $pb.PbList<MarketGroups_MarketGroup> createRepeated() =>
      $pb.PbList<MarketGroups_MarketGroup>();

  @$core.pragma('dart2js:noInline')
  static MarketGroups_MarketGroup getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MarketGroups_MarketGroup>(create);
  static MarketGroups_MarketGroup? _defaultInstance;

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
  $core.int get parentGroup => $_getIZ(1);

  @$pb.TagNumber(2)
  set parentGroup($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasParentGroup() => $_has(1);

  @$pb.TagNumber(2)
  void clearParentGroup() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get iconID => $_getIZ(2);

  @$pb.TagNumber(3)
  set iconID($core.int v) {
    $_setSignedInt32(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasIconID() => $_has(2);

  @$pb.TagNumber(3)
  void clearIconID() => clearField(3);

  @$pb.TagNumber(4)
  $core.List<$core.int> get types => $_getList(3);

  @$pb.TagNumber(5)
  $core.List<$core.int> get childGroups => $_getList(4);
}

class MarketGroups extends $pb.GeneratedMessage {
  factory MarketGroups({
    $core.Map<$core.int, MarketGroups_MarketGroup>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }

  MarketGroups._() : super();

  factory MarketGroups.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);

  factory MarketGroups.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MarketGroups',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'market_group'),
      createEmptyInstance: create)
    ..m<$core.int, MarketGroups_MarketGroup>(1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'MarketGroups.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: MarketGroups_MarketGroup.create,
        valueDefaultOrMaker: MarketGroups_MarketGroup.getDefault,
        packageName: const $pb.PackageName('market_group'));

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  MarketGroups clone() => MarketGroups()..mergeFromMessage(this);

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  MarketGroups copyWith(void Function(MarketGroups) updates) =>
      super.copyWith((message) => updates(message as MarketGroups)) as MarketGroups;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MarketGroups create() => MarketGroups._();

  MarketGroups createEmptyInstance() => create();

  static $pb.PbList<MarketGroups> createRepeated() => $pb.PbList<MarketGroups>();

  @$core.pragma('dart2js:noInline')
  static MarketGroups getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MarketGroups>(create);
  static MarketGroups? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, MarketGroups_MarketGroup> get entries => $_getMap(0);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
