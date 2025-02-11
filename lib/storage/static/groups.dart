import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/groups.pb.dart';
import 'package:eve_fit_assistant/utils/map.dart';

class Group {
  final Groups_Group _raw;

  String get nameEN => _raw.name.en;

  String get nameZH => _raw.name.zh;

  List<int> get types => _raw.types;

  List<int> get relatedMarketGroups => _raw.relatedMarketGroups;

  const Group._private(this._raw);

  static Map<int, Group> _fromBuffer(Uint8List buffer) {
    final groups = Groups.fromBuffer(buffer);
    return groups.entries
        .map((key, value) => MapEntry(key, Group._private(value)));
  }

  static Future<ReadonlyMap<int, Group>> read(Directory staticDir) async {
    final file = File('${staticDir.path}/groups.pb');
    final buffer = await file.readAsBytes();
    return ReadonlyMap(_fromBuffer(buffer));
  }
}
