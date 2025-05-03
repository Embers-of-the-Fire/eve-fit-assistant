//
//  Generated code. Do not modify.
//  source: types.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'i18n.pb.dart' as $0;

class Types_Type extends $pb.GeneratedMessage {
  factory Types_Type({
    $0.I18N? name,
    $core.int? groupID,
    $core.int? marketGroupID,
    $core.bool? published,
    $core.String? description,
    $core.String? traits,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (groupID != null) {
      $result.groupID = groupID;
    }
    if (marketGroupID != null) {
      $result.marketGroupID = marketGroupID;
    }
    if (published != null) {
      $result.published = published;
    }
    if (description != null) {
      $result.description = description;
    }
    if (traits != null) {
      $result.traits = traits;
    }
    return $result;
  }
  Types_Type._() : super();
  factory Types_Type.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Types_Type.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Types.Type', package: const $pb.PackageName(_omitMessageNames ? '' : 'types'), createEmptyInstance: create)
    ..aQM<$0.I18N>(1, _omitFieldNames ? '' : 'name', subBuilder: $0.I18N.create)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'groupID', $pb.PbFieldType.Q3, protoName: 'groupID')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'marketGroupID', $pb.PbFieldType.O3, protoName: 'marketGroupID')
    ..a<$core.bool>(4, _omitFieldNames ? '' : 'published', $pb.PbFieldType.QB)
    ..aQS(5, _omitFieldNames ? '' : 'description')
    ..aQS(6, _omitFieldNames ? '' : 'traits')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Types_Type clone() => Types_Type()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Types_Type copyWith(void Function(Types_Type) updates) => super.copyWith((message) => updates(message as Types_Type)) as Types_Type;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Types_Type create() => Types_Type._();
  Types_Type createEmptyInstance() => create();
  static $pb.PbList<Types_Type> createRepeated() => $pb.PbList<Types_Type>();
  @$core.pragma('dart2js:noInline')
  static Types_Type getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Types_Type>(create);
  static Types_Type? _defaultInstance;

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
  $core.int get marketGroupID => $_getIZ(2);
  @$pb.TagNumber(3)
  set marketGroupID($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasMarketGroupID() => $_has(2);
  @$pb.TagNumber(3)
  void clearMarketGroupID() => clearField(3);

  @$pb.TagNumber(4)
  $core.bool get published => $_getBF(3);
  @$pb.TagNumber(4)
  set published($core.bool v) { $_setBool(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasPublished() => $_has(3);
  @$pb.TagNumber(4)
  void clearPublished() => clearField(4);

  /// this might be i18n.I18N in the future, but not now.
  @$pb.TagNumber(5)
  $core.String get description => $_getSZ(4);
  @$pb.TagNumber(5)
  set description($core.String v) { $_setString(4, v); }
  @$pb.TagNumber(5)
  $core.bool hasDescription() => $_has(4);
  @$pb.TagNumber(5)
  void clearDescription() => clearField(5);

  @$pb.TagNumber(6)
  $core.String get traits => $_getSZ(5);
  @$pb.TagNumber(6)
  set traits($core.String v) { $_setString(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasTraits() => $_has(5);
  @$pb.TagNumber(6)
  void clearTraits() => clearField(6);
}

class Types extends $pb.GeneratedMessage {
  factory Types({
    $core.Map<$core.int, Types_Type>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  Types._() : super();
  factory Types.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Types.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Types', package: const $pb.PackageName(_omitMessageNames ? '' : 'types'), createEmptyInstance: create)
    ..m<$core.int, Types_Type>(1, _omitFieldNames ? '' : 'entries', entryClassName: 'Types.EntriesEntry', keyFieldType: $pb.PbFieldType.O3, valueFieldType: $pb.PbFieldType.OM, valueCreator: Types_Type.create, valueDefaultOrMaker: Types_Type.getDefault, packageName: const $pb.PackageName('types'))
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Types clone() => Types()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Types copyWith(void Function(Types) updates) => super.copyWith((message) => updates(message as Types)) as Types;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Types create() => Types._();
  Types createEmptyInstance() => create();
  static $pb.PbList<Types> createRepeated() => $pb.PbList<Types>();
  @$core.pragma('dart2js:noInline')
  static Types getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Types>(create);
  static Types? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, Types_Type> get entries => $_getMap(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
