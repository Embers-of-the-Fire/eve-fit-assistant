// This file is automatically generated, so please do not edit it.
// @generated by `flutter_rust_bridge`@ 2.8.0.

// ignore_for_file: invalid_use_of_internal_member, unused_import, unnecessary_import

import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

import '../frb_generated.dart';
import 'schema.dart';

// These functions are ignored because they are not marked as `pub`: `from_native_grouped`, `from_native_grouped`, `from_native`, `from_native`, `from_native`, `from_native`, `from_native`
// These function are ignored because they are on traits that is not defined in current crate (put an empty `#[frb]` on it to unignore): `clone`, `clone`, `clone`, `clone`, `clone`, `fmt`, `fmt`, `fmt`, `fmt`, `fmt`

class DroneProxy {
  final int groupIndex;
  final List<ItemProxy> drones;

  const DroneProxy({
    required this.groupIndex,
    required this.drones,
  });

  @override
  int get hashCode => groupIndex.hashCode ^ drones.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DroneProxy &&
          runtimeType == other.runtimeType &&
          groupIndex == other.groupIndex &&
          drones == other.drones;
}

class FighterProxy {
  final int groupIndex;
  final List<ItemProxy> fighters;

  const FighterProxy({
    required this.groupIndex,
    required this.fighters,
  });

  @override
  int get hashCode => groupIndex.hashCode ^ fighters.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FighterProxy &&
          runtimeType == other.runtimeType &&
          groupIndex == other.groupIndex &&
          fighters == other.fighters;
}

class ItemProxy {
  final int? index;
  final int itemId;
  final ItemProxy? charge;
  final Map<int, double> attributes;

  const ItemProxy({
    this.index,
    required this.itemId,
    this.charge,
    required this.attributes,
  });

  @override
  int get hashCode => index.hashCode ^ itemId.hashCode ^ charge.hashCode ^ attributes.hashCode;

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
  final ItemProxy? tacticalMode;
  final List<DroneProxy> drones;
  final List<FighterProxy> fighters;

  const ModulesProxy({
    required this.high,
    required this.medium,
    required this.low,
    required this.rig,
    required this.subsystem,
    this.tacticalMode,
    required this.drones,
    required this.fighters,
  });

  static Future<ModulesProxy> default_() => RustLib.instance.api.crateApiProxyModulesProxyDefault();

  @override
  int get hashCode =>
      high.hashCode ^
      medium.hashCode ^
      low.hashCode ^
      rig.hashCode ^
      subsystem.hashCode ^
      tacticalMode.hashCode ^
      drones.hashCode ^
      fighters.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ModulesProxy &&
          runtimeType == other.runtimeType &&
          high == other.high &&
          medium == other.medium &&
          low == other.low &&
          rig == other.rig &&
          subsystem == other.subsystem &&
          tacticalMode == other.tacticalMode &&
          drones == other.drones &&
          fighters == other.fighters;
}

class ShipProxy {
  final ItemProxy hull;
  final ModulesProxy modules;
  final List<ItemProxy> implants;
  final ItemProxy character;
  final DamageProfile damageProfile;

  const ShipProxy({
    required this.hull,
    required this.modules,
    required this.implants,
    required this.character,
    required this.damageProfile,
  });

  @override
  int get hashCode =>
      hull.hashCode ^
      modules.hashCode ^
      implants.hashCode ^
      character.hashCode ^
      damageProfile.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ShipProxy &&
          runtimeType == other.runtimeType &&
          hull == other.hull &&
          modules == other.modules &&
          implants == other.implants &&
          character == other.character &&
          damageProfile == other.damageProfile;
}
