//
//  Generated code. Do not modify.
//  source: tactical_mode.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use shipTacticalModeDescriptor instead')
const ShipTacticalMode$json = {
  '1': 'ShipTacticalMode',
  '2': [
    {'1': 'ships', '3': 1, '4': 3, '5': 11, '6': '.tactical_mode.ShipTacticalMode.ShipsEntry', '10': 'ships'},
  ],
  '3': [ShipTacticalMode_Ship$json, ShipTacticalMode_TacticalMode$json, ShipTacticalMode_ShipsEntry$json],
};

@$core.Deprecated('Use shipTacticalModeDescriptor instead')
const ShipTacticalMode_Ship$json = {
  '1': 'Ship',
  '2': [
    {'1': 'tacticalModes', '3': 1, '4': 3, '5': 11, '6': '.tactical_mode.ShipTacticalMode.Ship.TacticalModesEntry', '10': 'tacticalModes'},
  ],
  '3': [ShipTacticalMode_Ship_TacticalModesEntry$json],
};

@$core.Deprecated('Use shipTacticalModeDescriptor instead')
const ShipTacticalMode_Ship_TacticalModesEntry$json = {
  '1': 'TacticalModesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.tactical_mode.ShipTacticalMode.TacticalMode', '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use shipTacticalModeDescriptor instead')
const ShipTacticalMode_TacticalMode$json = {
  '1': 'TacticalMode',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 11, '6': '.i18n.I18N', '10': 'name'},
    {'1': 'iconID', '3': 2, '4': 2, '5': 5, '10': 'iconID'},
  ],
};

@$core.Deprecated('Use shipTacticalModeDescriptor instead')
const ShipTacticalMode_ShipsEntry$json = {
  '1': 'ShipsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.tactical_mode.ShipTacticalMode.Ship', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `ShipTacticalMode`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shipTacticalModeDescriptor = $convert.base64Decode(
    'ChBTaGlwVGFjdGljYWxNb2RlEkAKBXNoaXBzGAEgAygLMioudGFjdGljYWxfbW9kZS5TaGlwVG'
    'FjdGljYWxNb2RlLlNoaXBzRW50cnlSBXNoaXBzGtUBCgRTaGlwEl0KDXRhY3RpY2FsTW9kZXMY'
    'ASADKAsyNy50YWN0aWNhbF9tb2RlLlNoaXBUYWN0aWNhbE1vZGUuU2hpcC5UYWN0aWNhbE1vZG'
    'VzRW50cnlSDXRhY3RpY2FsTW9kZXMabgoSVGFjdGljYWxNb2Rlc0VudHJ5EhAKA2tleRgBIAEo'
    'BVIDa2V5EkIKBXZhbHVlGAIgASgLMiwudGFjdGljYWxfbW9kZS5TaGlwVGFjdGljYWxNb2RlLl'
    'RhY3RpY2FsTW9kZVIFdmFsdWU6AjgBGkYKDFRhY3RpY2FsTW9kZRIeCgRuYW1lGAEgAigLMgou'
    'aTE4bi5JMThOUgRuYW1lEhYKBmljb25JRBgCIAIoBVIGaWNvbklEGl4KClNoaXBzRW50cnkSEA'
    'oDa2V5GAEgASgFUgNrZXkSOgoFdmFsdWUYAiABKAsyJC50YWN0aWNhbF9tb2RlLlNoaXBUYWN0'
    'aWNhbE1vZGUuU2hpcFIFdmFsdWU6AjgB');

