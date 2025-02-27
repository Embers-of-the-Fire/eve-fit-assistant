//
//  Generated code. Do not modify.
//  source: dynamic_item.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use dynamicItemsDescriptor instead')
const DynamicItems$json = {
  '1': 'DynamicItems',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.dynamic_item.DynamicItems.EntriesEntry', '10': 'entries'},
  ],
  '3': [DynamicItems_DynamicItem$json, DynamicItems_EntriesEntry$json],
};

@$core.Deprecated('Use dynamicItemsDescriptor instead')
const DynamicItems_DynamicItem$json = {
  '1': 'DynamicItem',
  '2': [
    {'1': 'inputOutputMapping', '3': 1, '4': 2, '5': 11, '6': '.dynamic_item.DynamicItems.DynamicItem.InputOutputMapping', '10': 'inputOutputMapping'},
    {'1': 'attributes', '3': 2, '4': 3, '5': 11, '6': '.dynamic_item.DynamicItems.DynamicItem.AttributesEntry', '10': 'attributes'},
  ],
  '3': [DynamicItems_DynamicItem_InputOutputMapping$json, DynamicItems_DynamicItem_DynamicAttribute$json, DynamicItems_DynamicItem_AttributesEntry$json],
};

@$core.Deprecated('Use dynamicItemsDescriptor instead')
const DynamicItems_DynamicItem_InputOutputMapping$json = {
  '1': 'InputOutputMapping',
  '2': [
    {'1': 'resultingType', '3': 1, '4': 2, '5': 5, '10': 'resultingType'},
    {'1': 'applicableTypes', '3': 2, '4': 3, '5': 5, '10': 'applicableTypes'},
  ],
};

@$core.Deprecated('Use dynamicItemsDescriptor instead')
const DynamicItems_DynamicItem_DynamicAttribute$json = {
  '1': 'DynamicAttribute',
  '2': [
    {'1': 'max', '3': 1, '4': 2, '5': 1, '10': 'max'},
    {'1': 'min', '3': 2, '4': 2, '5': 1, '10': 'min'},
  ],
};

@$core.Deprecated('Use dynamicItemsDescriptor instead')
const DynamicItems_DynamicItem_AttributesEntry$json = {
  '1': 'AttributesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.dynamic_item.DynamicItems.DynamicItem.DynamicAttribute', '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use dynamicItemsDescriptor instead')
const DynamicItems_EntriesEntry$json = {
  '1': 'EntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.dynamic_item.DynamicItems.DynamicItem', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `DynamicItems`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dynamicItemsDescriptor = $convert.base64Decode(
    'CgxEeW5hbWljSXRlbXMSQQoHZW50cmllcxgBIAMoCzInLmR5bmFtaWNfaXRlbS5EeW5hbWljSX'
    'RlbXMuRW50cmllc0VudHJ5UgdlbnRyaWVzGuYDCgtEeW5hbWljSXRlbRJpChJpbnB1dE91dHB1'
    'dE1hcHBpbmcYASACKAsyOS5keW5hbWljX2l0ZW0uRHluYW1pY0l0ZW1zLkR5bmFtaWNJdGVtLk'
    'lucHV0T3V0cHV0TWFwcGluZ1ISaW5wdXRPdXRwdXRNYXBwaW5nElYKCmF0dHJpYnV0ZXMYAiAD'
    'KAsyNi5keW5hbWljX2l0ZW0uRHluYW1pY0l0ZW1zLkR5bmFtaWNJdGVtLkF0dHJpYnV0ZXNFbn'
    'RyeVIKYXR0cmlidXRlcxpkChJJbnB1dE91dHB1dE1hcHBpbmcSJAoNcmVzdWx0aW5nVHlwZRgB'
    'IAIoBVINcmVzdWx0aW5nVHlwZRIoCg9hcHBsaWNhYmxlVHlwZXMYAiADKAVSD2FwcGxpY2FibG'
    'VUeXBlcxo2ChBEeW5hbWljQXR0cmlidXRlEhAKA21heBgBIAIoAVIDbWF4EhAKA21pbhgCIAIo'
    'AVIDbWluGnYKD0F0dHJpYnV0ZXNFbnRyeRIQCgNrZXkYASABKAVSA2tleRJNCgV2YWx1ZRgCIA'
    'EoCzI3LmR5bmFtaWNfaXRlbS5EeW5hbWljSXRlbXMuRHluYW1pY0l0ZW0uRHluYW1pY0F0dHJp'
    'YnV0ZVIFdmFsdWU6AjgBGmIKDEVudHJpZXNFbnRyeRIQCgNrZXkYASABKAVSA2tleRI8CgV2YW'
    'x1ZRgCIAEoCzImLmR5bmFtaWNfaXRlbS5EeW5hbWljSXRlbXMuRHluYW1pY0l0ZW1SBXZhbHVl'
    'OgI4AQ==');

@$core.Deprecated('Use dynamicTypesDescriptor instead')
const DynamicTypes$json = {
  '1': 'DynamicTypes',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.dynamic_item.DynamicTypes.EntriesEntry', '10': 'entries'},
  ],
  '3': [DynamicTypes_DynamicType$json, DynamicTypes_EntriesEntry$json],
};

@$core.Deprecated('Use dynamicTypesDescriptor instead')
const DynamicTypes_DynamicType$json = {
  '1': 'DynamicType',
  '2': [
    {'1': 'mutaplasmidTypes', '3': 1, '4': 3, '5': 5, '10': 'mutaplasmidTypes'},
  ],
};

@$core.Deprecated('Use dynamicTypesDescriptor instead')
const DynamicTypes_EntriesEntry$json = {
  '1': 'EntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.dynamic_item.DynamicTypes.DynamicType', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `DynamicTypes`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List dynamicTypesDescriptor = $convert.base64Decode(
    'CgxEeW5hbWljVHlwZXMSQQoHZW50cmllcxgBIAMoCzInLmR5bmFtaWNfaXRlbS5EeW5hbWljVH'
    'lwZXMuRW50cmllc0VudHJ5UgdlbnRyaWVzGjkKC0R5bmFtaWNUeXBlEioKEG11dGFwbGFzbWlk'
    'VHlwZXMYASADKAVSEG11dGFwbGFzbWlkVHlwZXMaYgoMRW50cmllc0VudHJ5EhAKA2tleRgBIA'
    'EoBVIDa2V5EjwKBXZhbHVlGAIgASgLMiYuZHluYW1pY19pdGVtLkR5bmFtaWNUeXBlcy5EeW5h'
    'bWljVHlwZVIFdmFsdWU6AjgB');

