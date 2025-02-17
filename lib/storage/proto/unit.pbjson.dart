//
//  Generated code. Do not modify.
//  source: unit.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use unitsDescriptor instead')
const Units$json = {
  '1': 'Units',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.unit.Units.EntriesEntry', '10': 'entries'},
  ],
  '3': [Units_Unit$json, Units_EntriesEntry$json],
};

@$core.Deprecated('Use unitsDescriptor instead')
const Units_Unit$json = {
  '1': 'Unit',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 9, '10': 'name'},
    {'1': 'displayName', '3': 2, '4': 2, '5': 9, '10': 'displayName'},
    {'1': 'description', '3': 3, '4': 2, '5': 9, '10': 'description'},
  ],
};

@$core.Deprecated('Use unitsDescriptor instead')
const Units_EntriesEntry$json = {
  '1': 'EntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.unit.Units.Unit', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Units`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List unitsDescriptor = $convert.base64Decode(
    'CgVVbml0cxIyCgdlbnRyaWVzGAEgAygLMhgudW5pdC5Vbml0cy5FbnRyaWVzRW50cnlSB2VudH'
    'JpZXMaXgoEVW5pdBISCgRuYW1lGAEgAigJUgRuYW1lEiAKC2Rpc3BsYXlOYW1lGAIgAigJUgtk'
    'aXNwbGF5TmFtZRIgCgtkZXNjcmlwdGlvbhgDIAIoCVILZGVzY3JpcHRpb24aTAoMRW50cmllc0'
    'VudHJ5EhAKA2tleRgBIAEoBVIDa2V5EiYKBXZhbHVlGAIgASgLMhAudW5pdC5Vbml0cy5Vbml0'
    'UgV2YWx1ZToCOAE=');

