import "dart:async";
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

  factory CharacterMetadata.fromCharacter(CharacterStorage character) => CharacterMetadata(
    characterId: character.characterId,
    name: character.name,
    description: character.description,
    lastModified: character.lastModified,
    bundleId: character.bundleId,
  );

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

/// Character storage is always under global control,
/// so profile persistence stays behind this manager.
@riverpodSingleton
class CharacterRegistryManager extends _$CharacterRegistryManager {
  static String get _characterRegistryPath => p.join(PathProvider.charactersPath, "registry.json");

  static const builtInCharacterIds = <String>[predefinedMaxCharacterId, predefinedZeroCharacterId];
  static const _registrySyncDebounce = Duration(milliseconds: 300);
  static const _idGenerator = Uuid();

  Timer? _registrySyncTimer;
  Future<void> _pendingRegistrySync = Future<void>.value();

  static bool isBuiltInCharacterId(String characterId) => builtInCharacterIds.contains(characterId);

  static String generateCharacterId() => _idGenerator.v4();

  static int _normalizeSkillLevel(int level) {
    if (level < 0) return 0;
    if (level > 5) return 5;
    return level;
  }

  @override
  CharacterRegistry build() {
    ref.onDispose(() {
      _registrySyncTimer?.cancel();
      unawaited(_queueRegistrySync());
    });
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

  void updateCharacter(CharacterMetadata metadata) {
    debug("Update character ${metadata.characterId} in ${metadata.bundleId}");
    state = state.copyWith(characters: state.characters.add(metadata.characterId, metadata));
    _scheduleRegistrySync();
  }

  CharacterStorage? tryLoadCharacterSync(String characterId) {
    final path = File(CharacterStorage.characterStoragePathForId(characterId));
    if (!path.existsSync()) {
      return null;
    }

    final text = path.readAsStringSync();
    final json = jsonDecode(text) as Map<String, dynamic>;
    return CharacterStorage.fromJson(json);
  }

  Future<CharacterStorage?> tryLoadCharacter(String characterId) async {
    final path = File(CharacterStorage.characterStoragePathForId(characterId));
    if (!path.existsSync()) {
      return null;
    }

    final text = await path.readAsString();
    final json = jsonDecode(text) as Map<String, dynamic>;
    return CharacterStorage.fromJson(json);
  }

  CharacterStorage loadCharacterSync(String characterId) {
    final character = tryLoadCharacterSync(characterId);
    if (character == null) {
      throw StateError("Character file does not exist: $characterId");
    }
    return character;
  }

  Future<CharacterStorage> loadCharacter(String characterId) async {
    final character = await tryLoadCharacter(characterId);
    if (character == null) {
      throw StateError("Character file does not exist: $characterId");
    }
    return character;
  }

  Map<int, int> resolveCharacterSkillsSync(
    String characterId,
    Iterable<int> availableSkillTypeIds,
  ) {
    final skillTypeIds = availableSkillTypeIds.toList(growable: false);
    final skills = switch (characterId) {
      predefinedMaxCharacterId => Map<int, int>.fromEntries(
        skillTypeIds.map((typeId) => MapEntry(typeId, 5)),
      ),
      predefinedZeroCharacterId => Map<int, int>.fromEntries(
        skillTypeIds.map((typeId) => MapEntry(typeId, 0)),
      ),
      _ => tryLoadCharacterSync(characterId)?.skills ?? const <int, int>{},
    };

    if (skillTypeIds.isEmpty) {
      return skills.map((typeId, level) => MapEntry(typeId, _normalizeSkillLevel(level)));
    }

    return Map<int, int>.fromEntries(
      skillTypeIds.map((typeId) => MapEntry(typeId, _normalizeSkillLevel(skills[typeId] ?? 0))),
    );
  }

  Future<CharacterStorage> createCharacter({
    required String name,
    String description = "",
    String baseCharacterId = predefinedMaxCharacterId,
  }) async {
    final baseCharacter = await loadCharacter(baseCharacterId);
    return _createCharacterFromSkills(
      name: name,
      description: description,
      skills: baseCharacter.skills,
    );
  }

  Future<CharacterStorage> cloneCharacter(String characterId, {String? name}) async {
    final baseCharacter = await loadCharacter(characterId);
    return _createCharacterFromSkills(
      name: name ?? "${baseCharacter.name} Copy",
      description: baseCharacter.description,
      skills: baseCharacter.skills,
    );
  }

  Future<CharacterStorage> saveCharacter(CharacterStorage character, {bool touch = true}) async {
    if (isBuiltInCharacterId(character.characterId)) {
      throw StateError("Built-in characters cannot be modified: ${character.characterId}");
    }

    final savedCharacter = character.copyWith(
      lastModified: touch ? DateTime.now().millisecondsSinceEpoch : character.lastModified,
      skills: character.skills.map(
        (typeId, level) => MapEntry(typeId, _normalizeSkillLevel(level)),
      ),
    );
    await _writeCharacter(savedCharacter);
    updateCharacter(CharacterMetadata.fromCharacter(savedCharacter));
    return savedCharacter;
  }

  Future<void> deleteCharacter(String characterId) async {
    if (isBuiltInCharacterId(characterId)) {
      throw StateError("Built-in characters cannot be deleted: $characterId");
    }

    final path = File(CharacterStorage.characterStoragePathForId(characterId));
    if (path.existsSync()) {
      await path.delete();
    }
    state = state.copyWith(characters: state.characters.remove(characterId));
    await _flushRegistrySync();
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

  void _scheduleRegistrySync() {
    _registrySyncTimer?.cancel();
    _registrySyncTimer = Timer(_registrySyncDebounce, () {
      _registrySyncTimer = null;
      unawaited(_queueRegistrySync());
    });
  }

  Future<void> _flushRegistrySync() async {
    _registrySyncTimer?.cancel();
    _registrySyncTimer = null;
    await _queueRegistrySync();
  }

  Future<void> _queueRegistrySync() {
    final registry = state;
    _pendingRegistrySync = _pendingRegistrySync
        .catchError((Object errorValue, StackTrace stackTrace) {
          warning("Previous character registry sync failed: $errorValue");
          debug(errorValue.toString(), stackTrace: stackTrace);
        })
        .then((_) => _syncRegistryToDisk(registry));
    return _pendingRegistrySync;
  }

  Future<void> _syncRegistryToDisk(CharacterRegistry registry) async {
    final registryFile = File(_characterRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile.createSync(recursive: true);
    }
    final registryJson = registry.toJson();
    final registryContent = jsonEncode(registryJson);
    await registryFile.writeAsString(registryContent);
  }

  Future<void> _writeCharacter(CharacterStorage character) async {
    final path = File(character.characterStoragePath);
    if (!path.existsSync()) {
      await path.parent.create(recursive: true);
    }
    await path.writeAsString(jsonEncode(character.toJson()));
  }

  Future<CharacterStorage> _createCharacterFromSkills({
    required String name,
    required String description,
    required Map<int, int> skills,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final bundleId = ref.read(currentBundleProvider)?.bundleId ?? "";
    final character = CharacterStorage(
      characterId: generateCharacterId(),
      name: name,
      description: description,
      lastModified: now,
      bundleId: bundleId,
      skills: skills.map((typeId, level) => MapEntry(typeId, _normalizeSkillLevel(level))),
    );
    await _writeCharacter(character);
    updateCharacter(CharacterMetadata.fromCharacter(character));
    await _flushRegistrySync();
    return character;
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
        predefinedZeroCharacterId => Map<int, int>.fromEntries(
          skillTypeIds.map((typeId) => MapEntry(typeId, 0)),
        ),
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
