import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/character/schema.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:path/path.dart" as p;
import "package:riverpod_annotation/riverpod_annotation.dart";
import "package:uuid/uuid.dart";

part "manager.freezed.dart";
part "manager.g.dart";

@freezed
abstract class CharacterMetadata with _$CharacterMetadata {
  const factory CharacterMetadata({
    required String characterId,
    required String name,
    required String description,

    /// DateTime.millisecondsSinceEpoch
    required int lastModified,

    required String bundleId,
  }) = _CharacterMetadata;

  factory CharacterMetadata.fromJson(Map<String, dynamic> json) =>
      _$CharacterMetadataFromJson(json);
}

@freezed
abstract class CharacterRegistry with _$CharacterRegistry {
  const factory CharacterRegistry({
    @JsonKey(defaultValue: IMap.empty) required IMap<String, CharacterMetadata> characters,
  }) = _CharacterRegistry;

  factory CharacterRegistry.fromJson(Map<String, dynamic> json) =>
      _$CharacterRegistryFromJson(json);
}

/// Fit storage is always under global control,
/// So there's no need to maintain a global singleton outside of the Ref tree.
@riverpodSingleton
class CharacterRegistryManager extends _$CharacterRegistryManager {
  static String get _characterRegistryPath => p.join(PathProvider.charactersPath, "registry.json");

  static const builtInCharacterIds = <String>[predefinedMaxCharacterId, predefinedZeroCharacterId];

  @override
  CharacterRegistry build() {
    final bundleId = ref.watch(currentBundleProvider)?.bundleId ?? "";
    final skillTypeIds = ref.watch(bundleCollectionSkillTypeIdsProvider);
    final registryFile = File(_characterRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile
        ..createSync(recursive: true)
        ..writeAsStringSync("{}");
    }

    final registryContent = registryFile.readAsStringSync();
    final registryJson = jsonDecode(registryContent) as Map<String, dynamic>;
    final registry = CharacterRegistry.fromJson(registryJson);
    return _ensureBuiltInCharacters(registry, bundleId: bundleId, skillTypeIds: skillTypeIds);
  }

  void updateFit(CharacterMetadata metadata) {
    debug("Update character ${metadata.characterId} in ${metadata.bundleId}");
    state = state.copyWith(characters: state.characters.add(metadata.characterId, metadata));
    _syncToDisk();
  }

  // ignore: unused_element
  void _syncFromDisk() {
    final registryFile = File(_characterRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile
        ..createSync(recursive: true)
        ..writeAsStringSync("{}");
    }
    final registryContent = registryFile.readAsStringSync();
    final registryJson = jsonDecode(registryContent) as Map<String, dynamic>;
    final registry = CharacterRegistry.fromJson(registryJson);
    state = registry;
  }

  void _syncToDisk() {
    final registryFile = File(_characterRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile.createSync(recursive: true);
    }
    final registryJson = state.toJson();
    final registryContent = jsonEncode(registryJson);
    registryFile.writeAsStringSync(registryContent);
  }

  CharacterRegistry _ensureBuiltInCharacters(
    CharacterRegistry registry, {
    required String bundleId,
    required Iterable<int> skillTypeIds,
  }) {
    var nextRegistry = registry;

    for (final metadata in [
      CharacterMetadata(
        characterId: predefinedMaxCharacterId,
        name: "All V",
        description: "Built-in max skill profile",
        lastModified: 0,
        bundleId: bundleId,
      ),
      CharacterMetadata(
        characterId: predefinedZeroCharacterId,
        name: "All 0",
        description: "Built-in zero skill profile",
        lastModified: 0,
        bundleId: bundleId,
      ),
    ]) {
      final skills = switch (metadata.characterId) {
        predefinedMaxCharacterId => Map<int, int>.fromEntries(
          skillTypeIds.map((typeId) => MapEntry(typeId, 5)),
        ),
        predefinedZeroCharacterId => const <int, int>{},
        _ => const <int, int>{},
      };

      final character = CharacterStorage(
        characterId: metadata.characterId,
        name: metadata.name,
        description: metadata.description,
        lastModified: metadata.lastModified,
        bundleId: metadata.bundleId,
        skills: skills,
      );
      final path = File(character.characterStoragePath);
      if (!path.existsSync()) {
        path.parent.createSync(recursive: true);
      }
      path.writeAsStringSync(jsonEncode(character.toJson()));
      nextRegistry = nextRegistry.copyWith(
        characters: nextRegistry.characters.add(metadata.characterId, metadata),
      );
    }

    final changed = nextRegistry.characters != registry.characters;
    if (changed) {
      final registryFile = File(_characterRegistryPath);
      if (!registryFile.existsSync()) {
        registryFile.createSync(recursive: true);
      }
      registryFile.writeAsStringSync(jsonEncode(nextRegistry.toJson()));
    }

    return nextRegistry;
  }
}

@riverpodSingleton
class FitManager extends _$FitManager {
  static const _idGenerator = Uuid();

  @override
  Future<DateTime> build() async {
    ref.read(characterRegistryManagerProvider);
    return DateTime.now();
  }

  static String generateFitId() => _idGenerator.v4();
}
