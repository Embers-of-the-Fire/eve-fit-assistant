// This file is automatically generated, so please do not edit it.
// @generated by `flutter_rust_bridge`@ 2.8.0.

// ignore_for_file: unused_import, unused_element, unnecessary_import, duplicate_ignore, invalid_use_of_internal_member, annotate_overrides, non_constant_identifier_names, curly_braces_in_flow_control_structures, prefer_const_literals_to_create_immutables, unused_field

import 'dart:async';
import 'dart:convert';
import 'dart:ffi' as ffi;

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart';

import 'api.dart';
import 'api/data.dart';
import 'api/error.dart';
import 'api/proxy.dart';
import 'api/schema.dart';
import 'api/simple.dart';
import 'api/validate/post_validate/charge.dart';
import 'api/validate/post_validate/max_activate.dart';
import 'api/validate/pre_validate/fit_target.dart';
import 'api/validate/pre_validate/rig_size.dart';
import 'api/validate/pre_validate/slot_num.dart';
import 'frb_generated.dart';

abstract class RustLibApiImplPlatform extends BaseApiImpl<RustLibWire> {
  RustLibApiImplPlatform({
    required super.handler,
    required super.wire,
    required super.generalizedFrbRustBinding,
    required super.portManager,
  });

  CrossPlatformFinalizerArg get rust_arc_decrement_strong_count_EveDatabasePtr => wire
      ._rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabasePtr;

  @protected
  AnyhowException dco_decode_AnyhowException(dynamic raw);

  @protected
  EveDatabase
      dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          dynamic raw);

  @protected
  EveDatabase
      dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          dynamic raw);

  @protected
  Map<int, DynamicItem> dco_decode_Map_i_32_dynamic_item(dynamic raw);

  @protected
  Map<int, double> dco_decode_Map_i_32_f_64(dynamic raw);

  @protected
  Map<int, int> dco_decode_Map_i_32_u_8(dynamic raw);

  @protected
  EveDatabase dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
      dynamic raw);

  @protected
  String dco_decode_String(dynamic raw);

  @protected
  bool dco_decode_bool(dynamic raw);

  @protected
  ErrorKey dco_decode_box_autoadd_error_key(dynamic raw);

  @protected
  Fit dco_decode_box_autoadd_fit(dynamic raw);

  @protected
  int dco_decode_box_autoadd_i_32(dynamic raw);

  @protected
  Item dco_decode_box_autoadd_item(dynamic raw);

  @protected
  ItemProxy dco_decode_box_autoadd_item_proxy(dynamic raw);

  @protected
  WarningKey dco_decode_box_autoadd_warning_key(dynamic raw);

  @protected
  ItemProxy dco_decode_box_item_proxy(dynamic raw);

  @protected
  CalculateOutput dco_decode_calculate_output(dynamic raw);

  @protected
  DamageProfile dco_decode_damage_profile(dynamic raw);

  @protected
  DroneGroup dco_decode_drone_group(dynamic raw);

  @protected
  DroneProxy dco_decode_drone_proxy(dynamic raw);

  @protected
  DynamicItem dco_decode_dynamic_item(dynamic raw);

  @protected
  ErrorKey dco_decode_error_key(dynamic raw);

  @protected
  double dco_decode_f_64(dynamic raw);

  @protected
  FighterGroup dco_decode_fighter_group(dynamic raw);

  @protected
  FighterProxy dco_decode_fighter_proxy(dynamic raw);

  @protected
  Fit dco_decode_fit(dynamic raw);

  @protected
  int dco_decode_i_32(dynamic raw);

  @protected
  I32Array11 dco_decode_i_32_array_11(dynamic raw);

  @protected
  I32Array20 dco_decode_i_32_array_20(dynamic raw);

  @protected
  I32Array5 dco_decode_i_32_array_5(dynamic raw);

  @protected
  Implant dco_decode_implant(dynamic raw);

  @protected
  Item dco_decode_item(dynamic raw);

  @protected
  ItemProxy dco_decode_item_proxy(dynamic raw);

  @protected
  ItemState dco_decode_item_state(dynamic raw);

  @protected
  List<DroneGroup> dco_decode_list_drone_group(dynamic raw);

  @protected
  List<DroneProxy> dco_decode_list_drone_proxy(dynamic raw);

  @protected
  List<FighterGroup> dco_decode_list_fighter_group(dynamic raw);

  @protected
  List<FighterProxy> dco_decode_list_fighter_proxy(dynamic raw);

  @protected
  List<Implant> dco_decode_list_implant(dynamic raw);

  @protected
  List<Item> dco_decode_list_item(dynamic raw);

  @protected
  List<ItemProxy> dco_decode_list_item_proxy(dynamic raw);

  @protected
  Int32List dco_decode_list_prim_i_32_strict(dynamic raw);

  @protected
  List<int> dco_decode_list_prim_u_8_loose(dynamic raw);

  @protected
  Uint8List dco_decode_list_prim_u_8_strict(dynamic raw);

  @protected
  List<(int, DynamicItem)> dco_decode_list_record_i_32_dynamic_item(dynamic raw);

  @protected
  List<(int, double)> dco_decode_list_record_i_32_f_64(dynamic raw);

  @protected
  List<(int, int)> dco_decode_list_record_i_32_u_8(dynamic raw);

  @protected
  List<SlotInfo> dco_decode_list_slot_info(dynamic raw);

  @protected
  Module dco_decode_module(dynamic raw);

  @protected
  ModulesProxy dco_decode_modules_proxy(dynamic raw);

  @protected
  int? dco_decode_opt_box_autoadd_i_32(dynamic raw);

  @protected
  Item? dco_decode_opt_box_autoadd_item(dynamic raw);

  @protected
  ItemProxy? dco_decode_opt_box_autoadd_item_proxy(dynamic raw);

  @protected
  ItemProxy? dco_decode_opt_box_item_proxy(dynamic raw);

  @protected
  (int, DynamicItem) dco_decode_record_i_32_dynamic_item(dynamic raw);

  @protected
  (int, double) dco_decode_record_i_32_f_64(dynamic raw);

  @protected
  (int, int) dco_decode_record_i_32_u_8(dynamic raw);

  @protected
  ShipProxy dco_decode_ship_proxy(dynamic raw);

  @protected
  SlotInfo dco_decode_slot_info(dynamic raw);

  @protected
  SlotType dco_decode_slot_type(dynamic raw);

  @protected
  int dco_decode_u_8(dynamic raw);

  @protected
  void dco_decode_unit(dynamic raw);

  @protected
  BigInt dco_decode_usize(dynamic raw);

  @protected
  WarningKey dco_decode_warning_key(dynamic raw);

  @protected
  AnyhowException sse_decode_AnyhowException(SseDeserializer deserializer);

  @protected
  EveDatabase
      sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          SseDeserializer deserializer);

  @protected
  EveDatabase
      sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          SseDeserializer deserializer);

  @protected
  Map<int, DynamicItem> sse_decode_Map_i_32_dynamic_item(SseDeserializer deserializer);

  @protected
  Map<int, double> sse_decode_Map_i_32_f_64(SseDeserializer deserializer);

  @protected
  Map<int, int> sse_decode_Map_i_32_u_8(SseDeserializer deserializer);

  @protected
  EveDatabase sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
      SseDeserializer deserializer);

  @protected
  String sse_decode_String(SseDeserializer deserializer);

  @protected
  bool sse_decode_bool(SseDeserializer deserializer);

  @protected
  ErrorKey sse_decode_box_autoadd_error_key(SseDeserializer deserializer);

  @protected
  Fit sse_decode_box_autoadd_fit(SseDeserializer deserializer);

  @protected
  int sse_decode_box_autoadd_i_32(SseDeserializer deserializer);

  @protected
  Item sse_decode_box_autoadd_item(SseDeserializer deserializer);

  @protected
  ItemProxy sse_decode_box_autoadd_item_proxy(SseDeserializer deserializer);

  @protected
  WarningKey sse_decode_box_autoadd_warning_key(SseDeserializer deserializer);

  @protected
  ItemProxy sse_decode_box_item_proxy(SseDeserializer deserializer);

  @protected
  CalculateOutput sse_decode_calculate_output(SseDeserializer deserializer);

  @protected
  DamageProfile sse_decode_damage_profile(SseDeserializer deserializer);

  @protected
  DroneGroup sse_decode_drone_group(SseDeserializer deserializer);

  @protected
  DroneProxy sse_decode_drone_proxy(SseDeserializer deserializer);

  @protected
  DynamicItem sse_decode_dynamic_item(SseDeserializer deserializer);

  @protected
  ErrorKey sse_decode_error_key(SseDeserializer deserializer);

  @protected
  double sse_decode_f_64(SseDeserializer deserializer);

  @protected
  FighterGroup sse_decode_fighter_group(SseDeserializer deserializer);

  @protected
  FighterProxy sse_decode_fighter_proxy(SseDeserializer deserializer);

  @protected
  Fit sse_decode_fit(SseDeserializer deserializer);

  @protected
  int sse_decode_i_32(SseDeserializer deserializer);

  @protected
  I32Array11 sse_decode_i_32_array_11(SseDeserializer deserializer);

  @protected
  I32Array20 sse_decode_i_32_array_20(SseDeserializer deserializer);

  @protected
  I32Array5 sse_decode_i_32_array_5(SseDeserializer deserializer);

  @protected
  Implant sse_decode_implant(SseDeserializer deserializer);

  @protected
  Item sse_decode_item(SseDeserializer deserializer);

  @protected
  ItemProxy sse_decode_item_proxy(SseDeserializer deserializer);

  @protected
  ItemState sse_decode_item_state(SseDeserializer deserializer);

  @protected
  List<DroneGroup> sse_decode_list_drone_group(SseDeserializer deserializer);

  @protected
  List<DroneProxy> sse_decode_list_drone_proxy(SseDeserializer deserializer);

  @protected
  List<FighterGroup> sse_decode_list_fighter_group(SseDeserializer deserializer);

  @protected
  List<FighterProxy> sse_decode_list_fighter_proxy(SseDeserializer deserializer);

  @protected
  List<Implant> sse_decode_list_implant(SseDeserializer deserializer);

  @protected
  List<Item> sse_decode_list_item(SseDeserializer deserializer);

  @protected
  List<ItemProxy> sse_decode_list_item_proxy(SseDeserializer deserializer);

  @protected
  Int32List sse_decode_list_prim_i_32_strict(SseDeserializer deserializer);

  @protected
  List<int> sse_decode_list_prim_u_8_loose(SseDeserializer deserializer);

  @protected
  Uint8List sse_decode_list_prim_u_8_strict(SseDeserializer deserializer);

  @protected
  List<(int, DynamicItem)> sse_decode_list_record_i_32_dynamic_item(SseDeserializer deserializer);

  @protected
  List<(int, double)> sse_decode_list_record_i_32_f_64(SseDeserializer deserializer);

  @protected
  List<(int, int)> sse_decode_list_record_i_32_u_8(SseDeserializer deserializer);

  @protected
  List<SlotInfo> sse_decode_list_slot_info(SseDeserializer deserializer);

  @protected
  Module sse_decode_module(SseDeserializer deserializer);

  @protected
  ModulesProxy sse_decode_modules_proxy(SseDeserializer deserializer);

  @protected
  int? sse_decode_opt_box_autoadd_i_32(SseDeserializer deserializer);

  @protected
  Item? sse_decode_opt_box_autoadd_item(SseDeserializer deserializer);

  @protected
  ItemProxy? sse_decode_opt_box_autoadd_item_proxy(SseDeserializer deserializer);

  @protected
  ItemProxy? sse_decode_opt_box_item_proxy(SseDeserializer deserializer);

  @protected
  (int, DynamicItem) sse_decode_record_i_32_dynamic_item(SseDeserializer deserializer);

  @protected
  (int, double) sse_decode_record_i_32_f_64(SseDeserializer deserializer);

  @protected
  (int, int) sse_decode_record_i_32_u_8(SseDeserializer deserializer);

  @protected
  ShipProxy sse_decode_ship_proxy(SseDeserializer deserializer);

  @protected
  SlotInfo sse_decode_slot_info(SseDeserializer deserializer);

  @protected
  SlotType sse_decode_slot_type(SseDeserializer deserializer);

  @protected
  int sse_decode_u_8(SseDeserializer deserializer);

  @protected
  void sse_decode_unit(SseDeserializer deserializer);

  @protected
  BigInt sse_decode_usize(SseDeserializer deserializer);

  @protected
  WarningKey sse_decode_warning_key(SseDeserializer deserializer);

  @protected
  void sse_encode_AnyhowException(AnyhowException self, SseSerializer serializer);

  @protected
  void
      sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          EveDatabase self, SseSerializer serializer);

  @protected
  void
      sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          EveDatabase self, SseSerializer serializer);

  @protected
  void sse_encode_Map_i_32_dynamic_item(Map<int, DynamicItem> self, SseSerializer serializer);

  @protected
  void sse_encode_Map_i_32_f_64(Map<int, double> self, SseSerializer serializer);

  @protected
  void sse_encode_Map_i_32_u_8(Map<int, int> self, SseSerializer serializer);

  @protected
  void sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
      EveDatabase self, SseSerializer serializer);

  @protected
  void sse_encode_String(String self, SseSerializer serializer);

  @protected
  void sse_encode_bool(bool self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_error_key(ErrorKey self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_fit(Fit self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_i_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_item(Item self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_item_proxy(ItemProxy self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_warning_key(WarningKey self, SseSerializer serializer);

  @protected
  void sse_encode_box_item_proxy(ItemProxy self, SseSerializer serializer);

  @protected
  void sse_encode_calculate_output(CalculateOutput self, SseSerializer serializer);

  @protected
  void sse_encode_damage_profile(DamageProfile self, SseSerializer serializer);

  @protected
  void sse_encode_drone_group(DroneGroup self, SseSerializer serializer);

  @protected
  void sse_encode_drone_proxy(DroneProxy self, SseSerializer serializer);

  @protected
  void sse_encode_dynamic_item(DynamicItem self, SseSerializer serializer);

  @protected
  void sse_encode_error_key(ErrorKey self, SseSerializer serializer);

  @protected
  void sse_encode_f_64(double self, SseSerializer serializer);

  @protected
  void sse_encode_fighter_group(FighterGroup self, SseSerializer serializer);

  @protected
  void sse_encode_fighter_proxy(FighterProxy self, SseSerializer serializer);

  @protected
  void sse_encode_fit(Fit self, SseSerializer serializer);

  @protected
  void sse_encode_i_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_i_32_array_11(I32Array11 self, SseSerializer serializer);

  @protected
  void sse_encode_i_32_array_20(I32Array20 self, SseSerializer serializer);

  @protected
  void sse_encode_i_32_array_5(I32Array5 self, SseSerializer serializer);

  @protected
  void sse_encode_implant(Implant self, SseSerializer serializer);

  @protected
  void sse_encode_item(Item self, SseSerializer serializer);

  @protected
  void sse_encode_item_proxy(ItemProxy self, SseSerializer serializer);

  @protected
  void sse_encode_item_state(ItemState self, SseSerializer serializer);

  @protected
  void sse_encode_list_drone_group(List<DroneGroup> self, SseSerializer serializer);

  @protected
  void sse_encode_list_drone_proxy(List<DroneProxy> self, SseSerializer serializer);

  @protected
  void sse_encode_list_fighter_group(List<FighterGroup> self, SseSerializer serializer);

  @protected
  void sse_encode_list_fighter_proxy(List<FighterProxy> self, SseSerializer serializer);

  @protected
  void sse_encode_list_implant(List<Implant> self, SseSerializer serializer);

  @protected
  void sse_encode_list_item(List<Item> self, SseSerializer serializer);

  @protected
  void sse_encode_list_item_proxy(List<ItemProxy> self, SseSerializer serializer);

  @protected
  void sse_encode_list_prim_i_32_strict(Int32List self, SseSerializer serializer);

  @protected
  void sse_encode_list_prim_u_8_loose(List<int> self, SseSerializer serializer);

  @protected
  void sse_encode_list_prim_u_8_strict(Uint8List self, SseSerializer serializer);

  @protected
  void sse_encode_list_record_i_32_dynamic_item(
      List<(int, DynamicItem)> self, SseSerializer serializer);

  @protected
  void sse_encode_list_record_i_32_f_64(List<(int, double)> self, SseSerializer serializer);

  @protected
  void sse_encode_list_record_i_32_u_8(List<(int, int)> self, SseSerializer serializer);

  @protected
  void sse_encode_list_slot_info(List<SlotInfo> self, SseSerializer serializer);

  @protected
  void sse_encode_module(Module self, SseSerializer serializer);

  @protected
  void sse_encode_modules_proxy(ModulesProxy self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_autoadd_i_32(int? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_autoadd_item(Item? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_autoadd_item_proxy(ItemProxy? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_item_proxy(ItemProxy? self, SseSerializer serializer);

  @protected
  void sse_encode_record_i_32_dynamic_item((int, DynamicItem) self, SseSerializer serializer);

  @protected
  void sse_encode_record_i_32_f_64((int, double) self, SseSerializer serializer);

  @protected
  void sse_encode_record_i_32_u_8((int, int) self, SseSerializer serializer);

  @protected
  void sse_encode_ship_proxy(ShipProxy self, SseSerializer serializer);

  @protected
  void sse_encode_slot_info(SlotInfo self, SseSerializer serializer);

  @protected
  void sse_encode_slot_type(SlotType self, SseSerializer serializer);

  @protected
  void sse_encode_u_8(int self, SseSerializer serializer);

  @protected
  void sse_encode_unit(void self, SseSerializer serializer);

  @protected
  void sse_encode_usize(BigInt self, SseSerializer serializer);

  @protected
  void sse_encode_warning_key(WarningKey self, SseSerializer serializer);
}

// Section: wire_class

class RustLibWire implements BaseWire {
  factory RustLibWire.fromExternalLibrary(ExternalLibrary lib) =>
      RustLibWire(lib.ffiDynamicLibrary);

  /// Holds the symbol lookup function.
  final ffi.Pointer<T> Function<T extends ffi.NativeType>(String symbolName) _lookup;

  /// The symbols are looked up in [dynamicLibrary].
  RustLibWire(ffi.DynamicLibrary dynamicLibrary) : _lookup = dynamicLibrary.lookup;

  void
      rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
    ffi.Pointer<ffi.Void> ptr,
  ) {
    return _rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
      ptr,
    );
  }

  late final _rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabasePtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>>(
          'frbgen_eve_fit_assistant_rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase');
  late final _rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase =
      _rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabasePtr
          .asFunction<void Function(ffi.Pointer<ffi.Void>)>();

  void
      rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
    ffi.Pointer<ffi.Void> ptr,
  ) {
    return _rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
      ptr,
    );
  }

  late final _rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabasePtr =
      _lookup<ffi.NativeFunction<ffi.Void Function(ffi.Pointer<ffi.Void>)>>(
          'frbgen_eve_fit_assistant_rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase');
  late final _rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase =
      _rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabasePtr
          .asFunction<void Function(ffi.Pointer<ffi.Void>)>();
}
