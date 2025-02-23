import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/skills.pb.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

class SkillItem {
  final Skills_Skill _raw;

  String get nameEN => _raw.name.en;

  String get nameZH => _raw.name.zh;

  int get groupID => _raw.groupID;

  bool get published => _raw.published;

  int get alphaMaxLevel => _raw.alphaMaxLevel;

  const SkillItem._private(this._raw);

  static Map<int, SkillItem> _fromBuffer(Uint8List buffer) {
    final skills = Skills.fromBuffer(buffer);
    return skills.entries.map((key, value) => MapEntry(key, SkillItem._private(value)));
  }

  static Future<ReadonlyMap<int, SkillItem>> read(Directory staticDir) async {
    final file = File('${staticDir.path}/skills.pb');
    final buffer = await file.readAsBytes();
    return _fromBuffer(buffer).readonly;
  }
}
