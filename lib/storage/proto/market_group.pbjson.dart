//
//  Generated code. Do not modify.
//  source: market_group.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use marketGroupsDescriptor instead')
const MarketGroups$json = {
  '1': 'MarketGroups',
  '2': [
    {
      '1': 'entries',
      '3': 1,
      '4': 3,
      '5': 11,
      '6': '.market_group.MarketGroups.EntriesEntry',
      '10': 'entries'
    },
  ],
  '3': [MarketGroups_MarketGroup$json, MarketGroups_EntriesEntry$json],
};

@$core.Deprecated('Use marketGroupsDescriptor instead')
const MarketGroups_MarketGroup$json = {
  '1': 'MarketGroup',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 11, '6': '.i18n.I18N', '10': 'name'},
    {'1': 'parentGroup', '3': 2, '4': 1, '5': 5, '10': 'parentGroup'},
    {'1': 'iconID', '3': 3, '4': 1, '5': 5, '10': 'iconID'},
    {'1': 'types', '3': 4, '4': 3, '5': 5, '10': 'types'},
    {'1': 'childGroups', '3': 5, '4': 3, '5': 5, '10': 'childGroups'},
  ],
};

@$core.Deprecated('Use marketGroupsDescriptor instead')
const MarketGroups_EntriesEntry$json = {
  '1': 'EntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {
      '1': 'value',
      '3': 2,
      '4': 1,
      '5': 11,
      '6': '.market_group.MarketGroups.MarketGroup',
      '10': 'value'
    },
  ],
  '7': {'7': true},
};

/// Descriptor for `MarketGroups`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List marketGroupsDescriptor = $convert
    .base64Decode('CgxNYXJrZXRHcm91cHMSQQoHZW50cmllcxgBIAMoCzInLm1hcmtldF9ncm91cC5NYXJrZXRHcm'
        '91cHMuRW50cmllc0VudHJ5UgdlbnRyaWVzGp8BCgtNYXJrZXRHcm91cBIeCgRuYW1lGAEgAigL'
        'MgouaTE4bi5JMThOUgRuYW1lEiAKC3BhcmVudEdyb3VwGAIgASgFUgtwYXJlbnRHcm91cBIWCg'
        'ZpY29uSUQYAyABKAVSBmljb25JRBIUCgV0eXBlcxgEIAMoBVIFdHlwZXMSIAoLY2hpbGRHcm91'
        'cHMYBSADKAVSC2NoaWxkR3JvdXBzGmIKDEVudHJpZXNFbnRyeRIQCgNrZXkYASABKAVSA2tleR'
        'I8CgV2YWx1ZRgCIAEoCzImLm1hcmtldF9ncm91cC5NYXJrZXRHcm91cHMuTWFya2V0R3JvdXBS'
        'BXZhbHVlOgI4AQ==');
