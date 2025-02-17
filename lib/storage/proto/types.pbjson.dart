//
//  Generated code. Do not modify.
//  source: types.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use typesDescriptor instead')
const Types$json = {
  '1': 'Types',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.types.Types.EntriesEntry', '10': 'entries'},
  ],
  '3': [Types_Type$json, Types_EntriesEntry$json],
};

@$core.Deprecated('Use typesDescriptor instead')
const Types_Type$json = {
  '1': 'Type',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 11, '6': '.i18n.I18N', '10': 'name'},
    {'1': 'groupID', '3': 2, '4': 2, '5': 5, '10': 'groupID'},
    {'1': 'published', '3': 3, '4': 2, '5': 8, '10': 'published'},
    {'1': 'description', '3': 4, '4': 2, '5': 9, '10': 'description'},
  ],
};

@$core.Deprecated('Use typesDescriptor instead')
const Types_EntriesEntry$json = {
  '1': 'EntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.types.Types.Type', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Types`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List typesDescriptor = $convert.base64Decode(
    'CgVUeXBlcxIzCgdlbnRyaWVzGAEgAygLMhkudHlwZXMuVHlwZXMuRW50cmllc0VudHJ5Ugdlbn'
    'RyaWVzGoABCgRUeXBlEh4KBG5hbWUYASACKAsyCi5pMThuLkkxOE5SBG5hbWUSGAoHZ3JvdXBJ'
    'RBgCIAIoBVIHZ3JvdXBJRBIcCglwdWJsaXNoZWQYAyACKAhSCXB1Ymxpc2hlZBIgCgtkZXNjcm'
    'lwdGlvbhgEIAIoCVILZGVzY3JpcHRpb24aTQoMRW50cmllc0VudHJ5EhAKA2tleRgBIAEoBVID'
    'a2V5EicKBXZhbHVlGAIgASgLMhEudHlwZXMuVHlwZXMuVHlwZVIFdmFsdWU6AjgB');

