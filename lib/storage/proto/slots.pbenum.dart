// This is a generated file - do not edit.
//
// Generated from slots.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Slots_SlotState extends $pb.ProtobufEnum {
  static const Slots_SlotState PASSIVE =
      Slots_SlotState._(0, _omitEnumNames ? '' : 'PASSIVE');
  static const Slots_SlotState ONLINE =
      Slots_SlotState._(1, _omitEnumNames ? '' : 'ONLINE');
  static const Slots_SlotState ACTIVE =
      Slots_SlotState._(2, _omitEnumNames ? '' : 'ACTIVE');
  static const Slots_SlotState OVERLOAD =
      Slots_SlotState._(3, _omitEnumNames ? '' : 'OVERLOAD');

  static const $core.List<Slots_SlotState> values = <Slots_SlotState>[
    PASSIVE,
    ONLINE,
    ACTIVE,
    OVERLOAD,
  ];

  static final $core.List<Slots_SlotState?> _byValue =
      $pb.ProtobufEnum.$_initByValueList(values, 3);
  static Slots_SlotState? valueOf($core.int value) =>
      value < 0 || value >= _byValue.length ? null : _byValue[value];

  const Slots_SlotState._(super.value, super.name);
}

const $core.bool _omitEnumNames =
    $core.bool.fromEnvironment('protobuf.omit_enum_names');
