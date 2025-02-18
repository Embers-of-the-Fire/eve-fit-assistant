//
//  Generated code. Do not modify.
//  source: attribute.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'i18n.pb.dart' as $0;

class Attributes_Attribute extends $pb.GeneratedMessage {
  factory Attributes_Attribute({
    $core.String? name,
    $core.double? defaultValue,
    $core.int? categoryID,
    $core.String? description,
    $0.I18N? displayName,
    $core.bool? highIsGood,
    $core.int? iconID,
    $core.bool? published,
    $core.int? unitID,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (defaultValue != null) {
      $result.defaultValue = defaultValue;
    }
    if (categoryID != null) {
      $result.categoryID = categoryID;
    }
    if (description != null) {
      $result.description = description;
    }
    if (displayName != null) {
      $result.displayName = displayName;
    }
    if (highIsGood != null) {
      $result.highIsGood = highIsGood;
    }
    if (iconID != null) {
      $result.iconID = iconID;
    }
    if (published != null) {
      $result.published = published;
    }
    if (unitID != null) {
      $result.unitID = unitID;
    }
    return $result;
  }
  Attributes_Attribute._() : super();
  factory Attributes_Attribute.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Attributes_Attribute.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Attributes.Attribute', package: const $pb.PackageName(_omitMessageNames ? '' : 'attribute'), createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'name')
    ..a<$core.double>(2, _omitFieldNames ? '' : 'defaultValue', $pb.PbFieldType.OD, protoName: 'defaultValue')
    ..a<$core.int>(3, _omitFieldNames ? '' : 'categoryID', $pb.PbFieldType.O3, protoName: 'categoryID')
    ..aOS(4, _omitFieldNames ? '' : 'description')
    ..aOM<$0.I18N>(5, _omitFieldNames ? '' : 'displayName', protoName: 'displayName', subBuilder: $0.I18N.create)
    ..a<$core.bool>(6, _omitFieldNames ? '' : 'highIsGood', $pb.PbFieldType.QB, protoName: 'highIsGood')
    ..a<$core.int>(7, _omitFieldNames ? '' : 'iconID', $pb.PbFieldType.O3, protoName: 'iconID')
    ..a<$core.bool>(8, _omitFieldNames ? '' : 'published', $pb.PbFieldType.QB)
    ..a<$core.int>(9, _omitFieldNames ? '' : 'unitID', $pb.PbFieldType.O3, protoName: 'unitID')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Attributes_Attribute clone() => Attributes_Attribute()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Attributes_Attribute copyWith(void Function(Attributes_Attribute) updates) => super.copyWith((message) => updates(message as Attributes_Attribute)) as Attributes_Attribute;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Attributes_Attribute create() => Attributes_Attribute._();
  Attributes_Attribute createEmptyInstance() => create();
  static $pb.PbList<Attributes_Attribute> createRepeated() => $pb.PbList<Attributes_Attribute>();
  @$core.pragma('dart2js:noInline')
  static Attributes_Attribute getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Attributes_Attribute>(create);
  static Attributes_Attribute? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get defaultValue => $_getN(1);
  @$pb.TagNumber(2)
  set defaultValue($core.double v) { $_setDouble(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasDefaultValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearDefaultValue() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get categoryID => $_getIZ(2);
  @$pb.TagNumber(3)
  set categoryID($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasCategoryID() => $_has(2);
  @$pb.TagNumber(3)
  void clearCategoryID() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get description => $_getSZ(3);
  @$pb.TagNumber(4)
  set description($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasDescription() => $_has(3);
  @$pb.TagNumber(4)
  void clearDescription() => clearField(4);

  @$pb.TagNumber(5)
  $0.I18N get displayName => $_getN(4);
  @$pb.TagNumber(5)
  set displayName($0.I18N v) { setField(5, v); }
  @$pb.TagNumber(5)
  $core.bool hasDisplayName() => $_has(4);
  @$pb.TagNumber(5)
  void clearDisplayName() => clearField(5);
  @$pb.TagNumber(5)
  $0.I18N ensureDisplayName() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.bool get highIsGood => $_getBF(5);
  @$pb.TagNumber(6)
  set highIsGood($core.bool v) { $_setBool(5, v); }
  @$pb.TagNumber(6)
  $core.bool hasHighIsGood() => $_has(5);
  @$pb.TagNumber(6)
  void clearHighIsGood() => clearField(6);

  @$pb.TagNumber(7)
  $core.int get iconID => $_getIZ(6);
  @$pb.TagNumber(7)
  set iconID($core.int v) { $_setSignedInt32(6, v); }
  @$pb.TagNumber(7)
  $core.bool hasIconID() => $_has(6);
  @$pb.TagNumber(7)
  void clearIconID() => clearField(7);

  @$pb.TagNumber(8)
  $core.bool get published => $_getBF(7);
  @$pb.TagNumber(8)
  set published($core.bool v) { $_setBool(7, v); }
  @$pb.TagNumber(8)
  $core.bool hasPublished() => $_has(7);
  @$pb.TagNumber(8)
  void clearPublished() => clearField(8);

  @$pb.TagNumber(9)
  $core.int get unitID => $_getIZ(8);
  @$pb.TagNumber(9)
  set unitID($core.int v) { $_setSignedInt32(8, v); }
  @$pb.TagNumber(9)
  $core.bool hasUnitID() => $_has(8);
  @$pb.TagNumber(9)
  void clearUnitID() => clearField(9);
}

class Attributes extends $pb.GeneratedMessage {
  factory Attributes({
    $core.Map<$core.int, Attributes_Attribute>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  Attributes._() : super();
  factory Attributes.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Attributes.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Attributes', package: const $pb.PackageName(_omitMessageNames ? '' : 'attribute'), createEmptyInstance: create)
    ..m<$core.int, Attributes_Attribute>(1, _omitFieldNames ? '' : 'entries', entryClassName: 'Attributes.EntriesEntry', keyFieldType: $pb.PbFieldType.O3, valueFieldType: $pb.PbFieldType.OM, valueCreator: Attributes_Attribute.create, valueDefaultOrMaker: Attributes_Attribute.getDefault, packageName: const $pb.PackageName('attribute'))
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Attributes clone() => Attributes()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Attributes copyWith(void Function(Attributes) updates) => super.copyWith((message) => updates(message as Attributes)) as Attributes;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Attributes create() => Attributes._();
  Attributes createEmptyInstance() => create();
  static $pb.PbList<Attributes> createRepeated() => $pb.PbList<Attributes>();
  @$core.pragma('dart2js:noInline')
  static Attributes getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Attributes>(create);
  static Attributes? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, Attributes_Attribute> get entries => $_getMap(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
