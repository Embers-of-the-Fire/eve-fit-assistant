# -*- coding: utf-8 -*-
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# NO CHECKED-IN PROTOBUF GENCODE
# source: tactical_mode.proto
# Protobuf Python Version: 5.29.3
"""Generated protocol buffer code."""
from google.protobuf import descriptor as _descriptor
from google.protobuf import descriptor_pool as _descriptor_pool
from google.protobuf import runtime_version as _runtime_version
from google.protobuf import symbol_database as _symbol_database
from google.protobuf.internal import builder as _builder
_runtime_version.ValidateProtobufRuntimeVersion(
    _runtime_version.Domain.PUBLIC,
    5,
    29,
    3,
    '',
    'tactical_mode.proto'
)
# @@protoc_insertion_point(imports)

_sym_db = _symbol_database.Default()


import i18n_pb2 as i18n__pb2


DESCRIPTOR = _descriptor_pool.Default().AddSerializedFile(b'\n\x13tactical_mode.proto\x12\rtactical_mode\x1a\ni18n.proto\"\x98\x03\n\x10ShipTacticalMode\x12\x39\n\x05ships\x18\x01 \x03(\x0b\x32*.tactical_mode.ShipTacticalMode.ShipsEntry\x1a\xba\x01\n\x04Ship\x12N\n\rtacticalModes\x18\x01 \x03(\x0b\x32\x37.tactical_mode.ShipTacticalMode.Ship.TacticalModesEntry\x1a\x62\n\x12TacticalModesEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12;\n\x05value\x18\x02 \x01(\x0b\x32,.tactical_mode.ShipTacticalMode.TacticalMode:\x02\x38\x01\x1a\x38\n\x0cTacticalMode\x12\x18\n\x04name\x18\x01 \x02(\x0b\x32\n.i18n.I18N\x12\x0e\n\x06iconID\x18\x02 \x02(\x05\x1aR\n\nShipsEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12\x33\n\x05value\x18\x02 \x01(\x0b\x32$.tactical_mode.ShipTacticalMode.Ship:\x02\x38\x01')

_globals = globals()
_builder.BuildMessageAndEnumDescriptors(DESCRIPTOR, _globals)
_builder.BuildTopDescriptorsAndMessages(DESCRIPTOR, 'tactical_mode_pb2', _globals)
if not _descriptor._USE_C_DESCRIPTORS:
  DESCRIPTOR._loaded_options = None
  _globals['_SHIPTACTICALMODE_SHIP_TACTICALMODESENTRY']._loaded_options = None
  _globals['_SHIPTACTICALMODE_SHIP_TACTICALMODESENTRY']._serialized_options = b'8\001'
  _globals['_SHIPTACTICALMODE_SHIPSENTRY']._loaded_options = None
  _globals['_SHIPTACTICALMODE_SHIPSENTRY']._serialized_options = b'8\001'
  _globals['_SHIPTACTICALMODE']._serialized_start=51
  _globals['_SHIPTACTICALMODE']._serialized_end=459
  _globals['_SHIPTACTICALMODE_SHIP']._serialized_start=131
  _globals['_SHIPTACTICALMODE_SHIP']._serialized_end=317
  _globals['_SHIPTACTICALMODE_SHIP_TACTICALMODESENTRY']._serialized_start=219
  _globals['_SHIPTACTICALMODE_SHIP_TACTICALMODESENTRY']._serialized_end=317
  _globals['_SHIPTACTICALMODE_TACTICALMODE']._serialized_start=319
  _globals['_SHIPTACTICALMODE_TACTICALMODE']._serialized_end=375
  _globals['_SHIPTACTICALMODE_SHIPSENTRY']._serialized_start=377
  _globals['_SHIPTACTICALMODE_SHIPSENTRY']._serialized_end=459
# @@protoc_insertion_point(module_scope)
