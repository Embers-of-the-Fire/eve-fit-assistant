//
//  Generated code. Do not modify.
//  source: unit.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Units_Unit extends $pb.GeneratedMessage {
  factory Units_Unit({
    $core.String? name,
    $core.int? id,
    $core.String? displayName,
    $core.String? description,
  }) {
    final $result = create();
    if (name != null) {
      $result.name = name;
    }
    if (id != null) {
      $result.id = id;
    }
    if (displayName != null) {
      $result.displayName = displayName;
    }
    if (description != null) {
      $result.description = description;
    }
    return $result;
  }
  Units_Unit._() : super();
  factory Units_Unit.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Units_Unit.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Units.Unit', package: const $pb.PackageName(_omitMessageNames ? '' : 'unit'), createEmptyInstance: create)
    ..aQS(1, _omitFieldNames ? '' : 'name')
    ..a<$core.int>(2, _omitFieldNames ? '' : 'id', $pb.PbFieldType.Q3)
    ..aQS(3, _omitFieldNames ? '' : 'displayName', protoName: 'displayName')
    ..aQS(4, _omitFieldNames ? '' : 'description')
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Units_Unit clone() => Units_Unit()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Units_Unit copyWith(void Function(Units_Unit) updates) => super.copyWith((message) => updates(message as Units_Unit)) as Units_Unit;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Units_Unit create() => Units_Unit._();
  Units_Unit createEmptyInstance() => create();
  static $pb.PbList<Units_Unit> createRepeated() => $pb.PbList<Units_Unit>();
  @$core.pragma('dart2js:noInline')
  static Units_Unit getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Units_Unit>(create);
  static Units_Unit? _defaultInstance;

  @$pb.TagNumber(1)
  $core.String get name => $_getSZ(0);
  @$pb.TagNumber(1)
  set name($core.String v) { $_setString(0, v); }
  @$pb.TagNumber(1)
  $core.bool hasName() => $_has(0);
  @$pb.TagNumber(1)
  void clearName() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get id => $_getIZ(1);
  @$pb.TagNumber(2)
  set id($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasId() => $_has(1);
  @$pb.TagNumber(2)
  void clearId() => clearField(2);

  @$pb.TagNumber(3)
  $core.String get displayName => $_getSZ(2);
  @$pb.TagNumber(3)
  set displayName($core.String v) { $_setString(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasDisplayName() => $_has(2);
  @$pb.TagNumber(3)
  void clearDisplayName() => clearField(3);

  @$pb.TagNumber(4)
  $core.String get description => $_getSZ(3);
  @$pb.TagNumber(4)
  set description($core.String v) { $_setString(3, v); }
  @$pb.TagNumber(4)
  $core.bool hasDescription() => $_has(3);
  @$pb.TagNumber(4)
  void clearDescription() => clearField(4);
}

class Units extends $pb.GeneratedMessage {
  factory Units({
    $core.Map<$core.int, Units_Unit>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  Units._() : super();
  factory Units.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Units.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Units', package: const $pb.PackageName(_omitMessageNames ? '' : 'unit'), createEmptyInstance: create)
    ..m<$core.int, Units_Unit>(1, _omitFieldNames ? '' : 'entries', entryClassName: 'Units.EntriesEntry', keyFieldType: $pb.PbFieldType.O3, valueFieldType: $pb.PbFieldType.OM, valueCreator: Units_Unit.create, valueDefaultOrMaker: Units_Unit.getDefault, packageName: const $pb.PackageName('unit'))
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Units clone() => Units()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Units copyWith(void Function(Units) updates) => super.copyWith((message) => updates(message as Units)) as Units;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Units create() => Units._();
  Units createEmptyInstance() => create();
  static $pb.PbList<Units> createRepeated() => $pb.PbList<Units>();
  @$core.pragma('dart2js:noInline')
  static Units getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Units>(create);
  static Units? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, Units_Unit> get entries => $_getMap(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
