import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/proto/skills.pb.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

class TypeSkillItem {
  final TypeSkills_Skill _raw;

  int get id => _raw.id;

  int get level => _raw.level;

  const TypeSkillItem._private(this._raw);
}

class TypeSkill {
  final List<TypeSkillItem> skills;

  const TypeSkill._private(this.skills);

  factory TypeSkill._fromRaw(TypeSkills_TypeSkill raw) {
    final skills = raw.skills.map((skill) => TypeSkillItem._private(skill)).toList();
    return TypeSkill._private(skills);
  }

  static Map<int, TypeSkill> _fromBuffer(Uint8List buffer) {
    final typeSkills = TypeSkills.fromBuffer(buffer);
    return typeSkills.entries.map((key, value) => MapEntry(key, TypeSkill._fromRaw(value)));
  }

  static Future<ReadonlyMap<int, TypeSkill>> read(Directory staticDir) async {
    final file = File('${staticDir.path}/type_skills.pb');
    final buffer = await file.readAsBytes();
    return ReadonlyMap(_fromBuffer(buffer));
  }
}
