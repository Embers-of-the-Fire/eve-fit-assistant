# -*- coding: utf-8 -*-
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# NO CHECKED-IN PROTOBUF GENCODE
# source: dynamic_item.proto
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
    'dynamic_item.proto'
)
# @@protoc_insertion_point(imports)

_sym_db = _symbol_database.Default()




DESCRIPTOR = _descriptor_pool.Default().AddSerializedFile(b'\n\x12\x64ynamic_item.proto\x12\x0c\x64ynamic_item\"\xb3\x04\n\x0c\x44ynamicItems\x12\x38\n\x07\x65ntries\x18\x01 \x03(\x0b\x32\'.dynamic_item.DynamicItems.EntriesEntry\x1a\x90\x03\n\x0b\x44ynamicItem\x12U\n\x12inputOutputMapping\x18\x01 \x02(\x0b\x32\x39.dynamic_item.DynamicItems.DynamicItem.InputOutputMapping\x12J\n\nattributes\x18\x02 \x03(\x0b\x32\x36.dynamic_item.DynamicItems.DynamicItem.AttributesEntry\x1a\x44\n\x12InputOutputMapping\x12\x15\n\rresultingType\x18\x01 \x02(\x05\x12\x17\n\x0f\x61pplicableTypes\x18\x02 \x03(\x05\x1a,\n\x10\x44ynamicAttribute\x12\x0b\n\x03max\x18\x01 \x02(\x01\x12\x0b\n\x03min\x18\x02 \x02(\x01\x1aj\n\x0f\x41ttributesEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12\x46\n\x05value\x18\x02 \x01(\x0b\x32\x37.dynamic_item.DynamicItems.DynamicItem.DynamicAttribute:\x02\x38\x01\x1aV\n\x0c\x45ntriesEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12\x35\n\x05value\x18\x02 \x01(\x0b\x32&.dynamic_item.DynamicItems.DynamicItem:\x02\x38\x01\"\xc9\x01\n\x0c\x44ynamicTypes\x12\x38\n\x07\x65ntries\x18\x01 \x03(\x0b\x32\'.dynamic_item.DynamicTypes.EntriesEntry\x1a\'\n\x0b\x44ynamicType\x12\x18\n\x10mutaplasmidTypes\x18\x01 \x03(\x05\x1aV\n\x0c\x45ntriesEntry\x12\x0b\n\x03key\x18\x01 \x01(\x05\x12\x35\n\x05value\x18\x02 \x01(\x0b\x32&.dynamic_item.DynamicTypes.DynamicType:\x02\x38\x01')

_globals = globals()
_builder.BuildMessageAndEnumDescriptors(DESCRIPTOR, _globals)
_builder.BuildTopDescriptorsAndMessages(DESCRIPTOR, 'dynamic_item_pb2', _globals)
if not _descriptor._USE_C_DESCRIPTORS:
  DESCRIPTOR._loaded_options = None
  _globals['_DYNAMICITEMS_DYNAMICITEM_ATTRIBUTESENTRY']._loaded_options = None
  _globals['_DYNAMICITEMS_DYNAMICITEM_ATTRIBUTESENTRY']._serialized_options = b'8\001'
  _globals['_DYNAMICITEMS_ENTRIESENTRY']._loaded_options = None
  _globals['_DYNAMICITEMS_ENTRIESENTRY']._serialized_options = b'8\001'
  _globals['_DYNAMICTYPES_ENTRIESENTRY']._loaded_options = None
  _globals['_DYNAMICTYPES_ENTRIESENTRY']._serialized_options = b'8\001'
  _globals['_DYNAMICITEMS']._serialized_start=37
  _globals['_DYNAMICITEMS']._serialized_end=600
  _globals['_DYNAMICITEMS_DYNAMICITEM']._serialized_start=112
  _globals['_DYNAMICITEMS_DYNAMICITEM']._serialized_end=512
  _globals['_DYNAMICITEMS_DYNAMICITEM_INPUTOUTPUTMAPPING']._serialized_start=290
  _globals['_DYNAMICITEMS_DYNAMICITEM_INPUTOUTPUTMAPPING']._serialized_end=358
  _globals['_DYNAMICITEMS_DYNAMICITEM_DYNAMICATTRIBUTE']._serialized_start=360
  _globals['_DYNAMICITEMS_DYNAMICITEM_DYNAMICATTRIBUTE']._serialized_end=404
  _globals['_DYNAMICITEMS_DYNAMICITEM_ATTRIBUTESENTRY']._serialized_start=406
  _globals['_DYNAMICITEMS_DYNAMICITEM_ATTRIBUTESENTRY']._serialized_end=512
  _globals['_DYNAMICITEMS_ENTRIESENTRY']._serialized_start=514
  _globals['_DYNAMICITEMS_ENTRIESENTRY']._serialized_end=600
  _globals['_DYNAMICTYPES']._serialized_start=603
  _globals['_DYNAMICTYPES']._serialized_end=804
  _globals['_DYNAMICTYPES_DYNAMICTYPE']._serialized_start=677
  _globals['_DYNAMICTYPES_DYNAMICTYPE']._serialized_end=716
  _globals['_DYNAMICTYPES_ENTRIESENTRY']._serialized_start=718
  _globals['_DYNAMICTYPES_ENTRIESENTRY']._serialized_end=804
# @@protoc_insertion_point(module_scope)
