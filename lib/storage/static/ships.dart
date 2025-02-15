import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/ships.pb.dart';
import 'package:eve_fit_assistant/utils/map.dart';

class Ship {
  final Ships_Ship _raw;

  String get nameEN => _raw.name.en;

  String get nameZH => _raw.name.zh;

  int get groupID => _raw.groupID;

  bool get published => _raw.published;

  int get highSlotNum => _raw.highSlotNum;

  int get medSlotNum => _raw.medSlotNum;

  int get lowSlotNum => _raw.lowSlotNum;

  int get rigSlotNum => _raw.rigSlotNum;

  bool get hasSubsystem => _raw.hasSubsystem;

  int get turretSlotNum => _raw.turretSlotNum;

  int get launcherSlotNum => _raw.launcherSlotNum;

  int get droneBandwidth => _raw.droneBandwidth;

  bool get hasTacticalMode => _raw.hasTacticalMode;

  const Ship._private(this._raw);

  static Map<int, Ship> _fromBuffer(Uint8List buffer) {
    final ships = Ships.fromBuffer(buffer);
    return ships.entries.map((key, value) => MapEntry(key, Ship._private(value)));
  }

  static Future<ReadonlyMap<int, Ship>> read(Directory staticDir) async {
    final file = File('${staticDir.path}/ships.pb');
    final buffer = await file.readAsBytes();
    return ReadonlyMap(_fromBuffer(buffer));
  }
}
