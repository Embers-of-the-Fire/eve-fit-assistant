//
//  Generated code. Do not modify.
//  source: groups.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'i18n.pb.dart' as $0;

class Groups_Group extends $pb.GeneratedMessage {
  factory Groups_Group({
    $0.I18N? name,
    $core.int? categoryID,
    $core.bool? published,
    $core.Iterable<$core.int>? types,
    $core.Iterable<$core.int>? relatedMarketGroups,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (categoryID != null) {
      $result.categoryID = categoryID;
    }
    if (published != null) {
      $result.published = published;
    }
    if (types != null) {
      $result.types.addAll(types);
    }
    if (relatedMarketGroups != null) {
      $result.relatedMarketGroups.addAll(relatedMarketGroups);
    }
    return $result;
  }
  Groups_Group._() : super();
  factory Groups_Group.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Groups_Group.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Groups.Group',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'groups'),
      createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'categoryID', $pb.PbFieldType.Q3,
        protoName: 'categoryID')
    ..a<$core.bool>(3, _omitFieldNames ? '' : 'published', $pb.PbFieldType.QB)
    ..p<$core.int>(4, _omitFieldNames ? '' : 'types', $pb.PbFieldType.P3)
    ..p<$core.int>(5, _omitFieldNames ? '' : 'relatedMarketGroups', $pb.PbFieldType.P3,
        protoName: 'relatedMarketGroups');

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Groups_Group clone() => Groups_Group()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Groups_Group copyWith(void Function(Groups_Group) updates) =>
      super.copyWith((message) => updates(message as Groups_Group)) as Groups_Group;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Groups_Group create() => Groups_Group._();
  Groups_Group createEmptyInstance() => create();
  static $pb.PbList<Groups_Group> createRepeated() => $pb.PbList<Groups_Group>();
  @$core.pragma('dart2js:noInline')
  static Groups_Group getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Groups_Group>(create);
  static Groups_Group? _defaultInstance;

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
  $core.int get categoryID => $_getIZ(1);
  @$pb.TagNumber(2)
  set categoryID($core.int v) {
    $_setSignedInt32(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasCategoryID() => $_has(1);
  @$pb.TagNumber(2)
  void clearCategoryID() => clearField(2);

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
  $core.List<$core.int> get types => $_getList(3);

  @$pb.TagNumber(5)
  $core.List<$core.int> get relatedMarketGroups => $_getList(4);
}

class Groups extends $pb.GeneratedMessage {
  factory Groups({
    $core.Map<$core.int, Groups_Group>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  Groups._() : super();
  factory Groups.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory Groups.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Groups',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'groups'),
      createEmptyInstance: create)
    ..m<$core.int, Groups_Group>(1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'Groups.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Groups_Group.create,
        valueDefaultOrMaker: Groups_Group.getDefault,
        packageName: const $pb.PackageName('groups'));

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  Groups clone() => Groups()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  Groups copyWith(void Function(Groups) updates) =>
      super.copyWith((message) => updates(message as Groups)) as Groups;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Groups create() => Groups._();
  Groups createEmptyInstance() => create();
  static $pb.PbList<Groups> createRepeated() => $pb.PbList<Groups>();
  @$core.pragma('dart2js:noInline')
  static Groups getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Groups>(create);
  static Groups? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, Groups_Group> get entries => $_getMap(0);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
