import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/unit.pb.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

class UnitItem {
  final Units_Unit _raw;

  int get id => _raw.id;

  String get name => _raw.name;

  String get displayName => _raw.displayName;

  String get description => _raw.description;

  const UnitItem._private(this._raw);

  static Map<int, UnitItem> _fromBuffer(Uint8List buffer) {
    final raw = Units.fromBuffer(buffer);
    return raw.entries.map((k, v) => MapEntry(k, UnitItem._private(v)));
  }

  static Future<ReadonlyMap<int, UnitItem>> read(Directory staticDir) async {
    final file = File('${staticDir.path}/units.pb');
    final buffer = await file.readAsBytes();
    return ReadonlyMap(UnitItem._fromBuffer(buffer));
  }
}
