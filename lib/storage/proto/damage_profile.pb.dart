//
//  Generated code. Do not modify.
//  source: damage_profile.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class DamageProfiles_DamageProfile extends $pb.GeneratedMessage {
  factory DamageProfiles_DamageProfile({
    $core.String? name,
    $core.double? em,
    $core.double? explosive,
    $core.double? kinetic,
    $core.double? thermal,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (em != null) {
      $result.em = em;
    }
    if (explosive != null) {
      $result.explosive = explosive;
    }
    if (kinetic != null) {
      $result.kinetic = kinetic;
    }
    if (thermal != null) {
      $result.thermal = thermal;
    }
    return $result;
  }
  DamageProfiles_DamageProfile._() : super();
  factory DamageProfiles_DamageProfile.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DamageProfiles_DamageProfile.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DamageProfiles.DamageProfile',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'damage_profile'),
      createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'name')
    ..a<$core.double>(2, _omitFieldNames ? '' : 'em', $pb.PbFieldType.QD)
    ..a<$core.double>(3, _omitFieldNames ? '' : 'explosive', $pb.PbFieldType.QD)
    ..a<$core.double>(4, _omitFieldNames ? '' : 'kinetic', $pb.PbFieldType.QD)
    ..a<$core.double>(5, _omitFieldNames ? '' : 'thermal', $pb.PbFieldType.QD);

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DamageProfiles_DamageProfile clone() => DamageProfiles_DamageProfile()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DamageProfiles_DamageProfile copyWith(void Function(DamageProfiles_DamageProfile) updates) =>
      super.copyWith((message) => updates(message as DamageProfiles_DamageProfile))
          as DamageProfiles_DamageProfile;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DamageProfiles_DamageProfile create() => DamageProfiles_DamageProfile._();
  DamageProfiles_DamageProfile createEmptyInstance() => create();
  static $pb.PbList<DamageProfiles_DamageProfile> createRepeated() =>
      $pb.PbList<DamageProfiles_DamageProfile>();
  @$core.pragma('dart2js:noInline')
  static DamageProfiles_DamageProfile getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DamageProfiles_DamageProfile>(create);
  static DamageProfiles_DamageProfile? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get em => $_getN(1);
  @$pb.TagNumber(2)
  set em($core.double v) {
    $_setDouble(1, v);
  }

  @$pb.TagNumber(2)
  $core.bool hasEm() => $_has(1);
  @$pb.TagNumber(2)
  void clearEm() => clearField(2);

  @$pb.TagNumber(3)
  $core.double get explosive => $_getN(2);
  @$pb.TagNumber(3)
  set explosive($core.double v) {
    $_setDouble(2, v);
  }

  @$pb.TagNumber(3)
  $core.bool hasExplosive() => $_has(2);
  @$pb.TagNumber(3)
  void clearExplosive() => clearField(3);

  @$pb.TagNumber(4)
  $core.double get kinetic => $_getN(3);
  @$pb.TagNumber(4)
  set kinetic($core.double v) {
    $_setDouble(3, v);
  }

  @$pb.TagNumber(4)
  $core.bool hasKinetic() => $_has(3);
  @$pb.TagNumber(4)
  void clearKinetic() => clearField(4);

  @$pb.TagNumber(5)
  $core.double get thermal => $_getN(4);
  @$pb.TagNumber(5)
  set thermal($core.double v) {
    $_setDouble(4, v);
  }

  @$pb.TagNumber(5)
  $core.bool hasThermal() => $_has(4);
  @$pb.TagNumber(5)
  void clearThermal() => clearField(5);
}

class DamageProfiles_DamageProfileGroup extends $pb.GeneratedMessage {
  factory DamageProfiles_DamageProfileGroup({
    $core.String? name,
    $core.Iterable<DamageProfiles_DamageProfile>? profiles,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (profiles != null) {
      $result.profiles.addAll(profiles);
    }
    return $result;
  }
  DamageProfiles_DamageProfileGroup._() : super();
  factory DamageProfiles_DamageProfileGroup.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DamageProfiles_DamageProfileGroup.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DamageProfiles.DamageProfileGroup',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'damage_profile'),
      createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'name')
    ..pc<DamageProfiles_DamageProfile>(2, _omitFieldNames ? '' : 'profiles', $pb.PbFieldType.PM,
        subBuilder: DamageProfiles_DamageProfile.create);

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DamageProfiles_DamageProfileGroup clone() =>
      DamageProfiles_DamageProfileGroup()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DamageProfiles_DamageProfileGroup copyWith(
          void Function(DamageProfiles_DamageProfileGroup) updates) =>
      super.copyWith((message) => updates(message as DamageProfiles_DamageProfileGroup))
          as DamageProfiles_DamageProfileGroup;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DamageProfiles_DamageProfileGroup create() => DamageProfiles_DamageProfileGroup._();
  DamageProfiles_DamageProfileGroup createEmptyInstance() => create();
  static $pb.PbList<DamageProfiles_DamageProfileGroup> createRepeated() =>
      $pb.PbList<DamageProfiles_DamageProfileGroup>();
  @$core.pragma('dart2js:noInline')
  static DamageProfiles_DamageProfileGroup getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DamageProfiles_DamageProfileGroup>(create);
  static DamageProfiles_DamageProfileGroup? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) {
    $_setString(0, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<DamageProfiles_DamageProfile> get profiles => $_getList(1);
}

class DamageProfiles extends $pb.GeneratedMessage {
  factory DamageProfiles({
    $core.Iterable<DamageProfiles_DamageProfileGroup>? groups,
  }) {
    final $result = create();
    if (groups != null) {
      $result.groups.addAll(groups);
    }
    return $result;
  }
  DamageProfiles._() : super();
  factory DamageProfiles.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory DamageProfiles.fromJson($core.String i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DamageProfiles',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'damage_profile'),
      createEmptyInstance: create)
    ..pc<DamageProfiles_DamageProfileGroup>(1, _omitFieldNames ? '' : 'groups', $pb.PbFieldType.PM,
        subBuilder: DamageProfiles_DamageProfileGroup.create);

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  DamageProfiles clone() => DamageProfiles()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  DamageProfiles copyWith(void Function(DamageProfiles) updates) =>
      super.copyWith((message) => updates(message as DamageProfiles)) as DamageProfiles;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DamageProfiles create() => DamageProfiles._();
  DamageProfiles createEmptyInstance() => create();
  static $pb.PbList<DamageProfiles> createRepeated() => $pb.PbList<DamageProfiles>();
  @$core.pragma('dart2js:noInline')
  static DamageProfiles getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DamageProfiles>(create);
  static DamageProfiles? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<DamageProfiles_DamageProfileGroup> get groups => $_getList(0);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
