//
//  Generated code. Do not modify.
//  source: fighter.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use fightersDescriptor instead')
const Fighters$json = {
  '1': 'Fighters',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.fighter.Fighters.EntriesEntry',
      '10': 'entries'
    },
  ],
  '3': [Fighters_Fighter$json, Fighters_EntriesEntry$json],
  '4': [Fighters_FighterType$json],
};

@$core.Deprecated('Use fightersDescriptor instead')
const Fighters_Fighter$json = {
  '1': 'Fighter',
  '2': [
    {'1': 'type', '3': 1, '4': 2, '5': 14, '6': '.fighter.Fighters.FighterType', '10': 'type'},
    {'1': 'amount', '3': 2, '4': 2, '5': 5, '10': 'amount'},
    {'1': 'ability', '3': 3, '4': 2, '5': 5, '10': 'ability'},
  ],
};

@$core.Deprecated('Use fightersDescriptor instead')
const Fighters_EntriesEntry$json = {
  '1': 'EntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.fighter.Fighters.Fighter', '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use fightersDescriptor instead')
const Fighters_FighterType$json = {
  '1': 'FighterType',
  '2': [
    {'1': 'LIGHT', '2': 1},
    {'1': 'SUPPORT', '2': 2},
    {'1': 'HEAVY', '2': 3},
  ],
};

/// Descriptor for `Fighters`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List fightersDescriptor = $convert
    .base64Decode('CghGaWdodGVycxI4CgdlbnRyaWVzGAEgAygLMh4uZmlnaHRlci5GaWdodGVycy5FbnRyaWVzRW'
        '50cnlSB2VudHJpZXMabgoHRmlnaHRlchIxCgR0eXBlGAEgAigOMh0uZmlnaHRlci5GaWdodGVy'
        'cy5GaWdodGVyVHlwZVIEdHlwZRIWCgZhbW91bnQYAiACKAVSBmFtb3VudBIYCgdhYmlsaXR5GA'
        'MgAigFUgdhYmlsaXR5GlUKDEVudHJpZXNFbnRyeRIQCgNrZXkYASABKAVSA2tleRIvCgV2YWx1'
        'ZRgCIAEoCzIZLmZpZ2h0ZXIuRmlnaHRlcnMuRmlnaHRlclIFdmFsdWU6AjgBIjAKC0ZpZ2h0ZX'
        'JUeXBlEgkKBUxJR0hUEAESCwoHU1VQUE9SVBACEgkKBUhFQVZZEAM=');
