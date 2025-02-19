import 'dart:io';
import 'dart:typed_data';

import 'package:eve_fit_assistant/storage/character/character_brief.dart';
import 'package:eve_fit_assistant/storage/character/storage.dart';
import 'package:eve_fit_assistant/storage/proto/character.pb.dart' as proto;

class Character {
  final proto.Character _raw;

  String get id => _raw.id;

  String get name => _raw.name;

  String get description => _raw.description;

  Map<int, int> get skills => _raw.skills;

  set name(String name) => _raw.name = name;

  set description(String description) => _raw.description = description;

  void getSkill(int id) => _raw.skills[id];

  void setSkill(int id, int level) => _raw.skills[id] = level;

  const Character._private(this._raw);

  factory Character.newBlank(CharacterBrief brief, {required Character base}) {
    final raw = proto.Character(
      id: brief.id,
      name: brief.name,
      description: brief.description,
      skills: base.skills,
    );
    return Character._private(raw);
  }

  static Character _fromBuffer(Uint8List buffer) {
    final raw = proto.Character.fromBuffer(buffer);
    return Character._private(raw);
  }

  static Future<Character> readFromFile(File file) async {
    final buffer = await file.readAsBytes();
    return _fromBuffer(buffer);
  }

  static Future<Character> read(String id) async {
    final dir = await getCharacterFullDir();
    final file = File('${dir.path}/$id.pb');
    return readFromFile(file);
  }

  Future<void> save() async {
    final dir = await getCharacterFullDir();
    final file = File('${dir.path}/$id.pb');
    final buffer = _raw.writeToBuffer();
    await file.writeAsBytes(buffer);
  }

  static Future<void> delete(String id) async {
    final dir = await getCharacterFullDir();
    final file = File('${dir.path}/$id.pb');
    await file.delete();
  }
}

Future<Directory> getCharacterFullDir({bool create = false}) async {
  final storageDir = await getCharacterDir(create: create);
  final record = Directory('${storageDir.path}/full');
  if (create && !record.existsSync()) {
    await record.create();
  }
  return record;
}
