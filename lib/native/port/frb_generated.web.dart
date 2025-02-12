// This file is automatically generated, so please do not edit it.
// @generated by `flutter_rust_bridge`@ 2.8.0.

// ignore_for_file: unused_import, unused_element, unnecessary_import, duplicate_ignore, invalid_use_of_internal_member, annotate_overrides, non_constant_identifier_names, curly_braces_in_flow_control_structures, prefer_const_literals_to_create_immutables, unused_field

// Static analysis wrongly picks the IO variant, thus ignore this
// ignore_for_file: argument_type_not_assignable

import 'api.dart';
import 'api/data.dart';
import 'api/error.dart';
import 'api/proxy.dart';
import 'api/schema.dart';
import 'api/simple.dart';
import 'api/validate.dart';
import 'dart:async';
import 'dart:convert';
import 'frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_web.dart';

abstract class RustLibApiImplPlatform extends BaseApiImpl<RustLibWire> {
  RustLibApiImplPlatform({
    required super.handler,
    required super.wire,
    required super.generalizedFrbRustBinding,
    required super.portManager,
  });

  CrossPlatformFinalizerArg
      get rust_arc_decrement_strong_count_AttributesProxyPtr => wire
          .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy;

  CrossPlatformFinalizerArg
      get rust_arc_decrement_strong_count_EveDatabasePtr => wire
          .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase;

  @protected
  AnyhowException dco_decode_AnyhowException(dynamic raw);

  @protected
  AttributesProxy
      dco_decode_AutoExplicit_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          dynamic raw);

  @protected
  AttributesProxy
      dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          dynamic raw);

  @protected
  EveDatabase
      dco_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          dynamic raw);

  @protected
  AttributesProxy
      dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          dynamic raw);

  @protected
  EveDatabase
      dco_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          dynamic raw);

  @protected
  Map<int, int> dco_decode_Map_i_32_u_8(dynamic raw);

  @protected
  AttributesProxy
      dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          dynamic raw);

  @protected
  EveDatabase
      dco_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          dynamic raw);

  @protected
  String dco_decode_String(dynamic raw);

  @protected
  ErrorKey dco_decode_box_autoadd_error_key(dynamic raw);

  @protected
  double dco_decode_box_autoadd_f_64(dynamic raw);

  @protected
  Fit dco_decode_box_autoadd_fit(dynamic raw);

  @protected
  int dco_decode_box_autoadd_i_32(dynamic raw);

  @protected
  ItemProxy dco_decode_box_item_proxy(dynamic raw);

  @protected
  CalculateOutput dco_decode_calculate_output(dynamic raw);

  @protected
  DroneGroup dco_decode_drone_group(dynamic raw);

  @protected
  ErrorKey dco_decode_error_key(dynamic raw);

  @protected
  double dco_decode_f_64(dynamic raw);

  @protected
  Fit dco_decode_fit(dynamic raw);

  @protected
  int dco_decode_i_32(dynamic raw);

  @protected
  Implant dco_decode_implant(dynamic raw);

  @protected
  Item dco_decode_item(dynamic raw);

  @protected
  ItemProxy dco_decode_item_proxy(dynamic raw);

  @protected
  List<DroneGroup> dco_decode_list_drone_group(dynamic raw);

  @protected
  List<Implant> dco_decode_list_implant(dynamic raw);

  @protected
  List<Item> dco_decode_list_item(dynamic raw);

  @protected
  List<ItemProxy> dco_decode_list_item_proxy(dynamic raw);

  @protected
  List<int> dco_decode_list_prim_u_8_loose(dynamic raw);

  @protected
  Uint8List dco_decode_list_prim_u_8_strict(dynamic raw);

  @protected
  List<(int, int)> dco_decode_list_record_i_32_u_8(dynamic raw);

  @protected
  List<SlotInfo> dco_decode_list_slot_info(dynamic raw);

  @protected
  Module dco_decode_module(dynamic raw);

  @protected
  ModulesProxy dco_decode_modules_proxy(dynamic raw);

  @protected
  double? dco_decode_opt_box_autoadd_f_64(dynamic raw);

  @protected
  int? dco_decode_opt_box_autoadd_i_32(dynamic raw);

  @protected
  ItemProxy? dco_decode_opt_box_item_proxy(dynamic raw);

  @protected
  (int, int) dco_decode_record_i_32_u_8(dynamic raw);

  @protected
  ShipProxy dco_decode_ship_proxy(dynamic raw);

  @protected
  SlotInfo dco_decode_slot_info(dynamic raw);

  @protected
  SlotType dco_decode_slot_type(dynamic raw);

  @protected
  State dco_decode_state(dynamic raw);

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
  AttributesProxy
      sse_decode_AutoExplicit_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          SseDeserializer deserializer);

  @protected
  AttributesProxy
      sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          SseDeserializer deserializer);

  @protected
  EveDatabase
      sse_decode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          SseDeserializer deserializer);

  @protected
  AttributesProxy
      sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          SseDeserializer deserializer);

  @protected
  EveDatabase
      sse_decode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          SseDeserializer deserializer);

  @protected
  Map<int, int> sse_decode_Map_i_32_u_8(SseDeserializer deserializer);

  @protected
  AttributesProxy
      sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          SseDeserializer deserializer);

  @protected
  EveDatabase
      sse_decode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          SseDeserializer deserializer);

  @protected
  String sse_decode_String(SseDeserializer deserializer);

  @protected
  ErrorKey sse_decode_box_autoadd_error_key(SseDeserializer deserializer);

  @protected
  double sse_decode_box_autoadd_f_64(SseDeserializer deserializer);

  @protected
  Fit sse_decode_box_autoadd_fit(SseDeserializer deserializer);

  @protected
  int sse_decode_box_autoadd_i_32(SseDeserializer deserializer);

  @protected
  ItemProxy sse_decode_box_item_proxy(SseDeserializer deserializer);

  @protected
  CalculateOutput sse_decode_calculate_output(SseDeserializer deserializer);

  @protected
  DroneGroup sse_decode_drone_group(SseDeserializer deserializer);

  @protected
  ErrorKey sse_decode_error_key(SseDeserializer deserializer);

  @protected
  double sse_decode_f_64(SseDeserializer deserializer);

  @protected
  Fit sse_decode_fit(SseDeserializer deserializer);

  @protected
  int sse_decode_i_32(SseDeserializer deserializer);

  @protected
  Implant sse_decode_implant(SseDeserializer deserializer);

  @protected
  Item sse_decode_item(SseDeserializer deserializer);

  @protected
  ItemProxy sse_decode_item_proxy(SseDeserializer deserializer);

  @protected
  List<DroneGroup> sse_decode_list_drone_group(SseDeserializer deserializer);

  @protected
  List<Implant> sse_decode_list_implant(SseDeserializer deserializer);

  @protected
  List<Item> sse_decode_list_item(SseDeserializer deserializer);

  @protected
  List<ItemProxy> sse_decode_list_item_proxy(SseDeserializer deserializer);

  @protected
  List<int> sse_decode_list_prim_u_8_loose(SseDeserializer deserializer);

  @protected
  Uint8List sse_decode_list_prim_u_8_strict(SseDeserializer deserializer);

  @protected
  List<(int, int)> sse_decode_list_record_i_32_u_8(
      SseDeserializer deserializer);

  @protected
  List<SlotInfo> sse_decode_list_slot_info(SseDeserializer deserializer);

  @protected
  Module sse_decode_module(SseDeserializer deserializer);

  @protected
  ModulesProxy sse_decode_modules_proxy(SseDeserializer deserializer);

  @protected
  double? sse_decode_opt_box_autoadd_f_64(SseDeserializer deserializer);

  @protected
  int? sse_decode_opt_box_autoadd_i_32(SseDeserializer deserializer);

  @protected
  ItemProxy? sse_decode_opt_box_item_proxy(SseDeserializer deserializer);

  @protected
  (int, int) sse_decode_record_i_32_u_8(SseDeserializer deserializer);

  @protected
  ShipProxy sse_decode_ship_proxy(SseDeserializer deserializer);

  @protected
  SlotInfo sse_decode_slot_info(SseDeserializer deserializer);

  @protected
  SlotType sse_decode_slot_type(SseDeserializer deserializer);

  @protected
  State sse_decode_state(SseDeserializer deserializer);

  @protected
  int sse_decode_u_8(SseDeserializer deserializer);

  @protected
  void sse_decode_unit(SseDeserializer deserializer);

  @protected
  BigInt sse_decode_usize(SseDeserializer deserializer);

  @protected
  WarningKey sse_decode_warning_key(SseDeserializer deserializer);

  @protected
  bool sse_decode_bool(SseDeserializer deserializer);

  @protected
  void sse_encode_AnyhowException(
      AnyhowException self, SseSerializer serializer);

  @protected
  void
      sse_encode_AutoExplicit_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          AttributesProxy self, SseSerializer serializer);

  @protected
  void
      sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          AttributesProxy self, SseSerializer serializer);

  @protected
  void
      sse_encode_Auto_Owned_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          EveDatabase self, SseSerializer serializer);

  @protected
  void
      sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          AttributesProxy self, SseSerializer serializer);

  @protected
  void
      sse_encode_Auto_Ref_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          EveDatabase self, SseSerializer serializer);

  @protected
  void sse_encode_Map_i_32_u_8(Map<int, int> self, SseSerializer serializer);

  @protected
  void
      sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          AttributesProxy self, SseSerializer serializer);

  @protected
  void
      sse_encode_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          EveDatabase self, SseSerializer serializer);

  @protected
  void sse_encode_String(String self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_error_key(
      ErrorKey self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_f_64(double self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_fit(Fit self, SseSerializer serializer);

  @protected
  void sse_encode_box_autoadd_i_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_box_item_proxy(ItemProxy self, SseSerializer serializer);

  @protected
  void sse_encode_calculate_output(
      CalculateOutput self, SseSerializer serializer);

  @protected
  void sse_encode_drone_group(DroneGroup self, SseSerializer serializer);

  @protected
  void sse_encode_error_key(ErrorKey self, SseSerializer serializer);

  @protected
  void sse_encode_f_64(double self, SseSerializer serializer);

  @protected
  void sse_encode_fit(Fit self, SseSerializer serializer);

  @protected
  void sse_encode_i_32(int self, SseSerializer serializer);

  @protected
  void sse_encode_implant(Implant self, SseSerializer serializer);

  @protected
  void sse_encode_item(Item self, SseSerializer serializer);

  @protected
  void sse_encode_item_proxy(ItemProxy self, SseSerializer serializer);

  @protected
  void sse_encode_list_drone_group(
      List<DroneGroup> self, SseSerializer serializer);

  @protected
  void sse_encode_list_implant(List<Implant> self, SseSerializer serializer);

  @protected
  void sse_encode_list_item(List<Item> self, SseSerializer serializer);

  @protected
  void sse_encode_list_item_proxy(
      List<ItemProxy> self, SseSerializer serializer);

  @protected
  void sse_encode_list_prim_u_8_loose(List<int> self, SseSerializer serializer);

  @protected
  void sse_encode_list_prim_u_8_strict(
      Uint8List self, SseSerializer serializer);

  @protected
  void sse_encode_list_record_i_32_u_8(
      List<(int, int)> self, SseSerializer serializer);

  @protected
  void sse_encode_list_slot_info(List<SlotInfo> self, SseSerializer serializer);

  @protected
  void sse_encode_module(Module self, SseSerializer serializer);

  @protected
  void sse_encode_modules_proxy(ModulesProxy self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_autoadd_f_64(double? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_autoadd_i_32(int? self, SseSerializer serializer);

  @protected
  void sse_encode_opt_box_item_proxy(ItemProxy? self, SseSerializer serializer);

  @protected
  void sse_encode_record_i_32_u_8((int, int) self, SseSerializer serializer);

  @protected
  void sse_encode_ship_proxy(ShipProxy self, SseSerializer serializer);

  @protected
  void sse_encode_slot_info(SlotInfo self, SseSerializer serializer);

  @protected
  void sse_encode_slot_type(SlotType self, SseSerializer serializer);

  @protected
  void sse_encode_state(State self, SseSerializer serializer);

  @protected
  void sse_encode_u_8(int self, SseSerializer serializer);

  @protected
  void sse_encode_unit(void self, SseSerializer serializer);

  @protected
  void sse_encode_usize(BigInt self, SseSerializer serializer);

  @protected
  void sse_encode_warning_key(WarningKey self, SseSerializer serializer);

  @protected
  void sse_encode_bool(bool self, SseSerializer serializer);
}

// Section: wire_class

class RustLibWire implements BaseWire {
  RustLibWire.fromExternalLibrary(ExternalLibrary lib);

  void rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          int ptr) =>
      wasmModule
          .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
              ptr);

  void rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          int ptr) =>
      wasmModule
          .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
              ptr);

  void rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          int ptr) =>
      wasmModule
          .rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
              ptr);

  void rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          int ptr) =>
      wasmModule
          .rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
              ptr);
}

@JS('wasm_bindgen')
external RustLibWasmModule get wasmModule;

@JS()
@anonymous
extension type RustLibWasmModule._(JSObject _) implements JSObject {
  external void
      rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          int ptr);

  external void
      rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerAttributesProxy(
          int ptr);

  external void
      rust_arc_increment_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          int ptr);

  external void
      rust_arc_decrement_strong_count_RustOpaque_flutter_rust_bridgefor_generatedRustAutoOpaqueInnerEveDatabase(
          int ptr);
}
