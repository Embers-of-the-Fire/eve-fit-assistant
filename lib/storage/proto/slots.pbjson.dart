//
//  Generated code. Do not modify.
//  source: slots.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use slotsDescriptor instead')
const Slots$json = {
  '1': 'Slots',
  '2': [
    {'1': 'high', '3': 1, '4': 3, '5': 11, '6': '.slots.Slots.HighEntry', '10': 'high'},
    {'1': 'med', '3': 2, '4': 3, '5': 11, '6': '.slots.Slots.MedEntry', '10': 'med'},
    {'1': 'low', '3': 3, '4': 3, '5': 11, '6': '.slots.Slots.LowEntry', '10': 'low'},
    {'1': 'rig', '3': 4, '4': 3, '5': 11, '6': '.slots.Slots.RigEntry', '10': 'rig'},
    {
      '1': 'subsystem',
      '3': 5,
      '4': 3,
      '5': 11,
      '6': '.slots.Slots.SubsystemEntry',
      '10': 'subsystem'
    },
    {'1': 'implant', '3': 6, '4': 3, '5': 11, '6': '.slots.Slots.ImplantEntry', '10': 'implant'},
  ],
  '3': [
    Slots_HighSlot$json,
    Slots_Slot$json,
    Slots_ImplantSlot$json,
    Slots_HighEntry$json,
    Slots_MedEntry$json,
    Slots_LowEntry$json,
    Slots_RigEntry$json,
    Slots_SubsystemEntry$json,
    Slots_ImplantEntry$json
  ],
  '4': [Slots_SlotState$json],
};

@$core.Deprecated('Use slotsDescriptor instead')
const Slots_HighSlot$json = {
  '1': 'HighSlot',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 11, '6': '.i18n.I18N', '10': 'name'},
    {'1': 'isTurret', '3': 2, '4': 2, '5': 8, '10': 'isTurret'},
    {'1': 'isLauncher', '3': 3, '4': 2, '5': 8, '10': 'isLauncher'},
    {'1': 'published', '3': 4, '4': 2, '5': 8, '10': 'published'},
    {'1': 'maxState', '3': 5, '4': 2, '5': 14, '6': '.slots.Slots.SlotState', '10': 'maxState'},
    {'1': 'chargeGroups', '3': 6, '4': 3, '5': 5, '10': 'chargeGroups'},
  ],
};

@$core.Deprecated('Use slotsDescriptor instead')
const Slots_Slot$json = {
  '1': 'Slot',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 11, '6': '.i18n.I18N', '10': 'name'},
    {'1': 'published', '3': 2, '4': 2, '5': 8, '10': 'published'},
    {'1': 'maxState', '3': 3, '4': 2, '5': 14, '6': '.slots.Slots.SlotState', '10': 'maxState'},
    {'1': 'chargeGroups', '3': 4, '4': 3, '5': 5, '10': 'chargeGroups'},
  ],
};

@$core.Deprecated('Use slotsDescriptor instead')
const Slots_ImplantSlot$json = {
  '1': 'ImplantSlot',
  '2': [
    {'1': 'name', '3': 1, '4': 2, '5': 11, '6': '.i18n.I18N', '10': 'name'},
    {'1': 'published', '3': 2, '4': 2, '5': 8, '10': 'published'},
    {'1': 'slot', '3': 3, '4': 2, '5': 5, '10': 'slot'},
  ],
};

@$core.Deprecated('Use slotsDescriptor instead')
const Slots_HighEntry$json = {
  '1': 'HighEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.slots.Slots.HighSlot', '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use slotsDescriptor instead')
const Slots_MedEntry$json = {
  '1': 'MedEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.slots.Slots.Slot', '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use slotsDescriptor instead')
const Slots_LowEntry$json = {
  '1': 'LowEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.slots.Slots.Slot', '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use slotsDescriptor instead')
const Slots_RigEntry$json = {
  '1': 'RigEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.slots.Slots.Slot', '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use slotsDescriptor instead')
const Slots_SubsystemEntry$json = {
  '1': 'SubsystemEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.slots.Slots.Slot', '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use slotsDescriptor instead')
const Slots_ImplantEntry$json = {
  '1': 'ImplantEntry',
  '2': [
    {'1': 'key', '3': 1, '4': 1, '5': 5, '10': 'key'},
    {'1': 'value', '3': 2, '4': 1, '5': 11, '6': '.slots.Slots.ImplantSlot', '10': 'value'},
  ],
  '7': {'7': true},
};

@$core.Deprecated('Use slotsDescriptor instead')
const Slots_SlotState$json = {
  '1': 'SlotState',
  '2': [
    {'1': 'PASSIVE', '2': 0},
    {'1': 'ONLINE', '2': 1},
    {'1': 'ACTIVE', '2': 2},
    {'1': 'OVERLOAD', '2': 3},
  ],
};

/// Descriptor for `Slots`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List slotsDescriptor = $convert
    .base64Decode('CgVTbG90cxIqCgRoaWdoGAEgAygLMhYuc2xvdHMuU2xvdHMuSGlnaEVudHJ5UgRoaWdoEicKA2'
        '1lZBgCIAMoCzIVLnNsb3RzLlNsb3RzLk1lZEVudHJ5UgNtZWQSJwoDbG93GAMgAygLMhUuc2xv'
        'dHMuU2xvdHMuTG93RW50cnlSA2xvdxInCgNyaWcYBCADKAsyFS5zbG90cy5TbG90cy5SaWdFbn'
        'RyeVIDcmlnEjkKCXN1YnN5c3RlbRgFIAMoCzIbLnNsb3RzLlNsb3RzLlN1YnN5c3RlbUVudHJ5'
        'UglzdWJzeXN0ZW0SMwoHaW1wbGFudBgGIAMoCzIZLnNsb3RzLlNsb3RzLkltcGxhbnRFbnRyeV'
        'IHaW1wbGFudBrcAQoISGlnaFNsb3QSHgoEbmFtZRgBIAIoCzIKLmkxOG4uSTE4TlIEbmFtZRIa'
        'Cghpc1R1cnJldBgCIAIoCFIIaXNUdXJyZXQSHgoKaXNMYXVuY2hlchgDIAIoCFIKaXNMYXVuY2'
        'hlchIcCglwdWJsaXNoZWQYBCACKAhSCXB1Ymxpc2hlZBIyCghtYXhTdGF0ZRgFIAIoDjIWLnNs'
        'b3RzLlNsb3RzLlNsb3RTdGF0ZVIIbWF4U3RhdGUSIgoMY2hhcmdlR3JvdXBzGAYgAygFUgxjaG'
        'FyZ2VHcm91cHManAEKBFNsb3QSHgoEbmFtZRgBIAIoCzIKLmkxOG4uSTE4TlIEbmFtZRIcCglw'
        'dWJsaXNoZWQYAiACKAhSCXB1Ymxpc2hlZBIyCghtYXhTdGF0ZRgDIAIoDjIWLnNsb3RzLlNsb3'
        'RzLlNsb3RTdGF0ZVIIbWF4U3RhdGUSIgoMY2hhcmdlR3JvdXBzGAQgAygFUgxjaGFyZ2VHcm91'
        'cHMaXwoLSW1wbGFudFNsb3QSHgoEbmFtZRgBIAIoCzIKLmkxOG4uSTE4TlIEbmFtZRIcCglwdW'
        'JsaXNoZWQYAiACKAhSCXB1Ymxpc2hlZBISCgRzbG90GAMgAigFUgRzbG90Gk4KCUhpZ2hFbnRy'
        'eRIQCgNrZXkYASABKAVSA2tleRIrCgV2YWx1ZRgCIAEoCzIVLnNsb3RzLlNsb3RzLkhpZ2hTbG'
        '90UgV2YWx1ZToCOAEaSQoITWVkRW50cnkSEAoDa2V5GAEgASgFUgNrZXkSJwoFdmFsdWUYAiAB'
        'KAsyES5zbG90cy5TbG90cy5TbG90UgV2YWx1ZToCOAEaSQoITG93RW50cnkSEAoDa2V5GAEgAS'
        'gFUgNrZXkSJwoFdmFsdWUYAiABKAsyES5zbG90cy5TbG90cy5TbG90UgV2YWx1ZToCOAEaSQoI'
        'UmlnRW50cnkSEAoDa2V5GAEgASgFUgNrZXkSJwoFdmFsdWUYAiABKAsyES5zbG90cy5TbG90cy'
        '5TbG90UgV2YWx1ZToCOAEaTwoOU3Vic3lzdGVtRW50cnkSEAoDa2V5GAEgASgFUgNrZXkSJwoF'
        'dmFsdWUYAiABKAsyES5zbG90cy5TbG90cy5TbG90UgV2YWx1ZToCOAEaVAoMSW1wbGFudEVudH'
        'J5EhAKA2tleRgBIAEoBVIDa2V5Ei4KBXZhbHVlGAIgASgLMhguc2xvdHMuU2xvdHMuSW1wbGFu'
        'dFNsb3RSBXZhbHVlOgI4ASI+CglTbG90U3RhdGUSCwoHUEFTU0lWRRAAEgoKBk9OTElORRABEg'
        'oKBkFDVElWRRACEgwKCE9WRVJMT0FEEAM=');
