import 'dart:convert';
import 'dart:developer' as dev;
import 'dart:io';

import 'package:eve_fit_assistant/native/port/api/error.dart';
import 'package:eve_fit_assistant/storage/fit/fit_record.dart';
import 'package:eve_fit_assistant/storage/path.dart';
import 'package:eve_fit_assistant/storage/proto/slots.pb.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
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

  factory FitRecord.init(FitRecordBrief brief, int shipID) {
    return FitRecord(
      brief: brief,
      body: Fit.init(shipID),
    );
  }

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

  Future<void> save() async {
    final fullRecordDir = await getFullRecordDir(create: true);
    final file = File('${fullRecordDir.path}/${brief.id}.json');
    brief.lastModifyTime = DateTime.now().millisecondsSinceEpoch;
    await file.writeAsString(jsonEncode(toJson()));
    await GlobalStorage().ship.save();
    dev.log(
      'FitRecord.save done',
      name: 'FitRecord.save',
      time: DateTime.now(),
    );
  }

  static Future<FitRecord> read(String id) async {
    final fullRecordDir = await getFullRecordDir(create: false);
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

  final List<SlotItem?> high;
  final List<SlotItem?> med;
  final List<SlotItem?> low;
  final List<SlotItem?> rig;

  final List<SlotItem?> subsystem;

  final List<DroneItem> drone;
  final List<SlotItem?> implant;

  /// Do not use this constructor directly, use [Fit.init] instead.
  const Fit({
    required this.shipID,
    required this.high,
    required this.med,
    required this.low,
    required this.rig,
    required this.subsystem,
    required this.drone,
    required this.implant,
  });

  factory Fit.init(int shipID) {
    final ship = GlobalStorage().static.ships[shipID];
    return Fit(
      shipID: shipID,
      high: List.filled(ship?.highSlotNum ?? 0, null, growable: true),
      med: List.filled(ship?.medSlotNum ?? 0, null, growable: true),
      low: List.filled(ship?.lowSlotNum ?? 0, null, growable: true),
      rig: List.filled(ship?.rigSlotNum ?? 0, null),
      subsystem: List.filled(ship?.subsystemSlotNum ?? 0, null),
      drone: List.empty(growable: true),
      implant: List.filled(10, null),
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
  int compareTo(SlotState other) {
    return state.compareTo(other.state);
  }

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

  DroneState nextState() {
    return state == 0 ? DroneState.active : DroneState.passive;
  }
}
