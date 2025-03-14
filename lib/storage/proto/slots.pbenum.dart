//
//  Generated code. Do not modify.
//  source: slots.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

class Slots_SlotState extends $pb.ProtobufEnum {
  static const Slots_SlotState PASSIVE = Slots_SlotState._(0, _omitEnumNames ? '' : 'PASSIVE');
  static const Slots_SlotState ONLINE = Slots_SlotState._(1, _omitEnumNames ? '' : 'ONLINE');
  static const Slots_SlotState ACTIVE = Slots_SlotState._(2, _omitEnumNames ? '' : 'ACTIVE');
  static const Slots_SlotState OVERLOAD = Slots_SlotState._(3, _omitEnumNames ? '' : 'OVERLOAD');

  static const $core.List<Slots_SlotState> values = <Slots_SlotState>[
    PASSIVE,
    ONLINE,
    ACTIVE,
    OVERLOAD,
  ];

  static final $core.Map<$core.int, Slots_SlotState> _byValue =
      $pb.ProtobufEnum.initByValue(values);
  static Slots_SlotState? valueOf($core.int value) => _byValue[value];

  const Slots_SlotState._($core.int v, $core.String n) : super(v, n);
}

const _omitEnumNames = $core.bool.fromEnvironment('protobuf.omit_enum_names');
