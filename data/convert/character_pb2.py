# -*- coding: utf-8 -*-
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: character.proto
"""Generated protocol buffer code."""
from google.protobuf.internal import builder as _builder
from google.protobuf import descriptor as _descriptor
from google.protobuf import descriptor_pool as _descriptor_pool
from google.protobuf import symbol_database as _symbol_database
# @@protoc_insertion_point(imports)

_sym_db = _symbol_database.Default()




DESCRIPTOR = _descriptor_pool.Default().AddSerializedFile(b'\n\x0f\x63haracter.proto\x12\tcharacter\"\x9b\x01\n\tCharacter\x12\n\n\x02id\x18\x01 \x02(\t\x12\x0c\n\x04name\x18\x02 \x02(\t\x12\x13\n\x0b\x64\x65scription\x18\x03 \x02(\t\x12\x30\n\x06skills\x18\x04 \x03(\x0b\x32 .character.Character.SkillsEntry\x1a-\n\x0bSkillsEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12\r\n\x05value\x18\x02 \x01(\x05:\x02\x38\x01')

_builder.BuildMessageAndEnumDescriptors(DESCRIPTOR, globals())
_builder.BuildTopDescriptorsAndMessages(DESCRIPTOR, 'character_pb2', globals())
if _descriptor._USE_C_DESCRIPTORS == False:

  DESCRIPTOR._options = None
  _CHARACTER_SKILLSENTRY._options = None
  _CHARACTER_SKILLSENTRY._serialized_options = b'8\001'
  _CHARACTER._serialized_start=31
  _CHARACTER._serialized_end=186
  _CHARACTER_SKILLSENTRY._serialized_start=141
  _CHARACTER_SKILLSENTRY._serialized_end=186
# @@protoc_insertion_point(module_scope)
