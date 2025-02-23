import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/tactical_mode.pb.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

class TacticalModeItem {
  final ShipTacticalMode_TacticalMode _raw;

  String get nameEN => _raw.name.en;

  String get nameZH => _raw.name.zh;

  int get iconID => _raw.iconID;

  const TacticalModeItem._private(this._raw);
}

class TacticalModeShip {
  final ReadonlyMap<int, TacticalModeItem> _tacticalModes;

  ReadonlyMap<int, TacticalModeItem> get tacticalModes => _tacticalModes;

  const TacticalModeShip._private(this._tacticalModes);

  factory TacticalModeShip._fromRaw(ShipTacticalMode_Ship raw) {
    final tacticalModes =
        raw.tacticalModes.map((k, v) => MapEntry(k, TacticalModeItem._private(v)));
    return TacticalModeShip._private(ReadonlyMap(tacticalModes));
  }

  static Map<int, TacticalModeShip> _fromBuffer(Uint8List buffer) {
    final raw = ShipTacticalMode.fromBuffer(buffer);
    return raw.ships.map((k, v) => MapEntry(k, TacticalModeShip._fromRaw(v)));
  }

  static Future<ReadonlyMap<int, TacticalModeShip>> read(Directory staticDir) async {
    final file = File('${staticDir.path}/tactical_mode.pb');
    final buffer = await file.readAsBytes();
    return _fromBuffer(buffer).readonly;
  }
}
