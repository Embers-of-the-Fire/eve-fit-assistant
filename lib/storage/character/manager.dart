import "dart:async";
import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/bundle/skill_profiles.dart";
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
    @JsonKey(readValue: readCharacterBundleSnapshot)
    required CharacterBundleSnapshot bundleSnapshot,
  }) = _CharacterMetadata;

  factory CharacterMetadata.fromCharacter(CharacterStorage character) => CharacterMetadata(
    characterId: character.characterId,
    name: character.name,
    description: character.description,
    lastModified: character.lastModified,
    bundleId: character.bundleId,
    bundleSnapshot: character.bundleSnapshot,
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

  static const builtInCharacterIds = <String>[
    predefinedMaxCharacterId,
    predefinedAlphaMaxCharacterId,
    predefinedZeroCharacterId,
  ];
  static const _registrySyncDebounce = Duration(milliseconds: 300);
  static const _idGenerator = Uuid();

  Timer? _registrySyncTimer;
  Future<void> _pendingRegistrySync = Future<void>.value();
  CharacterRegistry? _registrySyncSnapshot;
  final Set<String> _reportedBundleWarnings = <String>{};

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
      final registry = _registrySyncSnapshot;
      if (registry != null) {
        unawaited(_queueRegistrySync(registry));
      }
    });
    final registryFile = File(_characterRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile
        ..createSync(recursive: true)
        ..writeAsStringSync("{}");
    }

    final registryContent = registryFile.readAsStringSync();
    final registryJson = jsonDecode(registryContent) as Map<String, dynamic>;
    final registry = CharacterRegistry.fromJson(registryJson);
    final normalizedRegistry = _ensureBuiltInCharacters(
      registry,
      activeBundle: ref.read(currentBundleProvider),
    );
    _registrySyncSnapshot = normalizedRegistry;
    return normalizedRegistry;
  }

  void updateCharacter(CharacterMetadata metadata) {
    debug("Update character ${metadata.characterId} in ${metadata.bundleId}");
    _setRegistry(state.copyWith(characters: state.characters.add(metadata.characterId, metadata)));
    _scheduleRegistrySync();
  }

  void refreshBuiltInCharacters(BundleMetadata? activeBundle) {
    _setRegistry(_ensureBuiltInCharacters(state, activeBundle: activeBundle));
    _scheduleRegistrySync();
  }

  Future<CharacterStorage?> tryLoadCharacter(String characterId) async {
    if (isBuiltInCharacterId(characterId)) {
      return _loadBuiltInCharacter(characterId);
    }

    final path = File(CharacterStorage.characterStoragePathForId(characterId));
    final String text;
    try {
      text = await path.readAsString();
    } on FileSystemException catch (exception) {
      if (exception.osError?.errorCode == 2) {
        return null;
      }
      rethrow;
    }
    final json = jsonDecode(text) as Map<String, dynamic>;
    final character = CharacterStorage.fromJson(json);
    _warnIfBundleNeedsAttention(character, context: "loading character");
    return character;
  }

  Future<CharacterStorage> loadCharacter(String characterId) async {
    final character = await tryLoadCharacter(characterId);
    if (character == null) {
      throw StateError("Character file does not exist: $characterId");
    }
    return character;
  }

  Future<Map<int, int>> resolveCharacterSkills(
    String characterId,
    Iterable<int> availableSkillTypeIds,
  ) async {
    final skillTypeIds = availableSkillTypeIds.toList(growable: false);
    final profileId = _skillProfileIdForCharacter(characterId);
    final Map<int, int> skills;
    if (profileId == null) {
      final character = await tryLoadCharacter(characterId);
      if (character == null) {
        skills = const <int, int>{};
      } else {
        _warnIfBundleNeedsAttention(character, context: "resolving character skills");
        skills = character.skills;
      }
    } else {
      skills = _resolveBundleSkillProfile(
        ref.read(bundleCollectionProvider),
        profileId,
        skillTypeIds,
      );
    }

    if (skillTypeIds.isEmpty) {
      return skills.map((typeId, level) => MapEntry(typeId, _normalizeSkillLevel(level)));
    }

    return Map<int, int>.fromEntries(
      skillTypeIds.map((typeId) => MapEntry(typeId, _normalizeSkillLevel(skills[typeId] ?? 0))),
    );
  }

  static String? _skillProfileIdForCharacter(String characterId) => switch (characterId) {
    predefinedMaxCharacterId => predefinedMaxSkillProfileId,
    predefinedAlphaMaxCharacterId => predefinedAlphaMaxSkillProfileId,
    predefinedZeroCharacterId => predefinedZeroSkillProfileId,
    _ => null,
  };

  static Map<int, int> _resolveBundleSkillProfile(
    BundleCollectionProxy? collection,
    String profileId,
    Iterable<int> skillTypeIds,
  ) {
    final profileSkills = collection?.getSkillProfile(profileId) ?? const <int, int>{};
    return <int, int>{for (final typeId in skillTypeIds) typeId: profileSkills[typeId] ?? 0};
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

    _warnIfBundleNeedsAttention(character, context: "saving character");
    final activeBundle = ref.read(currentBundleProvider);
    final savedCharacter = character.copyWith(
      lastModified: touch ? DateTime.now().millisecondsSinceEpoch : character.lastModified,
      bundleId: activeBundle?.bundleId ?? character.bundleId,
      bundleSnapshot: activeBundle == null
          ? character.bundleSnapshot
          : CharacterBundleSnapshot.fromBundleMetadata(activeBundle),
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
    _setRegistry(state.copyWith(characters: state.characters.remove(characterId)));
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
    _setRegistry(_ensureBuiltInCharacters(registry, activeBundle: ref.read(currentBundleProvider)));
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

  Future<void> _queueRegistrySync([CharacterRegistry? snapshot]) {
    final registry = snapshot ?? state;
    _registrySyncSnapshot = registry;
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
    final registryJson = _registryForDisk(registry).toJson();
    final registryContent = jsonEncode(registryJson);
    await registryFile.writeAsString(registryContent);
  }

  void _setRegistry(CharacterRegistry registry) {
    state = registry;
    _registrySyncSnapshot = registry;
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
    final activeBundle = ref.read(currentBundleProvider);
    final bundleSnapshot = _bundleSnapshotFor(activeBundle);
    final character = CharacterStorage(
      characterId: generateCharacterId(),
      name: name,
      description: description,
      lastModified: now,
      bundleId: bundleSnapshot.bundleId,
      bundleSnapshot: bundleSnapshot,
      skills: skills.map((typeId, level) => MapEntry(typeId, _normalizeSkillLevel(level))),
    );
    await _writeCharacter(character);
    updateCharacter(CharacterMetadata.fromCharacter(character));
    await _flushRegistrySync();
    return character;
  }

  CharacterRegistry _ensureBuiltInCharacters(
    CharacterRegistry registry, {
    required BundleMetadata? activeBundle,
  }) {
    var nextRegistry = registry;

    for (final metadata in _builtInMetadata(activeBundle)) {
      nextRegistry = nextRegistry.copyWith(
        characters: nextRegistry.characters.add(metadata.characterId, metadata),
      );
    }

    return nextRegistry;
  }

  CharacterStorage? _loadBuiltInCharacter(String characterId) {
    final metadata = _builtInMetadata(
      ref.read(currentBundleProvider),
    ).where((metadata) => metadata.characterId == characterId).firstOrNull;
    if (metadata == null) {
      return null;
    }

    final profileId = _skillProfileIdForCharacter(characterId);
    final skills = profileId == null
        ? const <int, int>{}
        : _resolveBundleSkillProfile(
            ref.read(bundleCollectionProvider),
            profileId,
            ref.read(bundleCollectionSkillTypeIdsProvider),
          );

    return CharacterStorage(
      characterId: metadata.characterId,
      name: metadata.name,
      description: metadata.description,
      lastModified: metadata.lastModified,
      bundleId: metadata.bundleId,
      bundleSnapshot: metadata.bundleSnapshot,
      skills: skills,
    );
  }

  static Iterable<CharacterMetadata> _builtInMetadata(BundleMetadata? activeBundle) {
    final bundleSnapshot = _bundleSnapshotFor(activeBundle);
    return [
      CharacterMetadata(
        characterId: predefinedMaxCharacterId,
        name: "All V",
        description: "Built-in max skill profile",
        lastModified: 0,
        bundleId: bundleSnapshot.bundleId,
        bundleSnapshot: bundleSnapshot,
      ),
      CharacterMetadata(
        characterId: predefinedAlphaMaxCharacterId,
        name: "Alpha Max",
        description: "Built-in Alpha clone max skill profile",
        lastModified: 0,
        bundleId: bundleSnapshot.bundleId,
        bundleSnapshot: bundleSnapshot,
      ),
      CharacterMetadata(
        characterId: predefinedZeroCharacterId,
        name: "All 0",
        description: "Built-in zero skill profile",
        lastModified: 0,
        bundleId: bundleSnapshot.bundleId,
        bundleSnapshot: bundleSnapshot,
      ),
    ];
  }

  static CharacterBundleSnapshot _bundleSnapshotFor(BundleMetadata? activeBundle) =>
      activeBundle == null
      ? const CharacterBundleSnapshot(bundleId: "")
      : CharacterBundleSnapshot.fromBundleMetadata(activeBundle);

  static CharacterRegistry _registryForDisk(CharacterRegistry registry) => registry.copyWith(
    characters: registry.characters.removeWhere(
      (characterId, _) => isBuiltInCharacterId(characterId),
    ),
  );

  void _warnIfBundleNeedsAttention(CharacterStorage character, {required String context}) {
    final compatibility = _evaluateCharacterBundleCompatibility(
      character.bundleSnapshot,
      ref.read(currentBundleProvider),
    );
    if (compatibility.kind == _CharacterBundleCompatibilityKind.compatible) {
      return;
    }

    final activeBundleId = compatibility.activeSnapshot?.bundleId ?? "<none>";
    final warningKey = [
      character.characterId,
      character.bundleSnapshot.bundleId,
      activeBundleId,
      compatibility.kind.name,
      compatibility.reason.name,
    ].join(":");
    if (!_reportedBundleWarnings.add(warningKey)) {
      return;
    }

    warning(
      "Character ${character.characterId} was saved against bundle "
      "${character.bundleSnapshot.bundleId}, but active bundle is $activeBundleId "
      "(${compatibility.reason.name}) while $context.",
    );
  }
}

enum _CharacterBundleCompatibilityKind { compatible, outdated, incompatible, unavailable }

enum _CharacterBundleCompatibilityReason {
  none,
  activeBundleUnavailable,
  bundleIdMismatch,
  missingComparableRevision,
  manifestMismatch,
  generationMismatch,
  buildMismatch,
  appVersionMismatch,
}

({
  _CharacterBundleCompatibilityKind kind,
  _CharacterBundleCompatibilityReason reason,
  CharacterBundleSnapshot? activeSnapshot,
})
_evaluateCharacterBundleCompatibility(
  CharacterBundleSnapshot savedSnapshot,
  BundleMetadata? activeBundle,
) {
  if (activeBundle == null) {
    return (
      kind: _CharacterBundleCompatibilityKind.unavailable,
      reason: _CharacterBundleCompatibilityReason.activeBundleUnavailable,
      activeSnapshot: null,
    );
  }

  final activeSnapshot = CharacterBundleSnapshot.fromBundleMetadata(activeBundle);
  final result = _evaluateCharacterSnapshotPair(savedSnapshot, activeSnapshot);
  return (kind: result.kind, reason: result.reason, activeSnapshot: activeSnapshot);
}

({_CharacterBundleCompatibilityKind kind, _CharacterBundleCompatibilityReason reason})
_evaluateCharacterSnapshotPair(
  CharacterBundleSnapshot savedSnapshot,
  CharacterBundleSnapshot activeSnapshot,
) {
  if (savedSnapshot.bundleId != activeSnapshot.bundleId) {
    return (
      kind: _CharacterBundleCompatibilityKind.incompatible,
      reason: _CharacterBundleCompatibilityReason.bundleIdMismatch,
    );
  }

  if (!savedSnapshot.hasComparableRevision || !activeSnapshot.hasComparableRevision) {
    return (
      kind: _CharacterBundleCompatibilityKind.outdated,
      reason: _CharacterBundleCompatibilityReason.missingComparableRevision,
    );
  }

  if (savedSnapshot.manifestHash case final savedManifestHash?) {
    final activeManifestHash = activeSnapshot.manifestHash;
    if (activeManifestHash != null && savedManifestHash != activeManifestHash) {
      return (
        kind: _CharacterBundleCompatibilityKind.outdated,
        reason: _CharacterBundleCompatibilityReason.manifestMismatch,
      );
    }
  }

  if (savedSnapshot.generateTimestamp case final savedGenerateTimestamp?) {
    final activeGenerateTimestamp = activeSnapshot.generateTimestamp;
    if (activeGenerateTimestamp != null && savedGenerateTimestamp != activeGenerateTimestamp) {
      return (
        kind: _CharacterBundleCompatibilityKind.outdated,
        reason: _CharacterBundleCompatibilityReason.generationMismatch,
      );
    }
  }

  if (savedSnapshot.gameBuild case final savedGameBuild?) {
    final activeGameBuild = activeSnapshot.gameBuild;
    if (activeGameBuild != null && savedGameBuild != activeGameBuild) {
      return (
        kind: _CharacterBundleCompatibilityKind.outdated,
        reason: _CharacterBundleCompatibilityReason.buildMismatch,
      );
    }
  }

  if (savedSnapshot.appVersion case final savedAppVersion?) {
    final activeAppVersion = activeSnapshot.appVersion;
    if (activeAppVersion != null && savedAppVersion != activeAppVersion) {
      return (
        kind: _CharacterBundleCompatibilityKind.outdated,
        reason: _CharacterBundleCompatibilityReason.appVersionMismatch,
      );
    }
  }

  return (
    kind: _CharacterBundleCompatibilityKind.compatible,
    reason: _CharacterBundleCompatibilityReason.none,
  );
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
