// This file is automatically generated, so please do not edit it.
// @generated by `flutter_rust_bridge`@ 2.8.0.

// ignore_for_file: invalid_use_of_internal_member, unused_import, unnecessary_import

import '../frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

// These functions are ignored because they are not marked as `pub`: `from_native`, `from_native`, `from_native`, `from_native`
// These function are ignored because they are on traits that is not defined in current crate (put an empty `#[frb]` on it to unignore): `clone`, `clone`, `clone`, `clone`, `fmt`, `fmt`, `fmt`, `fmt`

// Rust type: RustOpaqueMoi<flutter_rust_bridge::for_generated::RustAutoOpaqueInner<AttributesProxy>>
abstract class AttributesProxy implements RustOpaqueInterface {
  double? getById({required int key});
}

class ItemProxy {
  final int? index;
  final int itemId;
  final ItemProxy? charge;
  final AttributesProxy attributes;

  const ItemProxy({
    this.index,
    required this.itemId,
    this.charge,
    required this.attributes,
  });

  @override
  int get hashCode =>
      index.hashCode ^ itemId.hashCode ^ charge.hashCode ^ attributes.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ItemProxy &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          itemId == other.itemId &&
          charge == other.charge &&
          attributes == other.attributes;
}

class ModulesProxy {
  final List<ItemProxy> high;
  final List<ItemProxy> medium;
  final List<ItemProxy> low;
  final List<ItemProxy> rig;
  final List<ItemProxy> subsystem;

  const ModulesProxy({
    required this.high,
    required this.medium,
    required this.low,
    required this.rig,
    required this.subsystem,
  });

  static Future<ModulesProxy> default_() =>
      RustLib.instance.api.crateApiProxyModulesProxyDefault();

  @override
  int get hashCode =>
      high.hashCode ^
      medium.hashCode ^
      low.hashCode ^
      rig.hashCode ^
      subsystem.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModulesProxy &&
          runtimeType == other.runtimeType &&
          high == other.high &&
          medium == other.medium &&
          low == other.low &&
          rig == other.rig &&
          subsystem == other.subsystem;
}

class ShipProxy {
  final ItemProxy hull;
  final ModulesProxy modules;
  final List<ItemProxy> implants;
  final ItemProxy character;

  const ShipProxy({
    required this.hull,
    required this.modules,
    required this.implants,
    required this.character,
  });

  @override
  int get hashCode =>
      hull.hashCode ^ modules.hashCode ^ implants.hashCode ^ character.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShipProxy &&
          runtimeType == other.runtimeType &&
          hull == other.hull &&
          modules == other.modules &&
          implants == other.implants &&
          character == other.character;
}
