//
//  Generated code. Do not modify.
//  source: ships.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use shipsDescriptor instead')
const Ships$json = {
  '1': 'Ships',
  '2': [
    {'1': 'entries', '3': 1, '4': 3, '5': 11, '6': '.ships.Ships.EntriesEntry', '10': 'entries'},
  ],
  '3': [Ships_Ship$json, Ships_EntriesEntry$json],
};

@$core.Deprecated('Use shipsDescriptor instead')
const Ships_Ship$json = {
  '1': 'Ship',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 11, '6': '.i18n.I18N', '10': 'name'},
    {'1': 'groupID', '3': 2, '4': 2, '5': 5, '10': 'groupID'},
    {'1': 'published', '3': 3, '4': 2, '5': 8, '10': 'published'},
    {'1': 'highSlotNum', '3': 4, '4': 2, '5': 5, '10': 'highSlotNum'},
    {'1': 'medSlotNum', '3': 5, '4': 2, '5': 5, '10': 'medSlotNum'},
    {'1': 'lowSlotNum', '3': 6, '4': 2, '5': 5, '10': 'lowSlotNum'},
    {'1': 'rigSlotNum', '3': 7, '4': 2, '5': 5, '10': 'rigSlotNum'},
    {'1': 'subsystemSlotNum', '3': 8, '4': 2, '5': 5, '10': 'subsystemSlotNum'},
    {'1': 'turretSlotNum', '3': 9, '4': 2, '5': 5, '10': 'turretSlotNum'},
    {'1': 'launcherSlotNum', '3': 10, '4': 2, '5': 5, '10': 'launcherSlotNum'},
    {'1': 'droneBandwidth', '3': 11, '4': 2, '5': 5, '10': 'droneBandwidth'},
  ],
};

@$core.Deprecated('Use shipsDescriptor instead')
const Ships_EntriesEntry$json = {
  '1': 'EntriesEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.ships.Ships.Ship', '10': 'value'},
  ],
  '7': {'7': true},
};

/// Descriptor for `Ships`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List shipsDescriptor = $convert
    .base64Decode('CgVTaGlwcxIzCgdlbnRyaWVzGAEgAygLMhkuc2hpcHMuU2hpcHMuRW50cmllc0VudHJ5Ugdlbn'
        'RyaWVzGoQDCgRTaGlwEh4KBG5hbWUYASACKAsyCi5pMThuLkkxOE5SBG5hbWUSGAoHZ3JvdXBJ'
        'RBgCIAIoBVIHZ3JvdXBJRBIcCglwdWJsaXNoZWQYAyACKAhSCXB1Ymxpc2hlZBIgCgtoaWdoU2'
        'xvdE51bRgEIAIoBVILaGlnaFNsb3ROdW0SHgoKbWVkU2xvdE51bRgFIAIoBVIKbWVkU2xvdE51'
        'bRIeCgpsb3dTbG90TnVtGAYgAigFUgpsb3dTbG90TnVtEh4KCnJpZ1Nsb3ROdW0YByACKAVSCn'
        'JpZ1Nsb3ROdW0SKgoQc3Vic3lzdGVtU2xvdE51bRgIIAIoBVIQc3Vic3lzdGVtU2xvdE51bRIk'
        'Cg10dXJyZXRTbG90TnVtGAkgAigFUg10dXJyZXRTbG90TnVtEigKD2xhdW5jaGVyU2xvdE51bR'
        'gKIAIoBVIPbGF1bmNoZXJTbG90TnVtEiYKDmRyb25lQmFuZHdpZHRoGAsgAigFUg5kcm9uZUJh'
        'bmR3aWR0aBpNCgxFbnRyaWVzRW50cnkSEAoDa2V5GAEgASgFUgNrZXkSJwoFdmFsdWUYAiABKA'
        'syES5zaGlwcy5TaGlwcy5TaGlwUgV2YWx1ZToCOAE=');
