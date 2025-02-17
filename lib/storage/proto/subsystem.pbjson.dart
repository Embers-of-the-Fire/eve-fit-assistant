//
//  Generated code. Do not modify.
//  source: subsystem.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use shipSubsystemDescriptor instead')
const ShipSubsystem$json = {
  '1': 'ShipSubsystem',
  '2': [
    {
      '1': 'ships',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.subsystem.ShipSubsystem.ShipsEntry',
      '10': 'ships'
    },
    {
      '1': 'subsystems',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.subsystem.ShipSubsystem.SubsystemsEntry',
      '10': 'subsystems'
    },
  ],
  '3': [
    ShipSubsystem_Ship$json,
    ShipSubsystem_Subsystem$json,
    ShipSubsystem_ShipsEntry$json,
    ShipSubsystem_SubsystemsEntry$json
  ],
};

@$core.Deprecated('Use shipSubsystemDescriptor instead')
const ShipSubsystem_Ship$json = {
  '1': 'Ship',
  '2': [
    {'1': 'offensive', '3': 1, '4': 3, '5': 5, '10': 'offensive'},
    {'1': 'offensiveMarket', '3': 2, '4': 2, '5': 5, '10': 'offensiveMarket'},
    {'1': 'propulsion', '3': 3, '4': 3, '5': 5, '10': 'propulsion'},
    {'1': 'propulsionMarket', '3': 4, '4': 2, '5': 5, '10': 'propulsionMarket'},
    {'1': 'core', '3': 5, '4': 3, '5': 5, '10': 'core'},
    {'1': 'coreMarket', '3': 6, '4': 2, '5': 5, '10': 'coreMarket'},
    {'1': 'defensive', '3': 7, '4': 3, '5': 5, '10': 'defensive'},
    {'1': 'defensiveMarket', '3': 8, '4': 2, '5': 5, '10': 'defensiveMarket'},
  ],
};

@$core.Deprecated('Use shipSubsystemDescriptor instead')
const ShipSubsystem_Subsystem$json = {
  '1': 'Subsystem',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 11, '6': '.i18n.I18N', '10': 'name'},
    {'1': 'high', '3': 2, '4': 1, '5': 5, '10': 'high'},
    {'1': 'medium', '3': 3, '4': 1, '5': 5, '10': 'medium'},
    {'1': 'low', '3': 4, '4': 1, '5': 5, '10': 'low'},
    {'1': 'turret', '3': 5, '4': 1, '5': 5, '10': 'turret'},
    {'1': 'launcher', '3': 6, '4': 1, '5': 5, '10': 'launcher'},
  ],
};

@$core.Deprecated('Use shipSubsystemDescriptor instead')
const ShipSubsystem_ShipsEntry$json = {
  '1': 'ShipsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.subsystem.ShipSubsystem.Ship', '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use shipSubsystemDescriptor instead')
const ShipSubsystem_SubsystemsEntry$json = {
  '1': 'SubsystemsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.subsystem.ShipSubsystem.Subsystem',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `ShipSubsystem`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shipSubsystemDescriptor = $convert
    .base64Decode('Cg1TaGlwU3Vic3lzdGVtEjkKBXNoaXBzGAEgAygLMiMuc3Vic3lzdGVtLlNoaXBTdWJzeXN0ZW'
        '0uU2hpcHNFbnRyeVIFc2hpcHMSSAoKc3Vic3lzdGVtcxgCIAMoCzIoLnN1YnN5c3RlbS5TaGlw'
        'U3Vic3lzdGVtLlN1YnN5c3RlbXNFbnRyeVIKc3Vic3lzdGVtcxqWAgoEU2hpcBIcCglvZmZlbn'
        'NpdmUYASADKAVSCW9mZmVuc2l2ZRIoCg9vZmZlbnNpdmVNYXJrZXQYAiACKAVSD29mZmVuc2l2'
        'ZU1hcmtldBIeCgpwcm9wdWxzaW9uGAMgAygFUgpwcm9wdWxzaW9uEioKEHByb3B1bHNpb25NYX'
        'JrZXQYBCACKAVSEHByb3B1bHNpb25NYXJrZXQSEgoEY29yZRgFIAMoBVIEY29yZRIeCgpjb3Jl'
        'TWFya2V0GAYgAigFUgpjb3JlTWFya2V0EhwKCWRlZmVuc2l2ZRgHIAMoBVIJZGVmZW5zaXZlEi'
        'gKD2RlZmVuc2l2ZU1hcmtldBgIIAIoBVIPZGVmZW5zaXZlTWFya2V0Gp0BCglTdWJzeXN0ZW0S'
        'HgoEbmFtZRgBIAIoCzIKLmkxOG4uSTE4TlIEbmFtZRISCgRoaWdoGAIgASgFUgRoaWdoEhYKBm'
        '1lZGl1bRgDIAEoBVIGbWVkaXVtEhAKA2xvdxgEIAEoBVIDbG93EhYKBnR1cnJldBgFIAEoBVIG'
        'dHVycmV0EhoKCGxhdW5jaGVyGAYgASgFUghsYXVuY2hlchpXCgpTaGlwc0VudHJ5EhAKA2tleR'
        'gBIAEoBVIDa2V5EjMKBXZhbHVlGAIgASgLMh0uc3Vic3lzdGVtLlNoaXBTdWJzeXN0ZW0uU2hp'
        'cFIFdmFsdWU6AjgBGmEKD1N1YnN5c3RlbXNFbnRyeRIQCgNrZXkYASABKAVSA2tleRI4CgV2YW'
        'x1ZRgCIAEoCzIiLnN1YnN5c3RlbS5TaGlwU3Vic3lzdGVtLlN1YnN5c3RlbVIFdmFsdWU6AjgB');
