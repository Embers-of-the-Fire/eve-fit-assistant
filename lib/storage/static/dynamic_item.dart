import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/dynamic_item.pb.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

class DynamicItem {
  final DynamicItems_DynamicItem _raw;

  DynamicItems_DynamicItem get data => _raw;

  const DynamicItem._private(this._raw);

  static Map<int, DynamicItem> _fromBuffer(Uint8List buffer) {
    final items = DynamicItems.fromBuffer(buffer);
    return items.entries.map((key, value) => MapEntry(key, DynamicItem._private(value)));
  }

  static Future<ReadonlyMap<int, DynamicItem>> read(Directory staticDir) async {
    final file = File('${staticDir.path}/dynamic_item.pb');
    final buffer = await file.readAsBytes();
    return _fromBuffer(buffer).readonly;
  }
}
