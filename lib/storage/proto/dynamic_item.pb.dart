// This is a generated file - do not edit.
//
// Generated from dynamic_item.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class DynamicItems_DynamicItem_InputOutputMapping extends $pb.GeneratedMessage {
  factory DynamicItems_DynamicItem_InputOutputMapping({
    $core.int? resultingType,
    $core.Iterable<$core.int>? applicableTypes,
  }) {
    final result = create();
    if (resultingType != null) result.resultingType = resultingType;
    if (applicableTypes != null) result.applicableTypes.addAll(applicableTypes);
    return result;
  }

  DynamicItems_DynamicItem_InputOutputMapping._();

  factory DynamicItems_DynamicItem_InputOutputMapping.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DynamicItems_DynamicItem_InputOutputMapping.fromJson(
          $core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DynamicItems.DynamicItem.InputOutputMapping',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dynamic_item'),
      createEmptyInstance: create)
    ..aI(1, _omitFieldNames ? '' : 'resultingType',
        protoName: 'resultingType', fieldType: $pb.PbFieldType.Q3)
    ..p<$core.int>(
        2, _omitFieldNames ? '' : 'applicableTypes', $pb.PbFieldType.P3,
        protoName: 'applicableTypes');

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DynamicItems_DynamicItem_InputOutputMapping clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DynamicItems_DynamicItem_InputOutputMapping copyWith(
          void Function(DynamicItems_DynamicItem_InputOutputMapping) updates) =>
      super.copyWith((message) =>
              updates(message as DynamicItems_DynamicItem_InputOutputMapping))
          as DynamicItems_DynamicItem_InputOutputMapping;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DynamicItems_DynamicItem_InputOutputMapping create() =>
      DynamicItems_DynamicItem_InputOutputMapping._();
  @$core.override
  DynamicItems_DynamicItem_InputOutputMapping createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DynamicItems_DynamicItem_InputOutputMapping getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          DynamicItems_DynamicItem_InputOutputMapping>(create);
  static DynamicItems_DynamicItem_InputOutputMapping? _defaultInstance;

  @$pb.TagNumber(1)
  $core.int get resultingType => $_getIZ(0);
  @$pb.TagNumber(1)
  set resultingType($core.int value) => $_setSignedInt32(0, value);
  @$pb.TagNumber(1)
  $core.bool hasResultingType() => $_has(0);
  @$pb.TagNumber(1)
  void clearResultingType() => $_clearField(1);

  @$pb.TagNumber(2)
  $pb.PbList<$core.int> get applicableTypes => $_getList(1);
}

class DynamicItems_DynamicItem_DynamicAttribute extends $pb.GeneratedMessage {
  factory DynamicItems_DynamicItem_DynamicAttribute({
    $core.double? max,
    $core.double? min,
  }) {
    final result = create();
    if (max != null) result.max = max;
    if (min != null) result.min = min;
    return result;
  }

  DynamicItems_DynamicItem_DynamicAttribute._();

  factory DynamicItems_DynamicItem_DynamicAttribute.fromBuffer(
          $core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DynamicItems_DynamicItem_DynamicAttribute.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DynamicItems.DynamicItem.DynamicAttribute',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dynamic_item'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'max', fieldType: $pb.PbFieldType.QD)
    ..aD(2, _omitFieldNames ? '' : 'min', fieldType: $pb.PbFieldType.QD);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DynamicItems_DynamicItem_DynamicAttribute clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DynamicItems_DynamicItem_DynamicAttribute copyWith(
          void Function(DynamicItems_DynamicItem_DynamicAttribute) updates) =>
      super.copyWith((message) =>
              updates(message as DynamicItems_DynamicItem_DynamicAttribute))
          as DynamicItems_DynamicItem_DynamicAttribute;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DynamicItems_DynamicItem_DynamicAttribute create() =>
      DynamicItems_DynamicItem_DynamicAttribute._();
  @$core.override
  DynamicItems_DynamicItem_DynamicAttribute createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DynamicItems_DynamicItem_DynamicAttribute getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<
          DynamicItems_DynamicItem_DynamicAttribute>(create);
  static DynamicItems_DynamicItem_DynamicAttribute? _defaultInstance;

  @$pb.TagNumber(1)
  $core.double get max => $_getN(0);
  @$pb.TagNumber(1)
  set max($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasMax() => $_has(0);
  @$pb.TagNumber(1)
  void clearMax() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.double get min => $_getN(1);
  @$pb.TagNumber(2)
  set min($core.double value) => $_setDouble(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMin() => $_has(1);
  @$pb.TagNumber(2)
  void clearMin() => $_clearField(2);
}

class DynamicItems_DynamicItem extends $pb.GeneratedMessage {
  factory DynamicItems_DynamicItem({
    DynamicItems_DynamicItem_InputOutputMapping? inputOutputMapping,
    $core.Iterable<
            $core
            .MapEntry<$core.int, DynamicItems_DynamicItem_DynamicAttribute>>?
        attributes,
  }) {
    final result = create();
    if (inputOutputMapping != null)
      result.inputOutputMapping = inputOutputMapping;
    if (attributes != null) result.attributes.addEntries(attributes);
    return result;
  }

  DynamicItems_DynamicItem._();

  factory DynamicItems_DynamicItem.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DynamicItems_DynamicItem.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DynamicItems.DynamicItem',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dynamic_item'),
      createEmptyInstance: create)
    ..aQM<DynamicItems_DynamicItem_InputOutputMapping>(
        1, _omitFieldNames ? '' : 'inputOutputMapping',
        protoName: 'inputOutputMapping',
        subBuilder: DynamicItems_DynamicItem_InputOutputMapping.create)
    ..m<$core.int, DynamicItems_DynamicItem_DynamicAttribute>(
        2, _omitFieldNames ? '' : 'attributes',
        entryClassName: 'DynamicItems.DynamicItem.AttributesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: DynamicItems_DynamicItem_DynamicAttribute.create,
        valueDefaultOrMaker:
            DynamicItems_DynamicItem_DynamicAttribute.getDefault,
        packageName: const $pb.PackageName('dynamic_item'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DynamicItems_DynamicItem clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DynamicItems_DynamicItem copyWith(
          void Function(DynamicItems_DynamicItem) updates) =>
      super.copyWith((message) => updates(message as DynamicItems_DynamicItem))
          as DynamicItems_DynamicItem;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DynamicItems_DynamicItem create() => DynamicItems_DynamicItem._();
  @$core.override
  DynamicItems_DynamicItem createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DynamicItems_DynamicItem getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DynamicItems_DynamicItem>(create);
  static DynamicItems_DynamicItem? _defaultInstance;

  /// repeated InputOutputMapping inputOutputMapping = 1;
  @$pb.TagNumber(1)
  DynamicItems_DynamicItem_InputOutputMapping get inputOutputMapping =>
      $_getN(0);
  @$pb.TagNumber(1)
  set inputOutputMapping(DynamicItems_DynamicItem_InputOutputMapping value) =>
      $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasInputOutputMapping() => $_has(0);
  @$pb.TagNumber(1)
  void clearInputOutputMapping() => $_clearField(1);
  @$pb.TagNumber(1)
  DynamicItems_DynamicItem_InputOutputMapping ensureInputOutputMapping() =>
      $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbMap<$core.int, DynamicItems_DynamicItem_DynamicAttribute>
      get attributes => $_getMap(1);
}

class DynamicItems extends $pb.GeneratedMessage {
  factory DynamicItems({
    $core.Iterable<$core.MapEntry<$core.int, DynamicItems_DynamicItem>>?
        entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addEntries(entries);
    return result;
  }

  DynamicItems._();

  factory DynamicItems.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DynamicItems.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DynamicItems',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dynamic_item'),
      createEmptyInstance: create)
    ..m<$core.int, DynamicItems_DynamicItem>(
        1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'DynamicItems.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: DynamicItems_DynamicItem.create,
        valueDefaultOrMaker: DynamicItems_DynamicItem.getDefault,
        packageName: const $pb.PackageName('dynamic_item'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DynamicItems clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DynamicItems copyWith(void Function(DynamicItems) updates) =>
      super.copyWith((message) => updates(message as DynamicItems))
          as DynamicItems;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DynamicItems create() => DynamicItems._();
  @$core.override
  DynamicItems createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DynamicItems getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DynamicItems>(create);
  static DynamicItems? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, DynamicItems_DynamicItem> get entries => $_getMap(0);
}

class DynamicTypes_DynamicType extends $pb.GeneratedMessage {
  factory DynamicTypes_DynamicType({
    $core.Iterable<$core.int>? mutaplasmidTypes,
  }) {
    final result = create();
    if (mutaplasmidTypes != null)
      result.mutaplasmidTypes.addAll(mutaplasmidTypes);
    return result;
  }

  DynamicTypes_DynamicType._();

  factory DynamicTypes_DynamicType.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DynamicTypes_DynamicType.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DynamicTypes.DynamicType',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dynamic_item'),
      createEmptyInstance: create)
    ..p<$core.int>(
        1, _omitFieldNames ? '' : 'mutaplasmidTypes', $pb.PbFieldType.P3,
        protoName: 'mutaplasmidTypes')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DynamicTypes_DynamicType clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DynamicTypes_DynamicType copyWith(
          void Function(DynamicTypes_DynamicType) updates) =>
      super.copyWith((message) => updates(message as DynamicTypes_DynamicType))
          as DynamicTypes_DynamicType;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DynamicTypes_DynamicType create() => DynamicTypes_DynamicType._();
  @$core.override
  DynamicTypes_DynamicType createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DynamicTypes_DynamicType getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DynamicTypes_DynamicType>(create);
  static DynamicTypes_DynamicType? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbList<$core.int> get mutaplasmidTypes => $_getList(0);
}

class DynamicTypes extends $pb.GeneratedMessage {
  factory DynamicTypes({
    $core.Iterable<$core.MapEntry<$core.int, DynamicTypes_DynamicType>>?
        entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addEntries(entries);
    return result;
  }

  DynamicTypes._();

  factory DynamicTypes.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DynamicTypes.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DynamicTypes',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'dynamic_item'),
      createEmptyInstance: create)
    ..m<$core.int, DynamicTypes_DynamicType>(
        1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'DynamicTypes.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: DynamicTypes_DynamicType.create,
        valueDefaultOrMaker: DynamicTypes_DynamicType.getDefault,
        packageName: const $pb.PackageName('dynamic_item'))
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DynamicTypes clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DynamicTypes copyWith(void Function(DynamicTypes) updates) =>
      super.copyWith((message) => updates(message as DynamicTypes))
          as DynamicTypes;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DynamicTypes create() => DynamicTypes._();
  @$core.override
  DynamicTypes createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DynamicTypes getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DynamicTypes>(create);
  static DynamicTypes? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, DynamicTypes_DynamicType> get entries => $_getMap(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
