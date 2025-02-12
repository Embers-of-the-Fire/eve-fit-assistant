//
//  Generated code. Do not modify.
//  source: skills.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'i18n.pb.dart' as $0;

class Skills_Skill extends $pb.GeneratedMessage {
  factory Skills_Skill({
    $0.I18N? name,
    $core.int? groupID,
    $core.bool? published,
    $core.int? alphaMaxLevel,
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
    if (alphaMaxLevel != null) {
      $result.alphaMaxLevel = alphaMaxLevel;
    }
    return $result;
  }
  Skills_Skill._() : super();
  factory Skills_Skill.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Skills_Skill.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Skills.Skill', package: const $pb.PackageName(_omitMessageNames ? '' : 'skills'), createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'groupID', $pb.PbFieldType.Q3, protoName: 'groupID')
    ..a<$core.bool>(3, _omitFieldNames ? '' : 'published', $pb.PbFieldType.QB)
    ..a<$core.int>(4, _omitFieldNames ? '' : 'alphaMaxLevel', $pb.PbFieldType.O3, protoName: 'alphaMaxLevel')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Skills_Skill clone() => Skills_Skill()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Skills_Skill copyWith(void Function(Skills_Skill) updates) => super.copyWith((message) => updates(message as Skills_Skill)) as Skills_Skill;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Skills_Skill create() => Skills_Skill._();
  Skills_Skill createEmptyInstance() => create();
  static $pb.PbList<Skills_Skill> createRepeated() => $pb.PbList<Skills_Skill>();
  @$core.pragma('dart2js:noInline')
  static Skills_Skill getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Skills_Skill>(create);
  static Skills_Skill? _defaultInstance;

  @$pb.TagNumber(1)
  $0.I18N get name => $_getN(0);
  @$pb.TagNumber(1)
  set name($0.I18N v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);
  @$pb.TagNumber(1)
  $0.I18N ensureName() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.int get groupID => $_getIZ(1);
  @$pb.TagNumber(2)
  set groupID($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasGroupID() => $_has(1);
  @$pb.TagNumber(2)
  void clearGroupID() => clearField(2);

  @$pb.TagNumber(3)
  $core.bool get published => $_getBF(2);
  @$pb.TagNumber(3)
  set published($core.bool v) { $_setBool(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasPublished() => $_has(2);
  @$pb.TagNumber(3)
  void clearPublished() => clearField(3);

  @$pb.TagNumber(4)
  $core.int get alphaMaxLevel => $_getIZ(3);
  @$pb.TagNumber(4)
  set alphaMaxLevel($core.int v) { $_setSignedInt32(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasAlphaMaxLevel() => $_has(3);
  @$pb.TagNumber(4)
  void clearAlphaMaxLevel() => clearField(4);
}

class Skills extends $pb.GeneratedMessage {
  factory Skills({
    $core.Map<$core.int, Skills_Skill>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  Skills._() : super();
  factory Skills.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Skills.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Skills', package: const $pb.PackageName(_omitMessageNames ? '' : 'skills'), createEmptyInstance: create)
    ..m<$core.int, Skills_Skill>(1, _omitFieldNames ? '' : 'entries', entryClassName: 'Skills.EntriesEntry', keyFieldType: $pb.PbFieldType.O3, valueFieldType: $pb.PbFieldType.OM, valueCreator: Skills_Skill.create, valueDefaultOrMaker: Skills_Skill.getDefault, packageName: const $pb.PackageName('skills'))
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Skills clone() => Skills()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Skills copyWith(void Function(Skills) updates) => super.copyWith((message) => updates(message as Skills)) as Skills;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Skills create() => Skills._();
  Skills createEmptyInstance() => create();
  static $pb.PbList<Skills> createRepeated() => $pb.PbList<Skills>();
  @$core.pragma('dart2js:noInline')
  static Skills getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Skills>(create);
  static Skills? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, Skills_Skill> get entries => $_getMap(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
