import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
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
    // ignore: invalid_annotation_target
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

  @override
  CharacterRegistry build() {
    final registryFile = File(_characterRegistryPath);
    if (!registryFile.existsSync()) {
      registryFile
        ..createSync(recursive: true)
        ..writeAsStringSync("{}");
    }

    final registryContent = registryFile.readAsStringSync();
    final registryJson = jsonDecode(registryContent) as Map<String, dynamic>;
    final registry = CharacterRegistry.fromJson(registryJson);
    return registry;
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
