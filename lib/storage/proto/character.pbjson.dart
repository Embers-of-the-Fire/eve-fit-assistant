//
//  Generated code. Do not modify.
//  source: character.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use characterDescriptor instead')
const Character$json = {
  '1': 'Character',
  '2': [
    {'1': 'id', '3': 1, '4': 2, '5': 9, '10': 'id'},
    {'1': 'name', '3': 2, '4': 2, '5': 9, '10': 'name'},
    {'1': 'description', '3': 3, '4': 2, '5': 9, '10': 'description'},
    {'1': 'skills', '3': 4, '4': 3, '5': 11, '6': '.character.Character.SkillsEntry', '10': 'skills'},
  ],
  '3': [Character_SkillsEntry$json],
};

@$core.Deprecated('Use characterDescriptor instead')
const Character_SkillsEntry$json = {
  '1': 'SkillsEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 5, '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Character`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List characterDescriptor = $convert.base64Decode(
    'CglDaGFyYWN0ZXISDgoCaWQYASACKAlSAmlkEhIKBG5hbWUYAiACKAlSBG5hbWUSIAoLZGVzY3'
    'JpcHRpb24YAyACKAlSC2Rlc2NyaXB0aW9uEjgKBnNraWxscxgEIAMoCzIgLmNoYXJhY3Rlci5D'
    'aGFyYWN0ZXIuU2tpbGxzRW50cnlSBnNraWxscxo5CgtTa2lsbHNFbnRyeRIQCgNrZXkYASABKA'
    'VSA2tleRIUCgV2YWx1ZRgCIAEoBVIFdmFsdWU6AjgB');

