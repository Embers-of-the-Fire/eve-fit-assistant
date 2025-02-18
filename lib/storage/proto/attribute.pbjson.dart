//
//  Generated code. Do not modify.
//  source: attribute.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use attributesDescriptor instead')
const Attributes$json = {
  '1': 'Attributes',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.attribute.Attributes.EntriesEntry', '10': 'entries'},
  ],
  '3': [Attributes_Attribute$json, Attributes_EntriesEntry$json],
};

@$core.Deprecated('Use attributesDescriptor instead')
const Attributes_Attribute$json = {
  '1': 'Attribute',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 9, '10': 'name'},
    {'1': 'defaultValue', '3': 2, '4': 1, '5': 1, '10': 'defaultValue'},
    {'1': 'categoryID', '3': 3, '4': 1, '5': 5, '10': 'categoryID'},
    {'1': 'description', '3': 4, '4': 1, '5': 9, '10': 'description'},
    {'1': 'displayName', '3': 5, '4': 1, '5': 11, '6': '.i18n.I18N', '10': 'displayName'},
    {'1': 'highIsGood', '3': 6, '4': 2, '5': 8, '10': 'highIsGood'},
    {'1': 'iconID', '3': 7, '4': 1, '5': 5, '10': 'iconID'},
    {'1': 'published', '3': 8, '4': 2, '5': 8, '10': 'published'},
    {'1': 'unitID', '3': 9, '4': 1, '5': 5, '10': 'unitID'},
  ],
};

@$core.Deprecated('Use attributesDescriptor instead')
const Attributes_EntriesEntry$json = {
  '1': 'EntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.attribute.Attributes.Attribute', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Attributes`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List attributesDescriptor = $convert.base64Decode(
    'CgpBdHRyaWJ1dGVzEjwKB2VudHJpZXMYASADKAsyIi5hdHRyaWJ1dGUuQXR0cmlidXRlcy5Fbn'
    'RyaWVzRW50cnlSB2VudHJpZXMaoQIKCUF0dHJpYnV0ZRISCgRuYW1lGAEgAigJUgRuYW1lEiIK'
    'DGRlZmF1bHRWYWx1ZRgCIAEoAVIMZGVmYXVsdFZhbHVlEh4KCmNhdGVnb3J5SUQYAyABKAVSCm'
    'NhdGVnb3J5SUQSIAoLZGVzY3JpcHRpb24YBCABKAlSC2Rlc2NyaXB0aW9uEiwKC2Rpc3BsYXlO'
    'YW1lGAUgASgLMgouaTE4bi5JMThOUgtkaXNwbGF5TmFtZRIeCgpoaWdoSXNHb29kGAYgAigIUg'
    'poaWdoSXNHb29kEhYKBmljb25JRBgHIAEoBVIGaWNvbklEEhwKCXB1Ymxpc2hlZBgIIAIoCFIJ'
    'cHVibGlzaGVkEhYKBnVuaXRJRBgJIAEoBVIGdW5pdElEGlsKDEVudHJpZXNFbnRyeRIQCgNrZX'
    'kYASABKAVSA2tleRI1CgV2YWx1ZRgCIAEoCzIfLmF0dHJpYnV0ZS5BdHRyaWJ1dGVzLkF0dHJp'
    'YnV0ZVIFdmFsdWU6AjgB');

