import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/subsystem.pb.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

enum SubsystemType {
  offensive(0),
  propulsion(1),
  core(2),
  defensive(3);

  final int value;

  const SubsystemType(this.value);

  int get groupID {
    switch (this) {
      case SubsystemType.offensive:
        return 956;
      case SubsystemType.propulsion:
        return 957;
      case SubsystemType.core:
        return 958;
      case SubsystemType.defensive:
        return 954;
    }
  }
}

class SubsystemItem {
  final ShipSubsystem_Subsystem _raw;

  String get nameEN => _raw.name.en;

  String get nameZH => _raw.name.zh;

  int get high => _raw.high;

  int get medium => _raw.medium;

  int get low => _raw.low;

  int get turret => _raw.turret;

  int get launcher => _raw.launcher;

  const SubsystemItem._private(this._raw);
}

class SubsystemShip {
  final ShipSubsystem_Ship _raw;

  List<int> get offensive => _raw.offensive;

  int get offensiveMarketID => _raw.offensiveMarket;

  List<int> get propulsion => _raw.propulsion;

  int get propulsionMarketID => _raw.propulsionMarket;

  List<int> get core => _raw.core;

  int get coreMarketID => _raw.coreMarket;

  List<int> get defensive => _raw.defensive;

  int get defensiveMarketID => _raw.defensiveMarket;

  const SubsystemShip._private(this._raw);

  List<int> operator [](SubsystemType type) {
    switch (type) {
      case SubsystemType.offensive:
        return offensive;
      case SubsystemType.propulsion:
        return propulsion;
      case SubsystemType.core:
        return core;
      case SubsystemType.defensive:
        return defensive;
    }
  }

  int getMarketID(SubsystemType type) {
    switch (type) {
      case SubsystemType.offensive:
        return offensiveMarketID;
      case SubsystemType.propulsion:
        return propulsionMarketID;
      case SubsystemType.core:
        return coreMarketID;
      case SubsystemType.defensive:
        return defensiveMarketID;
    }
  }
}

class ShipSubsystemStorage {
  final ReadonlyMap<int, SubsystemShip> _ships;
  final ReadonlyMap<int, SubsystemItem> _items;

  ReadonlyMap<int, SubsystemShip> get ships => _ships;

  ReadonlyMap<int, SubsystemItem> get items => _items;

  ShipSubsystemStorage._private(this._ships, this._items);

  factory ShipSubsystemStorage._fromBuffer(Uint8List buffer) {
    final raw = ShipSubsystem.fromBuffer(buffer);
    final ships = raw.ships.map((key, value) => MapEntry(key, SubsystemShip._private(value)));
    final subsystems =
        raw.subsystems.map((key, value) => MapEntry(key, SubsystemItem._private(value)));
    return ShipSubsystemStorage._private(
      ReadonlyMap(ships),
      ReadonlyMap(subsystems),
    );
  }

  static Future<ShipSubsystemStorage> read(Directory staticDir) async {
    final file = File('${staticDir.path}/subsystem.pb');
    final buffer = await file.readAsBytes();
    return ShipSubsystemStorage._fromBuffer(buffer);
  }
}
