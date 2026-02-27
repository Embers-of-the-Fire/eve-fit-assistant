// This is a generated file - do not edit.
//
// Generated from types.proto.

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

class Types_Type extends $pb.GeneratedMessage {
  factory Types_Type({
    $0.I18N? name,
    $core.int? groupID,
    $core.int? marketGroupID,
    $core.bool? published,
    $core.String? description,
    $core.String? traits,
  }) {
    final result = create();
    if (name != null) result.name = name;
    if (groupID != null) result.groupID = groupID;
    if (marketGroupID != null) result.marketGroupID = marketGroupID;
    if (published != null) result.published = published;
    if (description != null) result.description = description;
    if (traits != null) result.traits = traits;
    return result;
  }

  Types_Type._();

  factory Types_Type.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Types_Type.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Types.Type',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'types'),
      createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..aI(2, _omitFieldNames ? '' : 'groupID',
        protoName: 'groupID', fieldType: $pb.PbFieldType.Q3)
    ..aI(3, _omitFieldNames ? '' : 'marketGroupID', protoName: 'marketGroupID')
    ..a<$core.bool>(4, _omitFieldNames ? '' : 'published', $pb.PbFieldType.QB)
    ..aQS(5, _omitFieldNames ? '' : 'description')
    ..aQS(6, _omitFieldNames ? '' : 'traits');

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Types_Type clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Types_Type copyWith(void Function(Types_Type) updates) =>
      super.copyWith((message) => updates(message as Types_Type)) as Types_Type;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Types_Type create() => Types_Type._();
  @$core.override
  Types_Type createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Types_Type getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Types_Type>(create);
  static Types_Type? _defaultInstance;

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
  $core.int get marketGroupID => $_getIZ(2);
  @$pb.TagNumber(3)
  set marketGroupID($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasMarketGroupID() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarketGroupID() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get published => $_getBF(3);
  @$pb.TagNumber(4)
  set published($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasPublished() => $_has(3);
  @$pb.TagNumber(4)
  void clearPublished() => $_clearField(4);

  /// this might be i18n.I18N in the future, but not now.
  @$pb.TagNumber(5)
  $core.String get description => $_getSZ(4);
  @$pb.TagNumber(5)
  set description($core.String value) => $_setString(4, value);
  @$pb.TagNumber(5)
  $core.bool hasDescription() => $_has(4);
  @$pb.TagNumber(5)
  void clearDescription() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.String get traits => $_getSZ(5);
  @$pb.TagNumber(6)
  set traits($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasTraits() => $_has(5);
  @$pb.TagNumber(6)
  void clearTraits() => $_clearField(6);
}

class Types extends $pb.GeneratedMessage {
  factory Types({
    $core.Iterable<$core.MapEntry<$core.int, Types_Type>>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addEntries(entries);
    return result;
  }

  Types._();

  factory Types.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Types.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Types',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'types'),
      createEmptyInstance: create)
    ..m<$core.int, Types_Type>(1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'Types.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Types_Type.create,
        valueDefaultOrMaker: Types_Type.getDefault,
        packageName: const $pb.PackageName('types'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Types clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Types copyWith(void Function(Types) updates) =>
      super.copyWith((message) => updates(message as Types)) as Types;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Types create() => Types._();
  @$core.override
  Types createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Types getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Types>(create);
  static Types? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, Types_Type> get entries => $_getMap(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
