import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/types.pb.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

class TypeItem {
  final Types_Type _raw;

  String get nameEN => _raw.name.en;

  String get nameZH => _raw.name.zh;

  int get groupID => _raw.groupID;

  bool get published => _raw.published;

  String get description => _raw.description;

  const TypeItem._private(this._raw);

  static Map<int, TypeItem> _fromBuffer(Uint8List buffer) {
    final types = Types.fromBuffer(buffer);
    return types.entries.map((key, value) => MapEntry(key, TypeItem._private(value)));
  }

  static Future<ReadonlyMap<int, TypeItem>> read(Directory staticDir) async {
    final file = File('${staticDir.path}/types.pb');
    final buffer = await file.readAsBytes();
    return ReadonlyMap(_fromBuffer(buffer));
  }
}
