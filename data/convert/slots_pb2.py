# -*- coding: utf-8 -*-
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: slots.proto
"""Generated protocol buffer code."""
from google.protobuf.internal import builder as _builder
from google.protobuf import descriptor as _descriptor
from google.protobuf import descriptor_pool as _descriptor_pool
from google.protobuf import symbol_database as _symbol_database
# @@protoc_insertion_point(imports)

_sym_db = _symbol_database.Default()


import i18n_pb2 as i18n__pb2


DESCRIPTOR = _descriptor_pool.Default().AddSerializedFile(b'\n\x0bslots.proto\x12\x05slots\x1a\ni18n.proto\"\xe4\t\n\x05Slots\x12$\n\x04high\x18\x01 \x03(\x0b\x32\x16.slots.Slots.HighEntry\x12\"\n\x03med\x18\x02 \x03(\x0b\x32\x15.slots.Slots.MedEntry\x12\"\n\x03low\x18\x03 \x03(\x0b\x32\x15.slots.Slots.LowEntry\x12\"\n\x03rig\x18\x04 \x03(\x0b\x32\x15.slots.Slots.RigEntry\x12.\n\tsubsystem\x18\x05 \x03(\x0b\x32\x1b.slots.Slots.SubsystemEntry\x12*\n\x07implant\x18\x06 \x03(\x0b\x32\x19.slots.Slots.ImplantEntry\x12*\n\x07\x62ooster\x18\x07 \x03(\x0b\x32\x19.slots.Slots.BoosterEntry\x1a\x9d\x01\n\x08HighSlot\x12\x18\n\x04name\x18\x01 \x02(\x0b\x32\n.i18n.I18N\x12\x10\n\x08isTurret\x18\x02 \x02(\x08\x12\x12\n\nisLauncher\x18\x03 \x02(\x08\x12\x11\n\tpublished\x18\x04 \x02(\x08\x12(\n\x08maxState\x18\x05 \x02(\x0e\x32\x16.slots.Slots.SlotState\x12\x14\n\x0c\x63hargeGroups\x18\x06 \x03(\x05\x1as\n\x04Slot\x12\x18\n\x04name\x18\x01 \x02(\x0b\x32\n.i18n.I18N\x12\x11\n\tpublished\x18\x02 \x02(\x08\x12(\n\x08maxState\x18\x03 \x02(\x0e\x32\x16.slots.Slots.SlotState\x12\x14\n\x0c\x63hargeGroups\x18\x04 \x03(\x05\x1aH\n\x0bImplantSlot\x12\x18\n\x04name\x18\x01 \x02(\x0b\x32\n.i18n.I18N\x12\x11\n\tpublished\x18\x02 \x02(\x08\x12\x0c\n\x04slot\x18\x03 \x02(\x05\x1aH\n\x0b\x42oosterSlot\x12\x18\n\x04name\x18\x01 \x02(\x0b\x32\n.i18n.I18N\x12\x11\n\tpublished\x18\x02 \x02(\x08\x12\x0c\n\x04slot\x18\x03 \x02(\x05\x1a\x42\n\tHighEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12$\n\x05value\x18\x02 \x01(\x0b\x32\x15.slots.Slots.HighSlot:\x02\x38\x01\x1a=\n\x08MedEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12 \n\x05value\x18\x02 \x01(\x0b\x32\x11.slots.Slots.Slot:\x02\x38\x01\x1a=\n\x08LowEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12 \n\x05value\x18\x02 \x01(\x0b\x32\x11.slots.Slots.Slot:\x02\x38\x01\x1a=\n\x08RigEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12 \n\x05value\x18\x02 \x01(\x0b\x32\x11.slots.Slots.Slot:\x02\x38\x01\x1a\x43\n\x0eSubsystemEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12 \n\x05value\x18\x02 \x01(\x0b\x32\x11.slots.Slots.Slot:\x02\x38\x01\x1aH\n\x0cImplantEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12\'\n\x05value\x18\x02 \x01(\x0b\x32\x18.slots.Slots.ImplantSlot:\x02\x38\x01\x1aH\n\x0c\x42oosterEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12\'\n\x05value\x18\x02 \x01(\x0b\x32\x18.slots.Slots.BoosterSlot:\x02\x38\x01\">\n\tSlotState\x12\x0b\n\x07PASSIVE\x10\x00\x12\n\n\x06ONLINE\x10\x01\x12\n\n\x06\x41\x43TIVE\x10\x02\x12\x0c\n\x08OVERLOAD\x10\x03')

_builder.BuildMessageAndEnumDescriptors(DESCRIPTOR, globals())
_builder.BuildTopDescriptorsAndMessages(DESCRIPTOR, 'slots_pb2', globals())
if _descriptor._USE_C_DESCRIPTORS == False:

  DESCRIPTOR._options = None
  _SLOTS_HIGHENTRY._options = None
  _SLOTS_HIGHENTRY._serialized_options = b'8\001'
  _SLOTS_MEDENTRY._options = None
  _SLOTS_MEDENTRY._serialized_options = b'8\001'
  _SLOTS_LOWENTRY._options = None
  _SLOTS_LOWENTRY._serialized_options = b'8\001'
  _SLOTS_RIGENTRY._options = None
  _SLOTS_RIGENTRY._serialized_options = b'8\001'
  _SLOTS_SUBSYSTEMENTRY._options = None
  _SLOTS_SUBSYSTEMENTRY._serialized_options = b'8\001'
  _SLOTS_IMPLANTENTRY._options = None
  _SLOTS_IMPLANTENTRY._serialized_options = b'8\001'
  _SLOTS_BOOSTERENTRY._options = None
  _SLOTS_BOOSTERENTRY._serialized_options = b'8\001'
  _SLOTS._serialized_start=35
  _SLOTS._serialized_end=1287
  _SLOTS_HIGHSLOT._serialized_start=327
  _SLOTS_HIGHSLOT._serialized_end=484
  _SLOTS_SLOT._serialized_start=486
  _SLOTS_SLOT._serialized_end=601
  _SLOTS_IMPLANTSLOT._serialized_start=603
  _SLOTS_IMPLANTSLOT._serialized_end=675
  _SLOTS_BOOSTERSLOT._serialized_start=677
  _SLOTS_BOOSTERSLOT._serialized_end=749
  _SLOTS_HIGHENTRY._serialized_start=751
  _SLOTS_HIGHENTRY._serialized_end=817
  _SLOTS_MEDENTRY._serialized_start=819
  _SLOTS_MEDENTRY._serialized_end=880
  _SLOTS_LOWENTRY._serialized_start=882
  _SLOTS_LOWENTRY._serialized_end=943
  _SLOTS_RIGENTRY._serialized_start=945
  _SLOTS_RIGENTRY._serialized_end=1006
  _SLOTS_SUBSYSTEMENTRY._serialized_start=1008
  _SLOTS_SUBSYSTEMENTRY._serialized_end=1075
  _SLOTS_IMPLANTENTRY._serialized_start=1077
  _SLOTS_IMPLANTENTRY._serialized_end=1149
  _SLOTS_BOOSTERENTRY._serialized_start=1151
  _SLOTS_BOOSTERENTRY._serialized_end=1223
  _SLOTS_SLOTSTATE._serialized_start=1225
  _SLOTS_SLOTSTATE._serialized_end=1287
# @@protoc_insertion_point(module_scope)
