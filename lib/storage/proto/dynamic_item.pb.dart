//
//  Generated code. Do not modify.
//  source: dynamic_item.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class DynamicItems_DynamicItem_InputOutputMapping extends $pb.GeneratedMessage {
  factory DynamicItems_DynamicItem_InputOutputMapping({
    $core.int? resultingType,
    $core.Iterable<$core.int>? applicableTypes,
  }) {
    final $result = create();
    if (resultingType != null) {
      $result.resultingType = resultingType;
    }
    if (applicableTypes != null) {
      $result.applicableTypes.addAll(applicableTypes);
    }
    return $result;
  }
  DynamicItems_DynamicItem_InputOutputMapping._() : super();
  factory DynamicItems_DynamicItem_InputOutputMapping.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DynamicItems_DynamicItem_InputOutputMapping.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DynamicItems.DynamicItem.InputOutputMapping', package: const $pb.PackageName(_omitMessageNames ? '' : 'dynamic_item'), createEmptyInstance: create)
    ..a<$core.int>(1, _omitFieldNames ? '' : 'resultingType', $pb.PbFieldType.Q3, protoName: 'resultingType')
    ..p<$core.int>(2, _omitFieldNames ? '' : 'applicableTypes', $pb.PbFieldType.P3, protoName: 'applicableTypes')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DynamicItems_DynamicItem_InputOutputMapping clone() => DynamicItems_DynamicItem_InputOutputMapping()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DynamicItems_DynamicItem_InputOutputMapping copyWith(void Function(DynamicItems_DynamicItem_InputOutputMapping) updates) => super.copyWith((message) => updates(message as DynamicItems_DynamicItem_InputOutputMapping)) as DynamicItems_DynamicItem_InputOutputMapping;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DynamicItems_DynamicItem_InputOutputMapping create() => DynamicItems_DynamicItem_InputOutputMapping._();
  DynamicItems_DynamicItem_InputOutputMapping createEmptyInstance() => create();
  static $pb.PbList<DynamicItems_DynamicItem_InputOutputMapping> createRepeated() => $pb.PbList<DynamicItems_DynamicItem_InputOutputMapping>();
  @$core.pragma('dart2js:noInline')
  static DynamicItems_DynamicItem_InputOutputMapping getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DynamicItems_DynamicItem_InputOutputMapping>(create);
  static DynamicItems_DynamicItem_InputOutputMapping? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get resultingType => $_getIZ(0);
  @$pb.TagNumber(1)
  set resultingType($core.int v) { $_setSignedInt32(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasResultingType() => $_has(0);
  @$pb.TagNumber(1)
  void clearResultingType() => clearField(1);

  @$pb.TagNumber(2)
  $core.List<$core.int> get applicableTypes => $_getList(1);
}

class DynamicItems_DynamicItem_DynamicAttribute extends $pb.GeneratedMessage {
  factory DynamicItems_DynamicItem_DynamicAttribute({
    $core.double? max,
    $core.double? min,
  }) {
    final $result = create();
    if (max != null) {
      $result.max = max;
    }
    if (min != null) {
      $result.min = min;
    }
    return $result;
  }
  DynamicItems_DynamicItem_DynamicAttribute._() : super();
  factory DynamicItems_DynamicItem_DynamicAttribute.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DynamicItems_DynamicItem_DynamicAttribute.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DynamicItems.DynamicItem.DynamicAttribute', package: const $pb.PackageName(_omitMessageNames ? '' : 'dynamic_item'), createEmptyInstance: create)
    ..a<$core.double>(1, _omitFieldNames ? '' : 'max', $pb.PbFieldType.QD)
    ..a<$core.double>(2, _omitFieldNames ? '' : 'min', $pb.PbFieldType.QD)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DynamicItems_DynamicItem_DynamicAttribute clone() => DynamicItems_DynamicItem_DynamicAttribute()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DynamicItems_DynamicItem_DynamicAttribute copyWith(void Function(DynamicItems_DynamicItem_DynamicAttribute) updates) => super.copyWith((message) => updates(message as DynamicItems_DynamicItem_DynamicAttribute)) as DynamicItems_DynamicItem_DynamicAttribute;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DynamicItems_DynamicItem_DynamicAttribute create() => DynamicItems_DynamicItem_DynamicAttribute._();
  DynamicItems_DynamicItem_DynamicAttribute createEmptyInstance() => create();
  static $pb.PbList<DynamicItems_DynamicItem_DynamicAttribute> createRepeated() => $pb.PbList<DynamicItems_DynamicItem_DynamicAttribute>();
  @$core.pragma('dart2js:noInline')
  static DynamicItems_DynamicItem_DynamicAttribute getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DynamicItems_DynamicItem_DynamicAttribute>(create);
  static DynamicItems_DynamicItem_DynamicAttribute? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get max => $_getN(0);
  @$pb.TagNumber(1)
  set max($core.double v) { $_setDouble(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasMax() => $_has(0);
  @$pb.TagNumber(1)
  void clearMax() => clearField(1);

  @$pb.TagNumber(2)
  $core.double get min => $_getN(1);
  @$pb.TagNumber(2)
  set min($core.double v) { $_setDouble(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasMin() => $_has(1);
  @$pb.TagNumber(2)
  void clearMin() => clearField(2);
}

class DynamicItems_DynamicItem extends $pb.GeneratedMessage {
  factory DynamicItems_DynamicItem({
    DynamicItems_DynamicItem_InputOutputMapping? inputOutputMapping,
    $core.Map<$core.int, DynamicItems_DynamicItem_DynamicAttribute>? attributes,
  }) {
    final $result = create();
    if (inputOutputMapping != null) {
      $result.inputOutputMapping = inputOutputMapping;
    }
    if (attributes != null) {
      $result.attributes.addAll(attributes);
    }
    return $result;
  }
  DynamicItems_DynamicItem._() : super();
  factory DynamicItems_DynamicItem.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DynamicItems_DynamicItem.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DynamicItems.DynamicItem', package: const $pb.PackageName(_omitMessageNames ? '' : 'dynamic_item'), createEmptyInstance: create)
    ..aQM<DynamicItems_DynamicItem_InputOutputMapping>(1, _omitFieldNames ? '' : 'inputOutputMapping', protoName: 'inputOutputMapping', subBuilder: DynamicItems_DynamicItem_InputOutputMapping.create)
    ..m<$core.int, DynamicItems_DynamicItem_DynamicAttribute>(2, _omitFieldNames ? '' : 'attributes', entryClassName: 'DynamicItems.DynamicItem.AttributesEntry', keyFieldType: $pb.PbFieldType.O3, valueFieldType: $pb.PbFieldType.OM, valueCreator: DynamicItems_DynamicItem_DynamicAttribute.create, valueDefaultOrMaker: DynamicItems_DynamicItem_DynamicAttribute.getDefault, packageName: const $pb.PackageName('dynamic_item'))
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DynamicItems_DynamicItem clone() => DynamicItems_DynamicItem()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DynamicItems_DynamicItem copyWith(void Function(DynamicItems_DynamicItem) updates) => super.copyWith((message) => updates(message as DynamicItems_DynamicItem)) as DynamicItems_DynamicItem;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DynamicItems_DynamicItem create() => DynamicItems_DynamicItem._();
  DynamicItems_DynamicItem createEmptyInstance() => create();
  static $pb.PbList<DynamicItems_DynamicItem> createRepeated() => $pb.PbList<DynamicItems_DynamicItem>();
  @$core.pragma('dart2js:noInline')
  static DynamicItems_DynamicItem getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DynamicItems_DynamicItem>(create);
  static DynamicItems_DynamicItem? _defaultInstance;

  /// repeated InputOutputMapping inputOutputMapping = 1;
  @$pb.TagNumber(1)
  DynamicItems_DynamicItem_InputOutputMapping get inputOutputMapping => $_getN(0);
  @$pb.TagNumber(1)
  set inputOutputMapping(DynamicItems_DynamicItem_InputOutputMapping v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasInputOutputMapping() => $_has(0);
  @$pb.TagNumber(1)
  void clearInputOutputMapping() => clearField(1);
  @$pb.TagNumber(1)
  DynamicItems_DynamicItem_InputOutputMapping ensureInputOutputMapping() => $_ensure(0);

  @$pb.TagNumber(2)
  $core.Map<$core.int, DynamicItems_DynamicItem_DynamicAttribute> get attributes => $_getMap(1);
}

class DynamicItems extends $pb.GeneratedMessage {
  factory DynamicItems({
    $core.Map<$core.int, DynamicItems_DynamicItem>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  DynamicItems._() : super();
  factory DynamicItems.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DynamicItems.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DynamicItems', package: const $pb.PackageName(_omitMessageNames ? '' : 'dynamic_item'), createEmptyInstance: create)
    ..m<$core.int, DynamicItems_DynamicItem>(1, _omitFieldNames ? '' : 'entries', entryClassName: 'DynamicItems.EntriesEntry', keyFieldType: $pb.PbFieldType.O3, valueFieldType: $pb.PbFieldType.OM, valueCreator: DynamicItems_DynamicItem.create, valueDefaultOrMaker: DynamicItems_DynamicItem.getDefault, packageName: const $pb.PackageName('dynamic_item'))
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DynamicItems clone() => DynamicItems()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DynamicItems copyWith(void Function(DynamicItems) updates) => super.copyWith((message) => updates(message as DynamicItems)) as DynamicItems;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DynamicItems create() => DynamicItems._();
  DynamicItems createEmptyInstance() => create();
  static $pb.PbList<DynamicItems> createRepeated() => $pb.PbList<DynamicItems>();
  @$core.pragma('dart2js:noInline')
  static DynamicItems getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DynamicItems>(create);
  static DynamicItems? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, DynamicItems_DynamicItem> get entries => $_getMap(0);
}

class DynamicTypes_DynamicType extends $pb.GeneratedMessage {
  factory DynamicTypes_DynamicType({
    $core.Iterable<$core.int>? mutaplasmidTypes,
  }) {
    final $result = create();
    if (mutaplasmidTypes != null) {
      $result.mutaplasmidTypes.addAll(mutaplasmidTypes);
    }
    return $result;
  }
  DynamicTypes_DynamicType._() : super();
  factory DynamicTypes_DynamicType.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DynamicTypes_DynamicType.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DynamicTypes.DynamicType', package: const $pb.PackageName(_omitMessageNames ? '' : 'dynamic_item'), createEmptyInstance: create)
    ..p<$core.int>(1, _omitFieldNames ? '' : 'mutaplasmidTypes', $pb.PbFieldType.P3, protoName: 'mutaplasmidTypes')
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DynamicTypes_DynamicType clone() => DynamicTypes_DynamicType()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DynamicTypes_DynamicType copyWith(void Function(DynamicTypes_DynamicType) updates) => super.copyWith((message) => updates(message as DynamicTypes_DynamicType)) as DynamicTypes_DynamicType;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DynamicTypes_DynamicType create() => DynamicTypes_DynamicType._();
  DynamicTypes_DynamicType createEmptyInstance() => create();
  static $pb.PbList<DynamicTypes_DynamicType> createRepeated() => $pb.PbList<DynamicTypes_DynamicType>();
  @$core.pragma('dart2js:noInline')
  static DynamicTypes_DynamicType getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DynamicTypes_DynamicType>(create);
  static DynamicTypes_DynamicType? _defaultInstance;

  @$pb.TagNumber(1)
  $core.List<$core.int> get mutaplasmidTypes => $_getList(0);
}

class DynamicTypes extends $pb.GeneratedMessage {
  factory DynamicTypes({
    $core.Map<$core.int, DynamicTypes_DynamicType>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  DynamicTypes._() : super();
  factory DynamicTypes.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory DynamicTypes.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'DynamicTypes', package: const $pb.PackageName(_omitMessageNames ? '' : 'dynamic_item'), createEmptyInstance: create)
    ..m<$core.int, DynamicTypes_DynamicType>(1, _omitFieldNames ? '' : 'entries', entryClassName: 'DynamicTypes.EntriesEntry', keyFieldType: $pb.PbFieldType.O3, valueFieldType: $pb.PbFieldType.OM, valueCreator: DynamicTypes_DynamicType.create, valueDefaultOrMaker: DynamicTypes_DynamicType.getDefault, packageName: const $pb.PackageName('dynamic_item'))
    ..hasRequiredFields = false
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  DynamicTypes clone() => DynamicTypes()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  DynamicTypes copyWith(void Function(DynamicTypes) updates) => super.copyWith((message) => updates(message as DynamicTypes)) as DynamicTypes;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DynamicTypes create() => DynamicTypes._();
  DynamicTypes createEmptyInstance() => create();
  static $pb.PbList<DynamicTypes> createRepeated() => $pb.PbList<DynamicTypes>();
  @$core.pragma('dart2js:noInline')
  static DynamicTypes getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<DynamicTypes>(create);
  static DynamicTypes? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, DynamicTypes_DynamicType> get entries => $_getMap(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
