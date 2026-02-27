// This is a generated file - do not edit.
//
// Generated from skills.proto.

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

class Skills_Skill extends $pb.GeneratedMessage {
  factory Skills_Skill({
    $0.I18N? name,
    $core.int? groupID,
    $core.bool? published,
    $core.int? alphaMaxLevel,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (groupID != null) result.groupID = groupID;
    if (published != null) result.published = published;
    if (alphaMaxLevel != null) result.alphaMaxLevel = alphaMaxLevel;
    return result;
  }

  Skills_Skill._();

  factory Skills_Skill.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Skills_Skill.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Skills.Skill',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'skills'),
      createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..aI(2, _omitFieldNames ? '' : 'groupID',
        protoName: 'groupID', fieldType: $pb.PbFieldType.Q3)
    ..a<$core.bool>(3, _omitFieldNames ? '' : 'published', $pb.PbFieldType.QB)
    ..aI(4, _omitFieldNames ? '' : 'alphaMaxLevel', protoName: 'alphaMaxLevel');

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Skills_Skill clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Skills_Skill copyWith(void Function(Skills_Skill) updates) =>
      super.copyWith((message) => updates(message as Skills_Skill))
          as Skills_Skill;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Skills_Skill create() => Skills_Skill._();
  @$core.override
  Skills_Skill createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Skills_Skill getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Skills_Skill>(create);
  static Skills_Skill? _defaultInstance;

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
  $core.int get groupID => $_getIZ(1);
  @$pb.TagNumber(2)
  set groupID($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasGroupID() => $_has(1);
  @$pb.TagNumber(2)
  void clearGroupID() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get published => $_getBF(2);
  @$pb.TagNumber(3)
  set published($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasPublished() => $_has(2);
  @$pb.TagNumber(3)
  void clearPublished() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.int get alphaMaxLevel => $_getIZ(3);
  @$pb.TagNumber(4)
  set alphaMaxLevel($core.int value) => $_setSignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasAlphaMaxLevel() => $_has(3);
  @$pb.TagNumber(4)
  void clearAlphaMaxLevel() => $_clearField(4);
}

class Skills extends $pb.GeneratedMessage {
  factory Skills({
    $core.Iterable<$core.MapEntry<$core.int, Skills_Skill>>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addEntries(entries);
    return result;
  }

  Skills._();

  factory Skills.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Skills.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Skills',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'skills'),
      createEmptyInstance: create)
    ..m<$core.int, Skills_Skill>(1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'Skills.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Skills_Skill.create,
        valueDefaultOrMaker: Skills_Skill.getDefault,
        packageName: const $pb.PackageName('skills'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Skills clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Skills copyWith(void Function(Skills) updates) =>
      super.copyWith((message) => updates(message as Skills)) as Skills;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Skills create() => Skills._();
  @$core.override
  Skills createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Skills getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Skills>(create);
  static Skills? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, Skills_Skill> get entries => $_getMap(0);
}

class TypeSkills_Skill extends $pb.GeneratedMessage {
  factory TypeSkills_Skill({
    $core.int? id,
    $core.int? level,
  }) {
    final result = create();
    if (id != null) result.id = id;
    if (level != null) result.level = level;
    return result;
  }

  TypeSkills_Skill._();

  factory TypeSkills_Skill.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TypeSkills_Skill.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TypeSkills.Skill',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'skills'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'id', fieldType: $pb.PbFieldType.Q3)
    ..aI(2, _omitFieldNames ? '' : 'level', fieldType: $pb.PbFieldType.Q3);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TypeSkills_Skill clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TypeSkills_Skill copyWith(void Function(TypeSkills_Skill) updates) =>
      super.copyWith((message) => updates(message as TypeSkills_Skill))
          as TypeSkills_Skill;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TypeSkills_Skill create() => TypeSkills_Skill._();
  @$core.override
  TypeSkills_Skill createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TypeSkills_Skill getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TypeSkills_Skill>(create);
  static TypeSkills_Skill? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get id => $_getIZ(0);
  @$pb.TagNumber(1)
  set id($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasId() => $_has(0);
  @$pb.TagNumber(1)
  void clearId() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get level => $_getIZ(1);
  @$pb.TagNumber(2)
  set level($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasLevel() => $_has(1);
  @$pb.TagNumber(2)
  void clearLevel() => $_clearField(2);
}

class TypeSkills_TypeSkill extends $pb.GeneratedMessage {
  factory TypeSkills_TypeSkill({
    $core.Iterable<TypeSkills_Skill>? skills,
  }) {
    final result = create();
    if (skills != null) result.skills.addAll(skills);
    return result;
  }

  TypeSkills_TypeSkill._();

  factory TypeSkills_TypeSkill.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TypeSkills_TypeSkill.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TypeSkills.TypeSkill',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'skills'),
      createEmptyInstance: create)
    ..pPM<TypeSkills_Skill>(1, _omitFieldNames ? '' : 'skills',
        subBuilder: TypeSkills_Skill.create);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TypeSkills_TypeSkill clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TypeSkills_TypeSkill copyWith(void Function(TypeSkills_TypeSkill) updates) =>
      super.copyWith((message) => updates(message as TypeSkills_TypeSkill))
          as TypeSkills_TypeSkill;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TypeSkills_TypeSkill create() => TypeSkills_TypeSkill._();
  @$core.override
  TypeSkills_TypeSkill createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TypeSkills_TypeSkill getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TypeSkills_TypeSkill>(create);
  static TypeSkills_TypeSkill? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<TypeSkills_Skill> get skills => $_getList(0);
}

class TypeSkills extends $pb.GeneratedMessage {
  factory TypeSkills({
    $core.Iterable<$core.MapEntry<$core.int, TypeSkills_TypeSkill>>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addEntries(entries);
    return result;
  }

  TypeSkills._();

  factory TypeSkills.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory TypeSkills.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'TypeSkills',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'skills'),
      createEmptyInstance: create)
    ..m<$core.int, TypeSkills_TypeSkill>(1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'TypeSkills.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: TypeSkills_TypeSkill.create,
        valueDefaultOrMaker: TypeSkills_TypeSkill.getDefault,
        packageName: const $pb.PackageName('skills'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TypeSkills clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  TypeSkills copyWith(void Function(TypeSkills) updates) =>
      super.copyWith((message) => updates(message as TypeSkills)) as TypeSkills;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static TypeSkills create() => TypeSkills._();
  @$core.override
  TypeSkills createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static TypeSkills getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<TypeSkills>(create);
  static TypeSkills? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, TypeSkills_TypeSkill> get entries => $_getMap(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
