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

class Fighters_FighterType extends $pb.ProtobufEnum {
  static const Fighters_FighterType LIGHT =
      Fighters_FighterType._(1, _omitEnumNames ? '' : 'LIGHT');
  static const Fighters_FighterType SUPPORT =
      Fighters_FighterType._(2, _omitEnumNames ? '' : 'SUPPORT');
  static const Fighters_FighterType HEAVY =
      Fighters_FighterType._(3, _omitEnumNames ? '' : 'HEAVY');

  static const $core.List<Fighters_FighterType> values = <Fighters_FighterType>[
    LIGHT,
    SUPPORT,
    HEAVY,
  ];

  static final $core.Map<$core.int, Fighters_FighterType> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static Fighters_FighterType? valueOf($core.int value) => _byValue[value];

  const Fighters_FighterType._($core.int v, $core.String n) : super(v, n);
}

const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
