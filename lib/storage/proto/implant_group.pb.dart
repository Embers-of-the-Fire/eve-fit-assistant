//
//  Generated code. Do not modify.
//  source: implant_group.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class ImplantGroups_ImplantGroup extends $pb.GeneratedMessage {
  factory ImplantGroups_ImplantGroup({
    $core.String? name,
    $core.Iterable<ImplantGroups_ImplantSubGroup>? groups,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (groups != null) {
      $result.groups.addAll(groups);
    }
    return $result;
  }
  ImplantGroups_ImplantGroup._() : super();
  factory ImplantGroups_ImplantGroup.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ImplantGroups_ImplantGroup.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ImplantGroups.ImplantGroup', package: const $pb.PackageName(_omitMessageNames ? '' : 'market_group'), createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'name')
    ..pc<ImplantGroups_ImplantSubGroup>(2, _omitFieldNames ? '' : 'groups', $pb.PbFieldType.PM, subBuilder: ImplantGroups_ImplantSubGroup.create)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ImplantGroups_ImplantGroup clone() => ImplantGroups_ImplantGroup()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ImplantGroups_ImplantGroup copyWith(void Function(ImplantGroups_ImplantGroup) updates) => super.copyWith((message) => updates(message as ImplantGroups_ImplantGroup)) as ImplantGroups_ImplantGroup;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImplantGroups_ImplantGroup create() => ImplantGroups_ImplantGroup._();
  ImplantGroups_ImplantGroup createEmptyInstance() => create();
  static $pb.PbList<ImplantGroups_ImplantGroup> createRepeated() => $pb.PbList<ImplantGroups_ImplantGroup>();
  @$core.pragma('dart2js:noInline')
  static ImplantGroups_ImplantGroup getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ImplantGroups_ImplantGroup>(create);
  static ImplantGroups_ImplantGroup? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<ImplantGroups_ImplantSubGroup> get groups => $_getList(1);
}

class ImplantGroups_ImplantSubGroup extends $pb.GeneratedMessage {
  factory ImplantGroups_ImplantSubGroup({
    $core.String? name,
    $core.Iterable<$core.int>? items,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (items != null) {
      $result.items.addAll(items);
    }
    return $result;
  }
  ImplantGroups_ImplantSubGroup._() : super();
  factory ImplantGroups_ImplantSubGroup.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ImplantGroups_ImplantSubGroup.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ImplantGroups.ImplantSubGroup', package: const $pb.PackageName(_omitMessageNames ? '' : 'market_group'), createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'name')
    ..p<$core.int>(2, _omitFieldNames ? '' : 'items', $pb.PbFieldType.P3)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ImplantGroups_ImplantSubGroup clone() => ImplantGroups_ImplantSubGroup()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ImplantGroups_ImplantSubGroup copyWith(void Function(ImplantGroups_ImplantSubGroup) updates) => super.copyWith((message) => updates(message as ImplantGroups_ImplantSubGroup)) as ImplantGroups_ImplantSubGroup;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImplantGroups_ImplantSubGroup create() => ImplantGroups_ImplantSubGroup._();
  ImplantGroups_ImplantSubGroup createEmptyInstance() => create();
  static $pb.PbList<ImplantGroups_ImplantSubGroup> createRepeated() => $pb.PbList<ImplantGroups_ImplantSubGroup>();
  @$core.pragma('dart2js:noInline')
  static ImplantGroups_ImplantSubGroup getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ImplantGroups_ImplantSubGroup>(create);
  static ImplantGroups_ImplantSubGroup? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get items => $_getList(1);
}

class ImplantGroups extends $pb.GeneratedMessage {
  factory ImplantGroups({
    $core.Iterable<ImplantGroups_ImplantGroup>? groups,
  }) {
    final $result = create();
    if (groups != null) {
      $result.groups.addAll(groups);
    }
    return $result;
  }
  ImplantGroups._() : super();
  factory ImplantGroups.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory ImplantGroups.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'ImplantGroups', package: const $pb.PackageName(_omitMessageNames ? '' : 'market_group'), createEmptyInstance: create)
    ..pc<ImplantGroups_ImplantGroup>(1, _omitFieldNames ? '' : 'groups', $pb.PbFieldType.PM, subBuilder: ImplantGroups_ImplantGroup.create)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  ImplantGroups clone() => ImplantGroups()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  ImplantGroups copyWith(void Function(ImplantGroups) updates) => super.copyWith((message) => updates(message as ImplantGroups)) as ImplantGroups;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static ImplantGroups create() => ImplantGroups._();
  ImplantGroups createEmptyInstance() => create();
  static $pb.PbList<ImplantGroups> createRepeated() => $pb.PbList<ImplantGroups>();
  @$core.pragma('dart2js:noInline')
  static ImplantGroups getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<ImplantGroups>(create);
  static ImplantGroups? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<ImplantGroups_ImplantGroup> get groups => $_getList(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
