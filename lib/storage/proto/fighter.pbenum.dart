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

  static final $core.List<Fighters_FighterType?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Fighters_FighterType? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Fighters_FighterType._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
