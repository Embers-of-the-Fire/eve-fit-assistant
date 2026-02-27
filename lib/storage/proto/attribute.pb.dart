// This is a generated file - do not edit.
//
// Generated from attribute.proto.

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
    final result = create();
    if (name != null) result.name = name;
    if (defaultValue != null) result.defaultValue = defaultValue;
    if (categoryID != null) result.categoryID = categoryID;
    if (description != null) result.description = description;
    if (displayName != null) result.displayName = displayName;
    if (highIsGood != null) result.highIsGood = highIsGood;
    if (iconID != null) result.iconID = iconID;
    if (published != null) result.published = published;
    if (unitID != null) result.unitID = unitID;
    return result;
  }

  Attributes_Attribute._();

  factory Attributes_Attribute.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Attributes_Attribute.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Attributes.Attribute',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'attribute'),
      createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'name')
    ..aD(2, _omitFieldNames ? '' : 'defaultValue', protoName: 'defaultValue')
    ..aI(3, _omitFieldNames ? '' : 'categoryID', protoName: 'categoryID')
    ..aOS(4, _omitFieldNames ? '' : 'description')
    ..aOM<$0.I18N>(5, _omitFieldNames ? '' : 'displayName',
        protoName: 'displayName', subBuilder: $0.I18N.create)
    ..a<$core.bool>(6, _omitFieldNames ? '' : 'highIsGood', $pb.PbFieldType.QB,
        protoName: 'highIsGood')
    ..aI(7, _omitFieldNames ? '' : 'iconID', protoName: 'iconID')
    ..a<$core.bool>(8, _omitFieldNames ? '' : 'published', $pb.PbFieldType.QB)
    ..aI(9, _omitFieldNames ? '' : 'unitID', protoName: 'unitID');

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Attributes_Attribute clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Attributes_Attribute copyWith(void Function(Attributes_Attribute) updates) =>
      super.copyWith((message) => updates(message as Attributes_Attribute))
          as Attributes_Attribute;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Attributes_Attribute create() => Attributes_Attribute._();
  @$core.override
  Attributes_Attribute createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Attributes_Attribute getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Attributes_Attribute>(create);
  static Attributes_Attribute? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get defaultValue => $_getN(1);
  @$pb.TagNumber(2)
  set defaultValue($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasDefaultValue() => $_has(1);
  @$pb.TagNumber(2)
  void clearDefaultValue() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get categoryID => $_getIZ(2);
  @$pb.TagNumber(3)
  set categoryID($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasCategoryID() => $_has(2);
  @$pb.TagNumber(3)
  void clearCategoryID() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.String get description => $_getSZ(3);
  @$pb.TagNumber(4)
  set description($core.String value) => $_setString(3, value);
  @$pb.TagNumber(4)
  $core.bool hasDescription() => $_has(3);
  @$pb.TagNumber(4)
  void clearDescription() => $_clearField(4);

  @$pb.TagNumber(5)
  $0.I18N get displayName => $_getN(4);
  @$pb.TagNumber(5)
  set displayName($0.I18N value) => $_setField(5, value);
  @$pb.TagNumber(5)
  $core.bool hasDisplayName() => $_has(4);
  @$pb.TagNumber(5)
  void clearDisplayName() => $_clearField(5);
  @$pb.TagNumber(5)
  $0.I18N ensureDisplayName() => $_ensure(4);

  @$pb.TagNumber(6)
  $core.bool get highIsGood => $_getBF(5);
  @$pb.TagNumber(6)
  set highIsGood($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasHighIsGood() => $_has(5);
  @$pb.TagNumber(6)
  void clearHighIsGood() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.int get iconID => $_getIZ(6);
  @$pb.TagNumber(7)
  set iconID($core.int value) => $_setSignedInt32(6, value);
  @$pb.TagNumber(7)
  $core.bool hasIconID() => $_has(6);
  @$pb.TagNumber(7)
  void clearIconID() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get published => $_getBF(7);
  @$pb.TagNumber(8)
  set published($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasPublished() => $_has(7);
  @$pb.TagNumber(8)
  void clearPublished() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.int get unitID => $_getIZ(8);
  @$pb.TagNumber(9)
  set unitID($core.int value) => $_setSignedInt32(8, value);
  @$pb.TagNumber(9)
  $core.bool hasUnitID() => $_has(8);
  @$pb.TagNumber(9)
  void clearUnitID() => $_clearField(9);
}

class Attributes extends $pb.GeneratedMessage {
  factory Attributes({
    $core.Iterable<$core.MapEntry<$core.int, Attributes_Attribute>>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addEntries(entries);
    return result;
  }

  Attributes._();

  factory Attributes.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Attributes.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Attributes',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'attribute'),
      createEmptyInstance: create)
    ..m<$core.int, Attributes_Attribute>(1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'Attributes.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Attributes_Attribute.create,
        valueDefaultOrMaker: Attributes_Attribute.getDefault,
        packageName: const $pb.PackageName('attribute'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Attributes clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Attributes copyWith(void Function(Attributes) updates) =>
      super.copyWith((message) => updates(message as Attributes)) as Attributes;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Attributes create() => Attributes._();
  @$core.override
  Attributes createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Attributes getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Attributes>(create);
  static Attributes? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, Attributes_Attribute> get entries => $_getMap(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
