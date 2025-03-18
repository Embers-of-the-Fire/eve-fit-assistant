// This file is automatically generated, so please do not edit it.
// @generated by `flutter_rust_bridge`@ 2.8.0.

// ignore_for_file: invalid_use_of_internal_member, unused_import, unnecessary_import

import '../frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';
import 'package:freezed_annotation/freezed_annotation.dart' hide protected;
part 'error.freezed.dart';

// These function are ignored because they are on traits that is not defined in current crate (put an empty `#[frb]` on it to unignore): `assert_receiver_is_total_eq`, `clone`, `clone`, `clone`, `clone`, `eq`, `eq`, `eq`, `eq`, `fmt`, `fmt`, `fmt`, `fmt`

@freezed
sealed class ErrorKey with _$ErrorKey {
  const ErrorKey._();

  const factory ErrorKey.incompatibleChargeSize({
    required int expected,
    required int actual,
  }) = ErrorKey_IncompatibleChargeSize;
  const factory ErrorKey.incompatibleChargeCapacity({
    required double max,
    required double actual,
  }) = ErrorKey_IncompatibleChargeCapacity;
  const factory ErrorKey.tooMuchTurret({
    required int expected,
    required int actual,
  }) = ErrorKey_TooMuchTurret;
  const factory ErrorKey.tooMuchLauncher({
    required int expected,
    required int actual,
  }) = ErrorKey_TooMuchLauncher;
  const factory ErrorKey.conflictItem({
    required int groupId,
  }) = ErrorKey_ConflictItem;
  const factory ErrorKey.incompatibleShipGroup({
    required Int32List expected,
  }) = ErrorKey_IncompatibleShipGroup;
  const factory ErrorKey.incompatibleShipType({
    required Int32List expected,
  }) = ErrorKey_IncompatibleShipType;
  const factory ErrorKey.incompatibleRigSize({
    required int expected,
    required int actual,
  }) = ErrorKey_IncompatibleRigSize;
}

@freezed
sealed class SlotInfo with _$SlotInfo {
  const SlotInfo._();

  const factory SlotInfo.error({
    required SlotType slot,
    int? index,
    required ErrorKey errorKey,
  }) = SlotInfo_Error;
  const factory SlotInfo.warning({
    required SlotType slot,
    int? index,
    required WarningKey warningKey,
  }) = SlotInfo_Warning;
}

enum SlotType {
  high,
  medium,
  low,
  rig,
  subsystem,
  implant,
  booster,
  drone,
  fighter,
  ;
}

@freezed
sealed class WarningKey with _$WarningKey {
  const WarningKey._();

  const factory WarningKey.missingCharge() = WarningKey_MissingCharge;
  const factory WarningKey.placeholder(
    int field0,
  ) = WarningKey_Placeholder;
}
