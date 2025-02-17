import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/fit/fit.dart';
import 'package:eve_fit_assistant/storage/proto/slots.pb.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

abstract mixin class TypeSlotLike {
  String get nameEN;

  String get nameZH;

  bool get published;

  SlotState get maxState;

  List<int> get chargeGroups;

  bool get hasCharge => chargeGroups.isNotEmpty;
}

class TypeSlot with TypeSlotLike {
  final Slots_Slot _raw;

  @override
  String get nameEN => _raw.name.en;

  @override
  String get nameZH => _raw.name.zh;

  @override
  bool get published => _raw.published;

  @override
  SlotState get maxState => SlotState.fromProto(_raw.maxState);

  @override
  List<int> get chargeGroups => _raw.chargeGroups;

  const TypeSlot._private(this._raw);
}

class TypeHighSlot with TypeSlotLike {
  final Slots_HighSlot _raw;

  @override
  String get nameEN => _raw.name.en;

  @override
  String get nameZH => _raw.name.zh;

  @override
  bool get published => _raw.published;

  bool get isTurret => _raw.isTurret;

  bool get isLauncher => _raw.isLauncher;

  @override
  SlotState get maxState => SlotState.fromProto(_raw.maxState);

  @override
  List<int> get chargeGroups => _raw.chargeGroups;

  const TypeHighSlot._private(this._raw);
}

class TypeImplantSlot with TypeSlotLike {
  final Slots_ImplantSlot _raw;

  @override
  String get nameEN => _raw.name.en;

  @override
  String get nameZH => _raw.name.zh;

  @override
  bool get published => _raw.published;

  int get slot => _raw.slot;

  @override
  SlotState get maxState => SlotState.online;

  @override
  List<int> get chargeGroups => [];

  const TypeImplantSlot._private(this._raw);
}

class TypeSlotStorage {
  final ReadonlyMap<int, TypeHighSlot> _high;
  final ReadonlyMap<int, TypeSlot> _med;
  final ReadonlyMap<int, TypeSlot> _low;
  final ReadonlyMap<int, TypeSlot> _rig;
  final ReadonlyMap<int, TypeSlot> _subsystem;

  final ReadonlyMap<int, TypeImplantSlot> _implant;

  ReadonlyMap<int, TypeHighSlot> get high => _high;

  ReadonlyMap<int, TypeSlot> get med => _med;

  ReadonlyMap<int, TypeSlot> get low => _low;

  ReadonlyMap<int, TypeSlot> get rig => _rig;

  ReadonlyMap<int, TypeSlot> get subsystem => _subsystem;

  ReadonlyMap<int, TypeImplantSlot> get implant => _implant;

  ReadonlyMap<int, TypeSlotLike> operator [](FitItemType type) {
    switch (type) {
      case FitItemType.high:
        return _high;
      case FitItemType.med:
        return _med;
      case FitItemType.low:
        return _low;
      case FitItemType.rig:
        return _rig;
      case FitItemType.subsystem:
        return _subsystem;
      case FitItemType.implant:
        return _implant;
      case FitItemType.drone:
        return const ReadonlyMap({});
    }
  }

  TypeSlotStorage._private({
    required high,
    required med,
    required low,
    required rig,
    required subsystem,
    required implant,
  })  : _high = high,
        _med = med,
        _low = low,
        _rig = rig,
        _subsystem = subsystem,
        _implant = implant;

  static TypeSlotStorage _fromBuffer(Uint8List buffer) {
    final slots = Slots.fromBuffer(buffer);
    return TypeSlotStorage._private(
      high:
          ReadonlyMap(slots.high.map((key, value) => MapEntry(key, TypeHighSlot._private(value)))),
      med: ReadonlyMap(slots.med.map((key, value) => MapEntry(key, TypeSlot._private(value)))),
      low: ReadonlyMap(slots.low.map((key, value) => MapEntry(key, TypeSlot._private(value)))),
      rig: ReadonlyMap(slots.rig.map((key, value) => MapEntry(key, TypeSlot._private(value)))),
      subsystem:
          ReadonlyMap(slots.subsystem.map((key, value) => MapEntry(key, TypeSlot._private(value)))),
      implant: ReadonlyMap(
          slots.implant.map((key, value) => MapEntry(key, TypeImplantSlot._private(value)))),
    );
  }

  static Future<TypeSlotStorage> read(Directory staticDir) async {
    final file = File('${staticDir.path}/slots.pb');
    final buffer = await file.readAsBytes();
    return TypeSlotStorage._fromBuffer(buffer);
  }
}
