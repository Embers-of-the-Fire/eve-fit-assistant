import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/native/codegen/constant/unit.dart';
import 'package:eve_fit_assistant/storage/proto/attribute.pb.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

class AttributeItem {
  final Attributes_Attribute _raw;

  String get name => _raw.name;

  double get defaultValue => _raw.defaultValue;

  int? get categoryID => _raw.categoryID.optional;

  String get description => _raw.description;

  String get displayNameEN => _raw.displayName.en;

  String get displayNameZH => _raw.displayName.zh;

  bool get highIsGood => _raw.highIsGood;

  int? get iconID => _raw.iconID.optional;

  bool get published => _raw.published;

  UnitType? get unitID => _raw.unitID.optional.andThen(UnitType.fromID);

  const AttributeItem._private(this._raw);

  static Map<int, AttributeItem> _fromBuffer(Uint8List buffer) {
    final raw = Attributes.fromBuffer(buffer);
    final attributes = raw.entries.map((k, v) => MapEntry(k, AttributeItem._private(v)));
    return attributes;
  }

  static Future<ReadonlyMap<int, AttributeItem>> read(Directory staticDir) async {
    final file = File('${staticDir.path}/attribute.pb');
    final buffer = await file.readAsBytes();
    return _fromBuffer(buffer).readonly;
  }
}
