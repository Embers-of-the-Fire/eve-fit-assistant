import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/fighter.pb.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

enum FighterType {
  light,
  support,
  heavy;

  factory FighterType._fromRaw(Fighters_FighterType type) => switch (type) {
        Fighters_FighterType.LIGHT => FighterType.light,
        Fighters_FighterType.SUPPORT => FighterType.support,
        Fighters_FighterType.HEAVY => FighterType.heavy,
        _ => throw Exception('Unknown fighter type: $type')
      };

  String get text => switch (this) {
        FighterType.light => '轻型',
        FighterType.support => '后勤',
        FighterType.heavy => '重型',
      };
}

class Fighter {
  final int _ability;
  final int _amount;
  final FighterType _type;

  int get ability => _ability;

  int get amount => _amount;

  FighterType get type => _type;

  const Fighter._private(
    this._ability,
    this._amount,
    this._type,
  );

  factory Fighter._fromRaw(Fighters_Fighter proto) =>
      Fighter._private(proto.ability, proto.amount, FighterType._fromRaw(proto.type));

  static Map<int, Fighter> _fromBuffer(Uint8List buffer) {
    final fighters = Fighters.fromBuffer(buffer);
    return fighters.entries.map((key, value) => MapEntry(key, Fighter._fromRaw(value)));
  }

  static Future<ReadonlyMap<int, Fighter>> read(Directory storageDir) async {
    final file = File('${storageDir.path}/fighter.pb');
    final buffer = await file.readAsBytes();
    return _fromBuffer(buffer).readonly;
  }
}
