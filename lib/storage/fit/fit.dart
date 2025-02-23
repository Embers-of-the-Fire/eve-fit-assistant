import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:eve_fit_assistant/native/codegen/constant/character.dart';
import 'package:eve_fit_assistant/native/port/api/error.dart';
import 'package:eve_fit_assistant/storage/fit/fit_record.dart';
import 'package:eve_fit_assistant/storage/fit/storage.dart';
import 'package:eve_fit_assistant/storage/proto/slots.pb.dart';
import 'package:eve_fit_assistant/storage/static/damage_profile.dart';
import 'package:eve_fit_assistant/storage/static/ship_subsystems.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'fit.freezed.dart';
part 'fit.g.dart';

enum FitItemType {
  high,
  med,
  low,
  rig,
  subsystem,
  drone,
  implant;

  factory FitItemType.fromNative(SlotType type) {
    switch (type) {
      case SlotType.high:
        return FitItemType.high;
      case SlotType.medium:
        return FitItemType.med;
      case SlotType.low:
        return FitItemType.low;
      case SlotType.rig:
        return FitItemType.rig;
      case SlotType.subsystem:
        return FitItemType.subsystem;
      case SlotType.drone:
        return FitItemType.drone;
      case SlotType.implant:
        return FitItemType.implant;
    }
  }
}

@JsonSerializable(explicitToJson: true)
class FitRecord {
  final FitRecordBrief brief;
  final Fit body;

  /// Do not directly use this constructor, use [FitRecord.init] instead.
  FitRecord({
    required this.brief,
    required this.body,
  });

  factory FitRecord.init(FitRecordBrief brief, int shipID) => FitRecord(
        brief: brief,
        body: Fit.init(shipID),
      );

  void modifyHigh(int index, SlotItem? Function(SlotItem?) map) {
    body.high[index] = map(body.high[index]);
  }

  void modifyMed(int index, SlotItem? Function(SlotItem?) map) {
    body.med[index] = map(body.med[index]);
  }

  void modifyLow(int index, SlotItem? Function(SlotItem?) map) {
    body.low[index] = map(body.low[index]);
  }

  void modifyRig(int index, SlotItem? Function(SlotItem?) map) {
    body.rig[index] = map(body.rig[index]);
  }

  void modifyImplant(int index, SlotItem? Function(SlotItem?) map) {
    body.implant[index] = map(body.implant[index]);
  }

  void clearImplant() {
    body.implant.fillAll(null);
  }

  void modifyDrone(int index, DroneItem Function(DroneItem) map) {
    final drone = map(body.drone[index]);
    if (drone.amount <= 0) {
      body.drone.removeAt(index);
      return;
    }
    body.drone[index] = drone;
  }

  void addDrone(int droneID) {
    body.drone.add(DroneItem(itemID: droneID, amount: 1, state: DroneState.active));
  }

  void removeDrone(int index) {
    body.drone.removeAt(index);
  }

  void clearDrone() {
    body.drone.clear();
  }

  void modifyFighter(int index, FighterItem Function(FighterItem) map) {
    final fighter = map(body.fighter[index]);
    if (fighter.amount <= 0) {
      body.fighter.removeAt(index);
      return;
    }
    body.fighter[index] = fighter;
  }

  void addFighter(int fighterID) {
    final amount = GlobalStorage().static.fighters[fighterID]?.amount ?? 1;
    body.fighter.add(FighterItem(
      itemID: fighterID,
      amount: amount,
      ability: 0,
      state: DroneState.active,
    ));
  }

  void removeFighter(int index) {
    body.fighter.removeAt(index);
  }

  void clearFighter() {
    body.fighter.clear();
  }

  void addSubsystem(SubsystemType type, int typeID) {
    body.subsystem[type.value] = SlotItem(itemID: typeID, chargeID: null, state: SlotState.online);
    _postSubsystemModify();
  }

  void removeSubsystem(SubsystemType type) {
    body.subsystem[type.value] = null;
    _postSubsystemModify();
  }

  void _postSubsystemModify() {
    int high = 0;
    int med = 0;
    int low = 0;
    for (final subsystem in body.subsystem) {
      if (subsystem == null) continue;

      final type = GlobalStorage().static.subsystems.items[subsystem.itemID];
      if (type == null) continue;
      high += type.high;
      med += type.medium;
      low += type.low;
    }

    void modifySlot(List<SlotItem?> slot, int targetLength) {
      if (slot.length < targetLength) {
        slot.addAll(List.filled(targetLength - slot.length, null));
      } else if (slot.length > targetLength) {
        slot.removeRange(targetLength, slot.length);
      }
    }

    modifySlot(body.high, high);
    modifySlot(body.med, med);
    modifySlot(body.low, low);
  }

  void changeTacticalMode() {
    if (body.tacticalModeID == null) {
      return;
    }
    final modeIDs =
        GlobalStorage().static.tacticalModes[body.shipID]?.tacticalModes.keys.toList() ?? [];
    body.tacticalModeID = modeIDs[(modeIDs.indexOf(body.tacticalModeID!) + 1) % modeIDs.length];
  }

  Future<void> save() async {
    final fullRecordDir = await getFitFullDir(create: true);
    final file = File('${fullRecordDir.path}/${brief.id}.json');
    brief.lastModifyTime = DateTime.now().millisecondsSinceEpoch;
    await file.writeAsString(jsonEncode(toJson()));
    await GlobalStorage().ship.updateBrief(brief);
    dev.log(
      'FitRecord.save done',
      name: 'FitRecord.save',
      time: DateTime.now(),
    );
  }

  static Future<void> delete(String id) async {
    final fullRecordDir = await getFitFullDir(create: false);
    final file = File('${fullRecordDir.path}/$id.json');
    await file.delete();
  }

  static Future<FitRecord> read(String id) async {
    final fullRecordDir = await getFitFullDir(create: false);
    final file = File('${fullRecordDir.path}/$id.json');
    final json = jsonDecode(await file.readAsString());
    final rec = FitRecord.fromJson(json);
    return rec;
  }

  factory FitRecord.fromJson(Map<String, dynamic> json) => _$FitRecordFromJson(json);

  Map<String, dynamic> toJson() => _$FitRecordToJson(this);
}

@JsonSerializable(explicitToJson: true)
class Fit {
  final int shipID;
  String characterID;

  DamageProfile damageProfile;

  final List<SlotItem?> high;
  final List<SlotItem?> med;
  final List<SlotItem?> low;
  final List<SlotItem?> rig;

  final List<SlotItem?> subsystem;

  final List<DroneItem> drone;
  final List<FighterItem> fighter;
  final List<SlotItem?> implant;

  int? tacticalModeID;

  /// Do not use this constructor directly, use [Fit.init] instead.
  Fit({
    required this.shipID,
    this.characterID = predefinedLevelAll5,
    this.damageProfile = DamageProfile.defaultProfile,
    required this.high,
    required this.med,
    required this.low,
    required this.rig,
    required this.subsystem,
    List<DroneItem>? drone,
    List<FighterItem>? fighter,
    required this.implant,
    this.tacticalModeID,
  })  : drone = drone ?? List.empty(growable: true),
        fighter = fighter ?? List.empty(growable: true);

  factory Fit.init(int shipID) {
    final ship = GlobalStorage().static.ships[shipID];
    return Fit(
      shipID: shipID,
      characterID: GlobalStorage().character.predefinedAll5.id,
      damageProfile: DamageProfile.defaultProfile,
      high: List.filled(ship?.highSlotNum ?? 0, null, growable: true),
      med: List.filled(ship?.medSlotNum ?? 0, null, growable: true),
      low: List.filled(ship?.lowSlotNum ?? 0, null, growable: true),
      rig: List.filled(ship?.rigSlotNum ?? 0, null),
      subsystem: List.filled((ship?.hasSubsystem ?? false) ? 4 : 0, null),
      drone: List.empty(growable: true),
      fighter: List.empty(growable: true),
      implant: List.filled(10, null),
      tacticalModeID: ship?.hasTacticalMode.unwrapOr(false).thenWith(() => shipID.andThen(
          (id) => GlobalStorage().static.tacticalModes[id]?.tacticalModes.keys.firstOrNull)),
    );
  }

  List<SlotItem?> getSlots(FitItemType type) {
    switch (type) {
      case FitItemType.high:
        return high;
      case FitItemType.med:
        return med;
      case FitItemType.low:
        return low;
      case FitItemType.rig:
        return rig;
      case FitItemType.subsystem:
        return subsystem;
      case FitItemType.implant:
        return implant;
      case _:
        return [];
    }
  }

  factory Fit.fromJson(Map<String, dynamic> json) => _$FitFromJson(json);

  Map<String, dynamic> toJson() => _$FitToJson(this);
}

@freezed
class SlotItem with _$SlotItem {
  const factory SlotItem({
    required int itemID,
    required int? chargeID,
    required SlotState state,
  }) = _SlotItem;

  factory SlotItem.fromJson(Map<String, dynamic> json) => _$SlotItemFromJson(json);
}

@JsonEnum(valueField: 'state')
enum SlotState implements Comparable<SlotState> {
  passive(0),
  online(1),
  active(2),
  overload(3);

  final int state;

  const SlotState(this.state);

  SlotState nextState({SlotState maxState = SlotState.overload}) {
    if (index >= maxState.index) return SlotState.passive;
    final next = (index + 1) % (maxState.index + 1);
    return SlotState.values[next];
  }

  factory SlotState.fromProto(Slots_SlotState proto) {
    switch (proto) {
      case Slots_SlotState.PASSIVE:
        return SlotState.passive;
      case Slots_SlotState.ONLINE:
        return SlotState.online;
      case Slots_SlotState.ACTIVE:
        return SlotState.active;
      case Slots_SlotState.OVERLOAD:
        return SlotState.overload;
      case _:
        return SlotState.passive;
    }
  }

  @override
  int compareTo(SlotState other) => state.compareTo(other.state);

  bool operator >(SlotState other) => state > other.state;

  bool operator >=(SlotState other) => state >= other.state;

  bool operator <(SlotState other) => state < other.state;

  bool operator <=(SlotState other) => state <= other.state;
}

@freezed
class DroneItem with _$DroneItem {
  const factory DroneItem({
    required int itemID,
    required int amount,
    required DroneState state,
  }) = _DroneItem;

  factory DroneItem.fromJson(Map<String, dynamic> json) => _$DroneItemFromJson(json);
}

@JsonEnum(valueField: 'state')
enum DroneState {
  passive(0),
  active(1);

  final int state;

  const DroneState(this.state);

  DroneState nextState() => state == 0 ? DroneState.active : DroneState.passive;
}

@freezed
class FighterItem with _$FighterItem {
  const factory FighterItem({
    required int itemID,
    required int amount,
    required int ability,
    required DroneState state,
  }) = _FighterItem;

  factory FighterItem.fromJson(Map<String, dynamic> json) => _$FighterItemFromJson(json);
}
