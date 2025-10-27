import "dart:async";
import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:eve_fit_assistant/storage/character/schema.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "service.freezed.dart";
part "service.g.dart";

@freezed
abstract class CharacterServiceStatus with _$CharacterServiceStatus {
  const factory CharacterServiceStatus.uninitialized() = _CharacterServiceStatusStatusUninitialized;
  const factory CharacterServiceStatus.error({required String message}) =
      _CharacterServiceStatusStatusError;
  const factory CharacterServiceStatus.syncing() = _CharacterServiceStatusStatusSyncing;
  const factory CharacterServiceStatus.loaded({required DateTime lastSync}) =
      _CharacterServiceStatusStatusLoaded;
}

@freezed
abstract class CharacterServiceState with _$CharacterServiceState {
  const factory CharacterServiceState.notInitialized() = _CharacterServiceStateNotInitialized;
  const factory CharacterServiceState.loaded({
    required CharacterServiceStatus status,
    required CharacterStorage character,
  }) = _CharacterServiceStateLoaded;

  const CharacterServiceState._();

  bool get isInitialized => when(notInitialized: () => false, loaded: (status, character) => true);
  CharacterStorage get character => when(
    notInitialized: () {
      final stackTrace = StackTrace.current;
      error("Invalid character service access: character not initialized", stackTrace: stackTrace);
      throw StateError("Character service not initialized");
    },
    loaded: (status, character) => character,
  );
  CharacterServiceStatus get status => when(
    notInitialized: CharacterServiceStatus.uninitialized,
    loaded: (status, character) => status,
  );
}

@riverpodSingleton
CharacterStorage character(Ref ref) =>
    ref.watch(characterServiceProvider.select((value) => value.character));

@riverpodSingleton
CharacterServiceStatus characterStatus(Ref ref) =>
    ref.watch(characterServiceProvider.select((value) => value.status));

@riverpodSingleton
class CharacterService extends _$CharacterService {
  @override
  CharacterServiceState build() => const CharacterServiceState.notInitialized();

  Future<void> _loadFromDisk(String characterId) async {
    if (state.isInitialized) {
      warning("Character service already initialized, force loading");
    }
    state = const CharacterServiceState.notInitialized();
    final path = File(CharacterStorage.characterStoragePathForId(characterId));
    if (!path.existsSync()) {
      error("Character file does not exist: ${path.path}");
      throw StateError("Character file does not exist: ${path.path}");
    }
    final text = await path.readAsString();
    final json = jsonDecode(text) as Map<String, dynamic>;
    final character = CharacterStorage.fromJson(json);
    state = CharacterServiceState.loaded(
      status: CharacterServiceStatus.loaded(lastSync: DateTime.now()),
      character: character,
    );
  }

  Future<void> _syncToDisk({bool setState = true}) async {
    if (!state.isInitialized) {
      error("Cannot sync character service: not initialized");
      return;
    }
    final character = state.character;
    state = CharacterServiceState.loaded(
      status: const CharacterServiceStatus.syncing(),
      character: character,
    );
    final path = File(character.characterStoragePath);
    final text = jsonEncode(character.toJson());
    if (!path.existsSync()) {
      await path.parent.create(recursive: true);
    }
    await path.writeAsString(text);
    if (setState) {
      state = CharacterServiceState.loaded(
        status: CharacterServiceStatus.loaded(lastSync: DateTime.now()),
        character: state.character,
      );
    }
  }

  Future<void> mount(String characterId) async {
    await _loadFromDisk(characterId);
  }

  Future<void> unmount() async {
    await _syncToDisk();
    state = const CharacterServiceState.notInitialized();
  }

  Future<void> update(CharacterStorage Function(CharacterStorage) updater) async {
    if (!state.isInitialized) {
      error("Cannot update character service: not initialized");
      return;
    }
    final character = updater(
      state.character,
    ).copyWith(lastModified: DateTime.now().millisecondsSinceEpoch);
    state = CharacterServiceState.loaded(
      status: const CharacterServiceStatus.syncing(),
      character: character,
    );
    ref
        .read(characterRegistryManagerProvider.notifier)
        .updateFit(
          CharacterMetadata(
            characterId: character.characterId,
            name: character.name,
            description: character.description,
            lastModified: character.lastModified,
            bundleId: character.bundleId,
          ),
        );
    await _syncToDisk(setState: false);
  }
}
