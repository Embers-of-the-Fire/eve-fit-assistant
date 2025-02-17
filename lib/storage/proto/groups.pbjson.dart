//
//  Generated code. Do not modify.
//  source: groups.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use groupsDescriptor instead')
const Groups$json = {
  '1': 'Groups',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.groups.Groups.EntriesEntry', '10': 'entries'},
  ],
  '3': [Groups_Group$json, Groups_EntriesEntry$json],
};

@$core.Deprecated('Use groupsDescriptor instead')
const Groups_Group$json = {
  '1': 'Group',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 11, '6': '.i18n.I18N', '10': 'name'},
    {'1': 'types', '3': 2, '4': 3, '5': 5, '10': 'types'},
    {'1': 'relatedMarketGroups', '3': 3, '4': 3, '5': 5, '10': 'relatedMarketGroups'},
  ],
};

@$core.Deprecated('Use groupsDescriptor instead')
const Groups_EntriesEntry$json = {
  '1': 'EntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.groups.Groups.Group', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Groups`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List groupsDescriptor = $convert.base64Decode(
    'CgZHcm91cHMSNQoHZW50cmllcxgBIAMoCzIbLmdyb3Vwcy5Hcm91cHMuRW50cmllc0VudHJ5Ug'
    'dlbnRyaWVzGm8KBUdyb3VwEh4KBG5hbWUYASACKAsyCi5pMThuLkkxOE5SBG5hbWUSFAoFdHlw'
    'ZXMYAiADKAVSBXR5cGVzEjAKE3JlbGF0ZWRNYXJrZXRHcm91cHMYAyADKAVSE3JlbGF0ZWRNYX'
    'JrZXRHcm91cHMaUAoMRW50cmllc0VudHJ5EhAKA2tleRgBIAEoBVIDa2V5EioKBXZhbHVlGAIg'
    'ASgLMhQuZ3JvdXBzLkdyb3Vwcy5Hcm91cFIFdmFsdWU6AjgB');

