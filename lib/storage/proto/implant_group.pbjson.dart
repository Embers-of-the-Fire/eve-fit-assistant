//
//  Generated code. Do not modify.
//  source: implant_group.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use implantGroupsDescriptor instead')
const ImplantGroups$json = {
  '1': 'ImplantGroups',
  '2': [
    {
      '1': 'groups',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.market_group.ImplantGroups.ImplantGroup',
      '10': 'groups'
    },
  ],
  '3': [ImplantGroups_ImplantGroup$json, ImplantGroups_ImplantSubGroup$json],
};

@$core.Deprecated('Use implantGroupsDescriptor instead')
const ImplantGroups_ImplantGroup$json = {
  '1': 'ImplantGroup',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 9, '10': 'name'},
    {
      '1': 'groups',
      '3': 2,
      '4': 3,
      '5': 11,
      '6': '.market_group.ImplantGroups.ImplantSubGroup',
      '10': 'groups'
    },
  ],
};

@$core.Deprecated('Use implantGroupsDescriptor instead')
const ImplantGroups_ImplantSubGroup$json = {
  '1': 'ImplantSubGroup',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 9, '10': 'name'},
    {'1': 'items', '3': 2, '4': 3, '5': 5, '10': 'items'},
  ],
};

/// Descriptor for `ImplantGroups`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List implantGroupsDescriptor = $convert
    .base64Decode('Cg1JbXBsYW50R3JvdXBzEkAKBmdyb3VwcxgBIAMoCzIoLm1hcmtldF9ncm91cC5JbXBsYW50R3'
        'JvdXBzLkltcGxhbnRHcm91cFIGZ3JvdXBzGmcKDEltcGxhbnRHcm91cBISCgRuYW1lGAEgAigJ'
        'UgRuYW1lEkMKBmdyb3VwcxgCIAMoCzIrLm1hcmtldF9ncm91cC5JbXBsYW50R3JvdXBzLkltcG'
        'xhbnRTdWJHcm91cFIGZ3JvdXBzGjsKD0ltcGxhbnRTdWJHcm91cBISCgRuYW1lGAEgAigJUgRu'
        'YW1lEhQKBWl0ZW1zGAIgAygFUgVpdGVtcw==');
