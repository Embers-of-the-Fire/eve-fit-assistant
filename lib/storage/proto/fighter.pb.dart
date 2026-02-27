// This is a generated file - do not edit.
//
// Generated from fighter.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'fighter.pbenum.dart';

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

export 'fighter.pbenum.dart';

class Fighters_Fighter extends $pb.GeneratedMessage {
  factory Fighters_Fighter({
    Fighters_FighterType? type,
    $core.int? amount,
    $core.int? ability,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (amount != null) result.amount = amount;
    if (ability != null) result.ability = ability;
    return result;
  }

  Fighters_Fighter._();

  factory Fighters_Fighter.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Fighters_Fighter.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Fighters.Fighter',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'fighter'),
      createEmptyInstance: create)
    ..aE<Fighters_FighterType>(1, _omitFieldNames ? '' : 'type',
        fieldType: $pb.PbFieldType.QE, enumValues: Fighters_FighterType.values)
    ..aI(2, _omitFieldNames ? '' : 'amount', fieldType: $pb.PbFieldType.Q3)
    ..aI(3, _omitFieldNames ? '' : 'ability', fieldType: $pb.PbFieldType.Q3);

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Fighters_Fighter clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Fighters_Fighter copyWith(void Function(Fighters_Fighter) updates) =>
      super.copyWith((message) => updates(message as Fighters_Fighter))
          as Fighters_Fighter;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Fighters_Fighter create() => Fighters_Fighter._();
  @$core.override
  Fighters_Fighter createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Fighters_Fighter getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<Fighters_Fighter>(create);
  static Fighters_Fighter? _defaultInstance;

  @$pb.TagNumber(1)
  Fighters_FighterType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(Fighters_FighterType value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.int get amount => $_getIZ(1);
  @$pb.TagNumber(2)
  set amount($core.int value) => $_setSignedInt32(1, value);
  @$pb.TagNumber(2)
  $core.bool hasAmount() => $_has(1);
  @$pb.TagNumber(2)
  void clearAmount() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.int get ability => $_getIZ(2);
  @$pb.TagNumber(3)
  set ability($core.int value) => $_setSignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasAbility() => $_has(2);
  @$pb.TagNumber(3)
  void clearAbility() => $_clearField(3);
}

class Fighters extends $pb.GeneratedMessage {
  factory Fighters({
    $core.Iterable<$core.MapEntry<$core.int, Fighters_Fighter>>? entries,
  }) {
    final result = create();
    if (entries != null) result.entries.addEntries(entries);
    return result;
  }

  Fighters._();

  factory Fighters.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Fighters.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Fighters',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'fighter'),
      createEmptyInstance: create)
    ..m<$core.int, Fighters_Fighter>(1, _omitFieldNames ? '' : 'entries',
        entryClassName: 'Fighters.EntriesEntry',
        keyFieldType: $pb.PbFieldType.O3,
        valueFieldType: $pb.PbFieldType.OM,
        valueCreator: Fighters_Fighter.create,
        valueDefaultOrMaker: Fighters_Fighter.getDefault,
        packageName: const $pb.PackageName('fighter'));

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Fighters clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Fighters copyWith(void Function(Fighters) updates) =>
      super.copyWith((message) => updates(message as Fighters)) as Fighters;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Fighters create() => Fighters._();
  @$core.override
  Fighters createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Fighters getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Fighters>(create);
  static Fighters? _defaultInstance;

  @$pb.TagNumber(1)
  $pb.PbMap<$core.int, Fighters_Fighter> get entries => $_getMap(0);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
