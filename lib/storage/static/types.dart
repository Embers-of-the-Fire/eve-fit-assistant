import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/types.pb.dart';
import 'package:eve_fit_assistant/utils/map.dart';

class TypeAbbr {
  final Types_Type _raw;

  String get nameEN => _raw.name.en;
  String get nameZH => _raw.name.zh;
  int get groupID => _raw.groupID;
  bool get published => _raw.published;

  const TypeAbbr._private(this._raw);

  static Map<int, TypeAbbr> _fromBuffer(Uint8List buffer) {
    final types = Types.fromBuffer(buffer);
    return types.entries
        .map((key, value) => MapEntry(key, TypeAbbr._private(value)));
  }

  static Future<ReadonlyMap<int, TypeAbbr>> read(Directory staticDir) async {
    final file = File('${staticDir.path}/types.pb');
    final buffer = await file.readAsBytes();
    return ReadonlyMap(_fromBuffer(buffer));
  }
}
