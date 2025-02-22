//
//  Generated code. Do not modify.
//  source: damage_profile.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use damageProfilesDescriptor instead')
const DamageProfiles$json = {
  '1': 'DamageProfiles',
  '2': [
    {'1': 'groups', '3': 1, '4': 3, '5': 11, '6': '.damage_profile.DamageProfiles.DamageProfileGroup', '10': 'groups'},
  ],
  '3': [DamageProfiles_DamageProfile$json, DamageProfiles_DamageProfileGroup$json],
};

@$core.Deprecated('Use damageProfilesDescriptor instead')
const DamageProfiles_DamageProfile$json = {
  '1': 'DamageProfile',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 9, '10': 'name'},
    {'1': 'em', '3': 2, '4': 2, '5': 1, '10': 'em'},
    {'1': 'explosive', '3': 3, '4': 2, '5': 1, '10': 'explosive'},
    {'1': 'kinetic', '3': 4, '4': 2, '5': 1, '10': 'kinetic'},
    {'1': 'thermal', '3': 5, '4': 2, '5': 1, '10': 'thermal'},
  ],
};

@$core.Deprecated('Use damageProfilesDescriptor instead')
const DamageProfiles_DamageProfileGroup$json = {
  '1': 'DamageProfileGroup',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 9, '10': 'name'},
    {'1': 'profiles', '3': 2, '4': 3, '5': 11, '6': '.damage_profile.DamageProfiles.DamageProfile', '10': 'profiles'},
  ],
};

/// Descriptor for `DamageProfiles`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List damageProfilesDescriptor = $convert.base64Decode(
    'Cg5EYW1hZ2VQcm9maWxlcxJJCgZncm91cHMYASADKAsyMS5kYW1hZ2VfcHJvZmlsZS5EYW1hZ2'
    'VQcm9maWxlcy5EYW1hZ2VQcm9maWxlR3JvdXBSBmdyb3VwcxqFAQoNRGFtYWdlUHJvZmlsZRIS'
    'CgRuYW1lGAEgAigJUgRuYW1lEg4KAmVtGAIgAigBUgJlbRIcCglleHBsb3NpdmUYAyACKAFSCW'
    'V4cGxvc2l2ZRIYCgdraW5ldGljGAQgAigBUgdraW5ldGljEhgKB3RoZXJtYWwYBSACKAFSB3Ro'
    'ZXJtYWwacgoSRGFtYWdlUHJvZmlsZUdyb3VwEhIKBG5hbWUYASACKAlSBG5hbWUSSAoIcHJvZm'
    'lsZXMYAiADKAsyLC5kYW1hZ2VfcHJvZmlsZS5EYW1hZ2VQcm9maWxlcy5EYW1hZ2VQcm9maWxl'
    'Ughwcm9maWxlcw==');

