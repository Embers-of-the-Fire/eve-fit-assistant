# -*- coding: utf-8 -*-
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: implant_group.proto
"""Generated protocol buffer code."""
from google.protobuf.internal import builder as _builder
from google.protobuf import descriptor as _descriptor
from google.protobuf import descriptor_pool as _descriptor_pool
from google.protobuf import symbol_database as _symbol_database
# @@protoc_insertion_point(imports)

_sym_db = _symbol_database.Default()




DESCRIPTOR = _descriptor_pool.Default().AddSerializedFile(b'\n\x13implant_group.proto\x12\rimplant_group\"\xd6\x01\n\rImplantGroups\x12\x39\n\x06groups\x18\x01 \x03(\x0b\x32).implant_group.ImplantGroups.ImplantGroup\x1aZ\n\x0cImplantGroup\x12\x0c\n\x04name\x18\x01 \x02(\t\x12<\n\x06groups\x18\x02 \x03(\x0b\x32,.implant_group.ImplantGroups.ImplantSubGroup\x1a.\n\x0fImplantSubGroup\x12\x0c\n\x04name\x18\x01 \x02(\t\x12\r\n\x05items\x18\x02 \x03(\x05')

_builder.BuildMessageAndEnumDescriptors(DESCRIPTOR, globals())
_builder.BuildTopDescriptorsAndMessages(DESCRIPTOR, 'implant_group_pb2', globals())
if _descriptor._USE_C_DESCRIPTORS == False:

  DESCRIPTOR._options = None
  _IMPLANTGROUPS._serialized_start=39
  _IMPLANTGROUPS._serialized_end=253
  _IMPLANTGROUPS_IMPLANTGROUP._serialized_start=115
  _IMPLANTGROUPS_IMPLANTGROUP._serialized_end=205
  _IMPLANTGROUPS_IMPLANTSUBGROUP._serialized_start=207
  _IMPLANTGROUPS_IMPLANTSUBGROUP._serialized_end=253
# @@protoc_insertion_point(module_scope)
