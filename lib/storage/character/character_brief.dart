import 'dart:convert';
import 'dart:io';

import 'package:eve_fit_assistant/storage/character/character.dart';
import 'package:eve_fit_assistant/storage/character/storage.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/v4.dart';

part 'character_brief.g.dart';

@JsonSerializable()
class CharacterBrief {
  final String id;
  String name;
  String description;

  CharacterBrief({
    required this.id,
    required this.name,
    required this.description,
  });

  factory CharacterBrief.fromJson(Map<String, dynamic> json) => _$CharacterBriefFromJson(json);

  factory CharacterBrief.blankNow(String name) {
    final id = const UuidV4().generate();
    return CharacterBrief(
      id: id,
      name: name,
      description: '',
    );
  }

  factory CharacterBrief.fromCharacter(Character character) => CharacterBrief(
      id: character.id,
      name: character.name,
      description: character.description,
    );

  static Future<Map<String, CharacterBrief>> read() async {
    final briefRecord = await getCharacterBriefFile(create: true);
    final Map<String, CharacterBrief> records = {};
    final data = jsonDecode(await briefRecord.readAsString());
    final rec = Map<String, dynamic>.from(data);
    rec.forEach((key, value) {
      records[key] = CharacterBrief.fromJson(value);
    });
    return records;
  }

  Map<String, dynamic> toJson() => _$CharacterBriefToJson(this);
}

Future<File> getCharacterBriefFile({bool create = false}) async {
  final storageDir = await getCharacterDir(create: create);
  final record = File('${storageDir.path}/brief.json');
  if (create && !record.existsSync()) {
    await record.create();
    await record.writeAsString('{}');
  }
  return record;
}
