import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/market_group.pb.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

class MarketGroup {
  final MarketGroups_MarketGroup _raw;

  String get nameEN => _raw.name.en;

  String get nameZH => _raw.name.zh;

  bool get hasTypes => _raw.types.isNotEmpty;

  bool get hasParent => _raw.parentGroup != 0;

  List<int> get types => _raw.types;

  List<int> get childGroups => _raw.childGroups;

  int? get parentGroup => _raw.parentGroup.optional;

  int? get iconID => _raw.iconID.optional;

  MarketGroup._private(this._raw);

  static Map<int, MarketGroup> _fromBuffer(Uint8List buffer) {
    final types = MarketGroups.fromBuffer(buffer);
    return types.entries.map((key, value) => MapEntry(key, MarketGroup._private(value)));
  }

  static Future<ReadonlyMap<int, MarketGroup>> read(Directory staticDir) async {
    final file = File('${staticDir.path}/market_groups.pb');
    final buffer = await file.readAsBytes();
    return ReadonlyMap(_fromBuffer(buffer));
  }
}
