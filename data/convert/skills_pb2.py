# -*- coding: utf-8 -*-
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# NO CHECKED-IN PROTOBUF GENCODE
# source: skills.proto
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
    'skills.proto'
)
# @@protoc_insertion_point(imports)

_sym_db = _symbol_database.Default()


import i18n_pb2 as i18n__pb2


DESCRIPTOR = _descriptor_pool.Default().AddSerializedFile(b'\n\x0cskills.proto\x12\x06skills\x1a\ni18n.proto\"\xda\x01\n\x06Skills\x12,\n\x07\x65ntries\x18\x01 \x03(\x0b\x32\x1b.skills.Skills.EntriesEntry\x1a\\\n\x05Skill\x12\x18\n\x04name\x18\x01 \x02(\x0b\x32\n.i18n.I18N\x12\x0f\n\x07groupID\x18\x02 \x02(\x05\x12\x11\n\tpublished\x18\x03 \x02(\x08\x12\x15\n\ralphaMaxLevel\x18\x04 \x01(\x05\x1a\x44\n\x0c\x45ntriesEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12#\n\x05value\x18\x02 \x01(\x0b\x32\x14.skills.Skills.Skill:\x02\x38\x01\"\xe7\x01\n\nTypeSkills\x12\x30\n\x07\x65ntries\x18\x01 \x03(\x0b\x32\x1f.skills.TypeSkills.EntriesEntry\x1a\"\n\x05Skill\x12\n\n\x02id\x18\x01 \x02(\x05\x12\r\n\x05level\x18\x02 \x02(\x05\x1a\x35\n\tTypeSkill\x12(\n\x06skills\x18\x01 \x03(\x0b\x32\x18.skills.TypeSkills.Skill\x1aL\n\x0c\x45ntriesEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12+\n\x05value\x18\x02 \x01(\x0b\x32\x1c.skills.TypeSkills.TypeSkill:\x02\x38\x01')

_globals = globals()
_builder.BuildMessageAndEnumDescriptors(DESCRIPTOR, _globals)
_builder.BuildTopDescriptorsAndMessages(DESCRIPTOR, 'skills_pb2', _globals)
if not _descriptor._USE_C_DESCRIPTORS:
  DESCRIPTOR._loaded_options = None
  _globals['_SKILLS_ENTRIESENTRY']._loaded_options = None
  _globals['_SKILLS_ENTRIESENTRY']._serialized_options = b'8\001'
  _globals['_TYPESKILLS_ENTRIESENTRY']._loaded_options = None
  _globals['_TYPESKILLS_ENTRIESENTRY']._serialized_options = b'8\001'
  _globals['_SKILLS']._serialized_start=37
  _globals['_SKILLS']._serialized_end=255
  _globals['_SKILLS_SKILL']._serialized_start=93
  _globals['_SKILLS_SKILL']._serialized_end=185
  _globals['_SKILLS_ENTRIESENTRY']._serialized_start=187
  _globals['_SKILLS_ENTRIESENTRY']._serialized_end=255
  _globals['_TYPESKILLS']._serialized_start=258
  _globals['_TYPESKILLS']._serialized_end=489
  _globals['_TYPESKILLS_SKILL']._serialized_start=322
  _globals['_TYPESKILLS_SKILL']._serialized_end=356
  _globals['_TYPESKILLS_TYPESKILL']._serialized_start=358
  _globals['_TYPESKILLS_TYPESKILL']._serialized_end=411
  _globals['_TYPESKILLS_ENTRIESENTRY']._serialized_start=413
  _globals['_TYPESKILLS_ENTRIESENTRY']._serialized_end=489
# @@protoc_insertion_point(module_scope)
