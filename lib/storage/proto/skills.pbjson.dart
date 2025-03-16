//
//  Generated code. Do not modify.
//  source: skills.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use skillsDescriptor instead')
const Skills$json = {
  '1': 'Skills',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.skills.Skills.EntriesEntry', '10': 'entries'},
  ],
  '3': [Skills_Skill$json, Skills_EntriesEntry$json],
};

@$core.Deprecated('Use skillsDescriptor instead')
const Skills_Skill$json = {
  '1': 'Skill',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 11, '6': '.i18n.I18N', '10': 'name'},
    {'1': 'groupID', '3': 2, '4': 2, '5': 5, '10': 'groupID'},
    {'1': 'published', '3': 3, '4': 2, '5': 8, '10': 'published'},
    {'1': 'alphaMaxLevel', '3': 4, '4': 1, '5': 5, '10': 'alphaMaxLevel'},
  ],
};

@$core.Deprecated('Use skillsDescriptor instead')
const Skills_EntriesEntry$json = {
  '1': 'EntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.skills.Skills.Skill', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Skills`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List skillsDescriptor = $convert.base64Decode(
    'CgZTa2lsbHMSNQoHZW50cmllcxgBIAMoCzIbLnNraWxscy5Ta2lsbHMuRW50cmllc0VudHJ5Ug'
    'dlbnRyaWVzGoUBCgVTa2lsbBIeCgRuYW1lGAEgAigLMgouaTE4bi5JMThOUgRuYW1lEhgKB2dy'
    'b3VwSUQYAiACKAVSB2dyb3VwSUQSHAoJcHVibGlzaGVkGAMgAigIUglwdWJsaXNoZWQSJAoNYW'
    'xwaGFNYXhMZXZlbBgEIAEoBVINYWxwaGFNYXhMZXZlbBpQCgxFbnRyaWVzRW50cnkSEAoDa2V5'
    'GAEgASgFUgNrZXkSKgoFdmFsdWUYAiABKAsyFC5za2lsbHMuU2tpbGxzLlNraWxsUgV2YWx1ZT'
    'oCOAE=');

@$core.Deprecated('Use typeSkillsDescriptor instead')
const TypeSkills$json = {
  '1': 'TypeSkills',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.skills.TypeSkills.EntriesEntry', '10': 'entries'},
  ],
  '3': [TypeSkills_Skill$json, TypeSkills_TypeSkill$json, TypeSkills_EntriesEntry$json],
};

@$core.Deprecated('Use typeSkillsDescriptor instead')
const TypeSkills_Skill$json = {
  '1': 'Skill',
  '2': [
    {'1': 'id', '3': 1, '4': 2, '5': 5, '10': 'id'},
    {'1': 'level', '3': 2, '4': 2, '5': 5, '10': 'level'},
  ],
};

@$core.Deprecated('Use typeSkillsDescriptor instead')
const TypeSkills_TypeSkill$json = {
  '1': 'TypeSkill',
  '2': [
    {'1': 'skills', '3': 1, '4': 3, '5': 11, '6': '.skills.TypeSkills.Skill', '10': 'skills'},
  ],
};

@$core.Deprecated('Use typeSkillsDescriptor instead')
const TypeSkills_EntriesEntry$json = {
  '1': 'EntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.skills.TypeSkills.TypeSkill', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `TypeSkills`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List typeSkillsDescriptor = $convert.base64Decode(
    'CgpUeXBlU2tpbGxzEjkKB2VudHJpZXMYASADKAsyHy5za2lsbHMuVHlwZVNraWxscy5FbnRyaW'
    'VzRW50cnlSB2VudHJpZXMaLQoFU2tpbGwSDgoCaWQYASACKAVSAmlkEhQKBWxldmVsGAIgAigF'
    'UgVsZXZlbBo9CglUeXBlU2tpbGwSMAoGc2tpbGxzGAEgAygLMhguc2tpbGxzLlR5cGVTa2lsbH'
    'MuU2tpbGxSBnNraWxscxpYCgxFbnRyaWVzRW50cnkSEAoDa2V5GAEgASgFUgNrZXkSMgoFdmFs'
    'dWUYAiABKAsyHC5za2lsbHMuVHlwZVNraWxscy5UeXBlU2tpbGxSBXZhbHVlOgI4AQ==');

