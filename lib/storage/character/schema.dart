import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:path/path.dart" as p;

part "schema.freezed.dart";
part "schema.g.dart";

const predefinedMaxCharacterId = "predefined_all_5";
const predefinedZeroCharacterId = "predefined_all_0";

CharacterStorage? loadCharacterStorageSync(String characterId) {
  final path = File(CharacterStorage.characterStoragePathForId(characterId));
  if (!path.existsSync()) {
    return null;
  }

  final text = path.readAsStringSync();
  final json = jsonDecode(text) as Map<String, dynamic>;
  return CharacterStorage.fromJson(json);
}

Map<int, int> resolveCharacterSkillsSync(String characterId, Iterable<int> availableSkillTypeIds) {
  switch (characterId) {
    case predefinedZeroCharacterId:
      return const <int, int>{};
    case predefinedMaxCharacterId:
      return Map<int, int>.fromEntries(availableSkillTypeIds.map((typeId) => MapEntry(typeId, 5)));
  }

  return loadCharacterStorageSync(characterId)?.skills ?? const <int, int>{};
}

@freezed
abstract class CharacterStorage with _$CharacterStorage {
  const factory CharacterStorage({
    required String characterId,
    required String name,
    required String description,

    /// DateTime.millisecondsSinceEpoch
    required int lastModified,

    required String bundleId,
    required Map<int, int> skills,
  }) = _CharacterStorage;

  const CharacterStorage._();

  factory CharacterStorage.empty(CharacterMetadata metadata) => CharacterStorage(
    characterId: metadata.characterId,
    name: metadata.name,
    description: metadata.description,
    lastModified: metadata.lastModified,
    bundleId: metadata.bundleId,
    skills: {},
  );
  factory CharacterStorage.copyFrom(CharacterMetadata metadata, CharacterStorage other) =>
      CharacterStorage(
        characterId: metadata.characterId,
        name: metadata.name,
        description: metadata.description,
        lastModified: metadata.lastModified,
        bundleId: metadata.bundleId,
        skills: other.skills,
      );

  factory CharacterStorage.fromJson(Map<String, dynamic> json) => _$CharacterStorageFromJson(json);

  String get characterStoragePath => p.join(PathProvider.charactersPath, "$characterId.json");

  static String characterStoragePathForId(String characterId) =>
      p.join(PathProvider.charactersPath, "$characterId.json");
}
