import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:eve_fit_assistant/storage/character/character.dart';
import 'package:eve_fit_assistant/storage/character/character_brief.dart';
import 'package:eve_fit_assistant/storage/path.dart';
import 'package:eve_fit_assistant/storage/static/storage.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/utils/utils.dart';

class CharacterStorage {
  late final Character _predefinedAll5;
  late final Character _predefinedAll0;
  final MapView<String, CharacterBrief> _briefRecords = MapView({});
  final MapView<String, Character> _characters = MapView({});

  ReadonlyMap<String, CharacterBrief> get brief => _briefRecords.read;

  Character get predefinedAll5 => _predefinedAll5;

  Character get predefinedAll0 => _predefinedAll0;

  CharacterStorage();

  Future<void> init() async {
    final staticDir = await getStaticCharacterDir();
    final all5File = File('${staticDir.path}/max.pb');
    final all0File = File('${staticDir.path}/min.pb');
    _predefinedAll5 = await Character.readFromFile(all5File);
    _predefinedAll0 = await Character.readFromFile(all0File);

    _characters.write[_predefinedAll5.id] = _predefinedAll5;
    _characters.write[_predefinedAll0.id] = _predefinedAll0;

    await _loadBrief();
  }

  Future<void> _loadBrief() async {
    final file = await getCharacterBriefFile(create: false);
    if (!await file.exists()) {
      _briefRecords.write[_predefinedAll5.id] = CharacterBrief.fromCharacter(_predefinedAll5);
      _briefRecords.write[_predefinedAll0.id] = CharacterBrief.fromCharacter(_predefinedAll0);
      await _saveBrief();
      return;
    }

    final content = await file.readAsString();
    final records = jsonDecode(content);
    for (final entry in records.entries) {
      _briefRecords.write[entry.key] = CharacterBrief.fromJson(entry.value);
    }
  }

  Future<CharacterBrief> _createBrief(String name) async {
    final brief = CharacterBrief.blankNow(name);
    _briefRecords.write[brief.id] = brief;
    await _saveBrief();
    return brief;
  }

  Future<void> _saveBrief() async {
    final records = _briefRecords.read.toJson();
    final file = await getCharacterBriefFile(create: true);
    await file.writeAsString(jsonEncode(records));
  }

  Future<Character> create(String name, {required String baseID}) async {
    final brief = await _createBrief(name);
    final character = Character.newBlank(brief, base: await GlobalStorage().character.get(baseID));
    await character.save();
    return character;
  }

  Future<Character> read(String id) async {
    if (id == _predefinedAll0.id) return _predefinedAll0;
    if (id == _predefinedAll5.id) return _predefinedAll5;

    final character = await Character.read(id);
    return character;
  }

  Future<void> delete(String id) async {
    if (id == _predefinedAll0.id || id == _predefinedAll5.id) return;

    await Character.delete(id);
    _briefRecords.write.remove(id);
    await _saveBrief();
  }

  Future<Character> get(String id) async {
    if (!_characters.read.containsKey(id)) {
      _characters.write[id] = await read(id);
    }
    return _characters.read[id]!;
  }

  Future<void> updateBrief(String id, Character character) async {
    final brief = _briefRecords.read[id]!;
    brief.name = character.name;
    brief.description = character.description;
    brief.lastModifyTime = DateTime.now().millisecondsSinceEpoch;
    await _saveBrief();
  }
}

Future<Directory> getStaticCharacterDir({bool create = false}) async {
  final staticDir = await getStaticStorageDir(create: create);
  final staticPersonDir = Directory('${staticDir.path}/character');
  if (create && !await staticPersonDir.exists()) {
    await staticPersonDir.create();
  }
  return staticPersonDir;
}

Future<Directory> getCharacterDir({bool create = false}) async {
  final storageDir = await getStorageDir(create: create);
  final characterDir = Directory('${storageDir.path}/character');
  if (create && !await characterDir.exists()) {
    await characterDir.create();
  }
  return characterDir;
}
