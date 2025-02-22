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
  int lastModifyTime;
  String name;
  String description;

  CharacterBrief({
    required this.id,
    required this.lastModifyTime,
    required this.name,
    required this.description,
  });

  factory CharacterBrief.fromJson(Map<String, dynamic> json) => _$CharacterBriefFromJson(json);

  factory CharacterBrief.blankNow(String name) {
    final id = const UuidV4().generate();
    return CharacterBrief(
      id: id,
      lastModifyTime: DateTime.now().millisecondsSinceEpoch,
      name: name,
      description: '',
    );
  }

  factory CharacterBrief.fromCharacter(Character character) => CharacterBrief(
      id: character.id,
      // `fromCharacter` should be only called when initializing
      // pre-defined characters, so we can safely set `lastModifyTime` to 0.
      lastModifyTime: 0,
      name: character.name,
      description: character.description,
    );

  static Future<Map<String, CharacterBrief>> read() async {
    final briefRecord = await getCharacterBriefFile();
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

Future<File> getCharacterBriefFile() async {
  final storageDir = await getCharacterDir(create: true);
  final record = File('${storageDir.path}/brief.json');
  return record;
}
