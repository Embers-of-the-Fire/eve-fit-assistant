// This is a generated file - do not edit.
//
// Generated from damage_profile.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class DamageProfiles_DamageProfile extends $pb.GeneratedMessage {
  factory DamageProfiles_DamageProfile({
    $core.String? name,
    $core.double? em,
    $core.double? explosive,
    $core.double? kinetic,
    $core.double? thermal,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (em != null) result.em = em;
    if (explosive != null) result.explosive = explosive;
    if (kinetic != null) result.kinetic = kinetic;
    if (thermal != null) result.thermal = thermal;
    return result;
  }

  DamageProfiles_DamageProfile._();

  factory DamageProfiles_DamageProfile.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DamageProfiles_DamageProfile.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DamageProfiles.DamageProfile',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'damage_profile'),
      createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'name')
    ..aD(2, _omitFieldNames ? '' : 'em', fieldType: $pb.PbFieldType.QD)
    ..aD(3, _omitFieldNames ? '' : 'explosive', fieldType: $pb.PbFieldType.QD)
    ..aD(4, _omitFieldNames ? '' : 'kinetic', fieldType: $pb.PbFieldType.QD)
    ..aD(5, _omitFieldNames ? '' : 'thermal', fieldType: $pb.PbFieldType.QD);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DamageProfiles_DamageProfile clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DamageProfiles_DamageProfile copyWith(
          void Function(DamageProfiles_DamageProfile) updates) =>
      super.copyWith(
              (message) => updates(message as DamageProfiles_DamageProfile))
          as DamageProfiles_DamageProfile;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DamageProfiles_DamageProfile create() =>
      DamageProfiles_DamageProfile._();
  @$core.override
  DamageProfiles_DamageProfile createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DamageProfiles_DamageProfile getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DamageProfiles_DamageProfile>(create);
  static DamageProfiles_DamageProfile? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get em => $_getN(1);
  @$pb.TagNumber(2)
  set em($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasEm() => $_has(1);
  @$pb.TagNumber(2)
  void clearEm() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.double get explosive => $_getN(2);
  @$pb.TagNumber(3)
  set explosive($core.double value) => $_setDouble(2, value);
  @$pb.TagNumber(3)
  $core.bool hasExplosive() => $_has(2);
  @$pb.TagNumber(3)
  void clearExplosive() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.double get kinetic => $_getN(3);
  @$pb.TagNumber(4)
  set kinetic($core.double value) => $_setDouble(3, value);
  @$pb.TagNumber(4)
  $core.bool hasKinetic() => $_has(3);
  @$pb.TagNumber(4)
  void clearKinetic() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.double get thermal => $_getN(4);
  @$pb.TagNumber(5)
  set thermal($core.double value) => $_setDouble(4, value);
  @$pb.TagNumber(5)
  $core.bool hasThermal() => $_has(4);
  @$pb.TagNumber(5)
  void clearThermal() => $_clearField(5);
}

class DamageProfiles_DamageProfileGroup extends $pb.GeneratedMessage {
  factory DamageProfiles_DamageProfileGroup({
    $core.String? name,
    $core.Iterable<DamageProfiles_DamageProfile>? profiles,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (profiles != null) result.profiles.addAll(profiles);
    return result;
  }

  DamageProfiles_DamageProfileGroup._();

  factory DamageProfiles_DamageProfileGroup.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DamageProfiles_DamageProfileGroup.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DamageProfiles.DamageProfileGroup',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'damage_profile'),
      createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'name')
    ..pPM<DamageProfiles_DamageProfile>(2, _omitFieldNames ? '' : 'profiles',
        subBuilder: DamageProfiles_DamageProfile.create);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DamageProfiles_DamageProfileGroup clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DamageProfiles_DamageProfileGroup copyWith(
          void Function(DamageProfiles_DamageProfileGroup) updates) =>
      super.copyWith((message) =>
              updates(message as DamageProfiles_DamageProfileGroup))
          as DamageProfiles_DamageProfileGroup;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DamageProfiles_DamageProfileGroup create() =>
      DamageProfiles_DamageProfileGroup._();
  @$core.override
  DamageProfiles_DamageProfileGroup createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DamageProfiles_DamageProfileGroup getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DamageProfiles_DamageProfileGroup>(
          create);
  static DamageProfiles_DamageProfileGroup? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<DamageProfiles_DamageProfile> get profiles => $_getList(1);
}

class DamageProfiles extends $pb.GeneratedMessage {
  factory DamageProfiles({
    $core.Iterable<DamageProfiles_DamageProfileGroup>? groups,
  }) {
    final result = create();
    if (groups != null) result.groups.addAll(groups);
    return result;
  }

  DamageProfiles._();

  factory DamageProfiles.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DamageProfiles.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DamageProfiles',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'damage_profile'),
      createEmptyInstance: create)
    ..pPM<DamageProfiles_DamageProfileGroup>(1, _omitFieldNames ? '' : 'groups',
        subBuilder: DamageProfiles_DamageProfileGroup.create);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DamageProfiles clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DamageProfiles copyWith(void Function(DamageProfiles) updates) =>
      super.copyWith((message) => updates(message as DamageProfiles))
          as DamageProfiles;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DamageProfiles create() => DamageProfiles._();
  @$core.override
  DamageProfiles createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DamageProfiles getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DamageProfiles>(create);
  static DamageProfiles? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<DamageProfiles_DamageProfileGroup> get groups => $_getList(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
