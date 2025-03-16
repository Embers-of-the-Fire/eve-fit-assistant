//
//  Generated code. Do not modify.
//  source: fighter.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import 'fighter.pbenum.dart';

export 'fighter.pbenum.dart';

class Fighters_Fighter extends $pb.GeneratedMessage {
  factory Fighters_Fighter({
    Fighters_FighterType? type,
    $core.int? amount,
    $core.int? ability,
  }) {
    final $result = create();
    if (type != null) {
      $result.type = type;
    }
    if (amount != null) {
      $result.amount = amount;
    }
    if (ability != null) {
      $result.ability = ability;
    }
    return $result;
  }
  Fighters_Fighter._() : super();
  factory Fighters_Fighter.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Fighters_Fighter.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Fighters.Fighter', package: const $pb.PackageName(_omitMessageNames ? '' : 'fighter'), createEmptyInstance: create)
    ..e<Fighters_FighterType>(1, _omitFieldNames ? '' : 'type', $pb.PbFieldType.QE, defaultOrMaker: Fighters_FighterType.LIGHT, valueOf: Fighters_FighterType.valueOf, enumValues: Fighters_FighterType.values)
    ..a<$core.int>(2, _omitFieldNames ? '' : 'amount', $pb.PbFieldType.Q3)
    ..a<$core.int>(3, _omitFieldNames ? '' : 'ability', $pb.PbFieldType.Q3)
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Fighters_Fighter clone() => Fighters_Fighter()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Fighters_Fighter copyWith(void Function(Fighters_Fighter) updates) => super.copyWith((message) => updates(message as Fighters_Fighter)) as Fighters_Fighter;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Fighters_Fighter create() => Fighters_Fighter._();
  Fighters_Fighter createEmptyInstance() => create();
  static $pb.PbList<Fighters_Fighter> createRepeated() => $pb.PbList<Fighters_Fighter>();
  @$core.pragma('dart2js:noInline')
  static Fighters_Fighter getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Fighters_Fighter>(create);
  static Fighters_Fighter? _defaultInstance;

  @$pb.TagNumber(1)
  Fighters_FighterType get type => $_getN(0);
  @$pb.TagNumber(1)
  set type(Fighters_FighterType v) { setField(1, v); }
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => clearField(1);

  @$pb.TagNumber(2)
  $core.int get amount => $_getIZ(1);
  @$pb.TagNumber(2)
  set amount($core.int v) { $_setSignedInt32(1, v); }
  @$pb.TagNumber(2)
  $core.bool hasAmount() => $_has(1);
  @$pb.TagNumber(2)
  void clearAmount() => clearField(2);

  @$pb.TagNumber(3)
  $core.int get ability => $_getIZ(2);
  @$pb.TagNumber(3)
  set ability($core.int v) { $_setSignedInt32(2, v); }
  @$pb.TagNumber(3)
  $core.bool hasAbility() => $_has(2);
  @$pb.TagNumber(3)
  void clearAbility() => clearField(3);
}

class Fighters extends $pb.GeneratedMessage {
  factory Fighters({
    $core.Map<$core.int, Fighters_Fighter>? entries,
  }) {
    final $result = create();
    if (entries != null) {
      $result.entries.addAll(entries);
    }
    return $result;
  }
  Fighters._() : super();
  factory Fighters.fromBuffer($core.List<$core.int> i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromBuffer(i, r);
  factory Fighters.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) => create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'Fighters', package: const $pb.PackageName(_omitMessageNames ? '' : 'fighter'), createEmptyInstance: create)
    ..m<$core.int, Fighters_Fighter>(1, _omitFieldNames ? '' : 'entries', entryClassName: 'Fighters.EntriesEntry', keyFieldType: $pb.PbFieldType.O3, valueFieldType: $pb.PbFieldType.OM, valueCreator: Fighters_Fighter.create, valueDefaultOrMaker: Fighters_Fighter.getDefault, packageName: const $pb.PackageName('fighter'))
  ;

  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
  'Will be removed in next major version')
  Fighters clone() => Fighters()..mergeFromMessage(this);
  @$core.Deprecated(
  'Using this can add significant overhead to your binary. '
  'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
  'Will be removed in next major version')
  Fighters copyWith(void Function(Fighters) updates) => super.copyWith((message) => updates(message as Fighters)) as Fighters;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Fighters create() => Fighters._();
  Fighters createEmptyInstance() => create();
  static $pb.PbList<Fighters> createRepeated() => $pb.PbList<Fighters>();
  @$core.pragma('dart2js:noInline')
  static Fighters getDefault() => _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Fighters>(create);
  static Fighters? _defaultInstance;

  @$pb.TagNumber(1)
  $core.Map<$core.int, Fighters_Fighter> get entries => $_getMap(0);
}


const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
