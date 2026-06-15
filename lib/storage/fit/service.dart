import "dart:async";
import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/native/api/server.dart" as native_server;
import "package:eve_fit_assistant/storage/character/manager.dart";
import "package:eve_fit_assistant/storage/fit/compatibility.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:fpdart/fpdart.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:riverpod/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "service.freezed.dart";
part "service.g.dart";

enum FitErrorMessageKey {
  fitLoadFailed,
  fitLoadMissing,
  fitSaveFailed,
  fitReadOnly,
  fitUnavailable,
  fitStatsUnavailable,
  fitCalculationsUnavailable,
}

String localizeFitErrorMessage(AppLocalizations l10n, FitErrorMessageKey key) => switch (key) {
  FitErrorMessageKey.fitLoadFailed => l10n.fitPageBrokenMessage,
  FitErrorMessageKey.fitLoadMissing => l10n.fitPageMissingMessage,
  FitErrorMessageKey.fitSaveFailed => l10n.fitPageSaveErrorMessage,
  FitErrorMessageKey.fitReadOnly => l10n.fitPageReadOnlyMessage,
  FitErrorMessageKey.fitUnavailable => l10n.fitPageBrokenMessage,
  FitErrorMessageKey.fitStatsUnavailable => l10n.fitPageStatsUnavailableMessage,
  FitErrorMessageKey.fitCalculationsUnavailable => l10n.fitPageStatsUnavailableMessage,
};

@freezed
abstract class FitServiceStatus with _$FitServiceStatus {
  const factory FitServiceStatus.uninitialized() = _FitServiceStatusUninitialized;
  const factory FitServiceStatus.error({required FitErrorMessageKey messageKey}) =
      _FitServiceStatusError;
  const factory FitServiceStatus.syncing() = _FitServiceStatusSyncing;
  const factory FitServiceStatus.loaded({required DateTime lastSync}) = _FitServiceStatusLoaded;
}

@freezed
abstract class FitServiceState with _$FitServiceState {
  const factory FitServiceState.notInitialized() = _FitServiceStateNotInitialized;
  const factory FitServiceState.error({required FitErrorMessageKey messageKey}) =
      _FitServiceStateError;
  const factory FitServiceState.loaded({
    required FitServiceStatus status,
    required FitStorage fit,
  }) = _FitServiceStateLoaded;

  const FitServiceState._();
  bool get isInitialized => when(
    notInitialized: () => false,
    error: (messageKey) => false,
    loaded: (status, fit) => true,
  );
  bool get hasError => when(
    notInitialized: () => false,
    error: (messageKey) => true,
    loaded: (status, fit) => false,
  );
  FitErrorMessageKey? get errorMessageKey => when(
    notInitialized: () => null,
    error: (messageKey) => messageKey,
    loaded: (status, fit) => null,
  );
  FitStorage get fit => when(
    notInitialized: () {
      final stackTrace = StackTrace.current;
      error("Invalid fit service access: fit not initialized", stackTrace: stackTrace);
      throw StateError("Fit is unavailable.");
    },
    error: (messageKey) {
      final stackTrace = StackTrace.current;
      error("Invalid fit service access: ${messageKey.name}", stackTrace: stackTrace);
      throw StateError("Fit is unavailable.");
    },
    loaded: (status, fit) => fit,
  );
  FitServiceStatus get status => when(
    notInitialized: FitServiceStatus.uninitialized,
    error: (messageKey) => FitServiceStatus.error(messageKey: messageKey),
    loaded: (status, fit) => status,
  );
}

@riverpod
class Fit extends _$Fit {
  late String _fitId;
  FitStorage? _mountedFit;
  Future<void> _pendingSync = Future<void>.value();
  int _latestSyncRevision = 0;

  @override
  FitServiceState build(String fitId) {
    _fitId = fitId;
    ref.onDispose(_unmount);
    unawaited(Future(() => _mount(fitId)));
    return const FitServiceState.notInitialized();
  }

  Future<void> reload() => _mount(_fitId);

  void _setLoadError(
    String fitId,
    FitErrorMessageKey messageKey,
    Object errorValue,
    StackTrace stackTrace,
  ) {
    error("Failed to load fit $fitId: $errorValue", stackTrace: stackTrace);
    state = FitServiceState.error(messageKey: messageKey);
  }

  Future<void> _loadFromDisk(String fitId) async {
    if (state.isInitialized) {
      warning("Fit service already initialized, force loading");
    }
    state = const FitServiceState.notInitialized();
    _mountedFit = null;
    final path = File(FitStorage.fitStoragePathForId(fitId));
    try {
      if (!path.existsSync()) {
        throw StateError("Fit file does not exist: ${path.path}");
      }
      final text = await path.readAsString();
      final json = jsonDecode(text) as Map<String, dynamic>;
      final decodedFit = decodeFitStorage(json);
      final fit = pruneDynamicRegistry(decodedFit.fit);
      if (decodedFit.didMigrate) {
        try {
          await path.writeAsString(jsonEncode(encodeFitStorage(fit)));
        } on Object catch (errorValue, stackTrace) {
          warning("Failed to rewrite migrated fit $fitId: $errorValue");
          debug(errorValue.toString(), stackTrace: stackTrace);
        }
      }
      _mountedFit = fit;
      state = FitServiceState.loaded(
        status: FitServiceStatus.loaded(lastSync: DateTime.now()),
        fit: fit,
      );
    } on Object catch (errorValue, stackTrace) {
      final messageKey = path.existsSync()
          ? FitErrorMessageKey.fitLoadFailed
          : FitErrorMessageKey.fitLoadMissing;
      _setLoadError(fitId, messageKey, errorValue, stackTrace);
    }
  }

  Future<void> _syncToDisk(FitStorage fit, int revision) async {
    _mountedFit = fit;
    final path = File(fit.fitStoragePath);
    final text = jsonEncode(encodeFitStorage(fit));
    try {
      if (!path.existsSync()) {
        await path.parent.create(recursive: true);
      }
      await path.writeAsString(text);
      if (revision != _latestSyncRevision) return;
      state = FitServiceState.loaded(
        status: FitServiceStatus.loaded(lastSync: DateTime.now()),
        fit: fit,
      );
    } on Object catch (errorValue, stackTrace) {
      error("Failed to sync fit ${fit.metadata.fitId}: $errorValue", stackTrace: stackTrace);
      if (revision != _latestSyncRevision) return;
      state = FitServiceState.loaded(
        status: const FitServiceStatus.error(messageKey: FitErrorMessageKey.fitSaveFailed),
        fit: fit,
      );
    }
  }

  Future<void> _queueSync(FitStorage fit) {
    final revision = ++_latestSyncRevision;
    _pendingSync = _pendingSync
        .catchError((Object _, StackTrace _) {})
        .then((_) => _syncToDisk(fit, revision));
    return _pendingSync;
  }

  Future<void> _mount(String fitId) => _loadFromDisk(fitId);

  FitCheckoutCompatibility _compatibilityFor(FitStorage fit) {
    final checkoutId = ref.read(activeCheckoutIdProvider);
    final active = ref.read(activeCheckoutProvider);
    return checkFitCompatibility(
      fit.metadata,
      activeCheckoutId: checkoutId.match(() => "", (id) => id),
      activeServerId: active.match(() => "", (a) => a.serverId),
    );
  }

  void _unmount() {
    debug("Unmounting fit service");
    final fit = _mountedFit;
    if (fit == null) {
      debug("Fit service not initialized, skipping unmount");
      return;
    }
    try {
      final path = File(fit.fitStoragePath);
      final text = jsonEncode(encodeFitStorage(fit));
      if (!path.existsSync()) {
        path.parent.createSync(recursive: true);
      }
      unawaited(path.writeAsString(text));
    } on Object catch (errorValue, stackTrace) {
      warning("Failed to persist fit ${fit.metadata.fitId} on unmount: $errorValue");
      debug(errorValue.toString(), stackTrace: stackTrace);
    }
  }

  Future<void> update(FitStorage Function(FitStorage) updater) async {
    if (!state.isInitialized) {
      error("Cannot update fit service: not initialized");
      return;
    }
    final currentFit = state.fit;
    final compatibility = _compatibilityFor(currentFit);
    if (!compatibility.allowsEditing) {
      state = FitServiceState.loaded(
        status: const FitServiceStatus.error(messageKey: FitErrorMessageKey.fitReadOnly),
        fit: currentFit,
      );
      return;
    }

    final active = ref.read(activeCheckoutProvider);
    final checkoutId = ref.read(activeCheckoutIdProvider);
    final updatedMetadata = currentFit.metadata.copyWith(
      lastModified: DateTime.now().millisecondsSinceEpoch,
      checkoutRef: active.match(
        () => currentFit.metadata.checkoutRef,
        (a) =>
            CheckoutRef(checkoutId: checkoutId.match(() => "", (id) => id), serverId: a.serverId),
      ),
    );
    final fit = pruneDynamicRegistry(updater(currentFit)).copyWith(metadata: updatedMetadata);
    _mountedFit = fit;
    state = FitServiceState.loaded(status: const FitServiceStatus.syncing(), fit: fit);
    ref.read(fitRegistryManagerProvider.notifier).updateFit(fit.metadata);
    await _queueSync(fit);
  }
}

@freezed
class FitEmulatorState with _$FitEmulatorState {
  const factory FitEmulatorState.notInitialized() = _FitEmulatorStateNotInitialized;
  const factory FitEmulatorState.emulating({required native.Ship? previous}) =
      _FitEmulatorStateEmulating;
  const factory FitEmulatorState.error({
    required FitErrorMessageKey messageKey,
    required native.Ship? previous,
  }) = _FitEmulatorStateError;
  const factory FitEmulatorState.emulated({required native.Ship output}) =
      _FitEmulatorStateEmulated;

  const FitEmulatorState._();

  FitEmulatorState get emulating => switch (this) {
    _FitEmulatorStateEmulated(:final output) => _FitEmulatorStateEmulating(previous: output),
    _FitEmulatorStateEmulating(previous: final _) => this,
    _FitEmulatorStateError(:final previous) => _FitEmulatorStateEmulating(previous: previous),
    _ => const _FitEmulatorStateEmulating(previous: null),
  };

  bool get hasError => when(
    notInitialized: () => false,
    emulating: (previous) => false,
    error: (messageKey, previous) => true,
    emulated: (output) => false,
  );

  FitErrorMessageKey? get errorMessageKey => when(
    notInitialized: () => null,
    emulating: (previous) => null,
    error: (messageKey, previous) => messageKey,
    emulated: (output) => null,
  );

  native.Ship? get emulated => when(
    notInitialized: () => null,
    emulating: (previous) => previous,
    error: (messageKey, previous) => previous,
    emulated: (output) => output,
  );
}

@riverpod
native.Ship? nativeEmulatedShip(Ref ref, String fitId) =>
    ref.watch(fitEmulatorServiceProvider(fitId).select((t) => t.emulated));

@riverpod
class FitEmulatorService extends _$FitEmulatorService {
  late String _fitId;
  int _emulationGeneration = 0;

  void _invalidatePendingEmulations() {
    _emulationGeneration++;
  }

  void _scheduleEmulationForCurrentFit() {
    final fitState = ref.read(fitProvider(_fitId));
    if (!fitState.isInitialized) return;
    final emulationGeneration = ++_emulationGeneration;
    unawaited(
      Future<void>(() async {
        if (!ref.mounted || _emulationGeneration != emulationGeneration) {
          return;
        }
        await emulate(fitState.fit, emulationGeneration: emulationGeneration);
      }),
    );
  }

  @override
  FitEmulatorState build(String fitId) {
    _fitId = fitId;
    ref
      ..onDispose(_invalidatePendingEmulations)
      // Register listener for subsequent changes. Do NOT synchronously call
      // `emulate` from the listener when `fireImmediately` would trigger it
      // during `build` (that can cause `state` to be mutated before the
      // notifier is fully initialized). Instead defer actual emulation to a
      // later event-loop task.
      ..listen<FitServiceState>(fitProvider(fitId), (prev, next) {
        if (prev == next) return;
        if (!next.isInitialized) {
          _invalidatePendingEmulations();
          state = next.hasError
              ? FitEmulatorState.error(
                  messageKey: next.errorMessageKey ?? FitErrorMessageKey.fitUnavailable,
                  previous: state.emulated,
                )
              : const FitEmulatorState.notInitialized();
          return;
        }
        _scheduleEmulationForCurrentFit();
      }, fireImmediately: true)
      ..listen<NativeFitEngineState>(nativeFitEngineServiceProvider, (prev, next) {
        if (prev == next) return;
        _scheduleEmulationForCurrentFit();
      })
      ..listen(repoCollectionProvider, (prev, next) {
        if (prev == next) return;
        _scheduleEmulationForCurrentFit();
      })
      ..listen(characterRegistryManagerProvider, (prev, next) {
        if (prev == next) return;
        _scheduleEmulationForCurrentFit();
      });

    return const FitEmulatorState.notInitialized();
  }

  Future<void> retry() async {
    final fitState = ref.read(fitProvider(_fitId));
    if (!fitState.isInitialized) return;
    _invalidatePendingEmulations();
    final emulationGeneration = _emulationGeneration;
    await emulate(fitState.fit, emulationGeneration: emulationGeneration);
  }

  Future<void> emulate(FitStorage fitStorage, {int? emulationGeneration}) async {
    final activeGeneration = emulationGeneration ?? ++_emulationGeneration;
    if (!ref.mounted || _emulationGeneration != activeGeneration) {
      return;
    }

    state = state.emulating;
    debug("Started emulating ${fitStorage.metadata.fitId}");
    try {
      final engineState = ref.read(nativeFitEngineServiceProvider);
      final engine = engineState.engineOrNull;
      if (engine == null) {
        final messageKey = engineState.errorMessageKey;
        if (messageKey == null) {
          debug(
            "Deferring emulation for ${fitStorage.metadata.fitId}: fit engine is still loading",
          );
          return;
        }
        warning("Failed to emulate ${fitStorage.metadata.fitId}: ${messageKey.name}");
        state = FitEmulatorState.error(messageKey: messageKey, previous: state.emulated);
        return;
      }

      final collection = ref.read(repoCollectionProvider);
      if (collection == null) {
        debug(
          "Deferring emulation for ${fitStorage.metadata.fitId}: skill definitions are still loading",
        );
        return;
      }
      final availableSkillTypeIds = collection.getSkillTypeIds();

      final characterSkills = await ref
          .read(characterRegistryManagerProvider.notifier)
          .resolveCharacterSkills(fitStorage.body.characterId, availableSkillTypeIds);
      if (!ref.mounted || _emulationGeneration != activeGeneration) {
        return;
      }
      final nativeCompatible = convertToNative(fitStorage, characterSkills: characterSkills);
      final emulatedOutput = await engine.emulate(fit: nativeCompatible);
      if (!ref.mounted || _emulationGeneration != activeGeneration) {
        return;
      }
      state = FitEmulatorState.emulated(output: emulatedOutput);
      debug("Finished emulating ${fitStorage.metadata.fitId}");
    } on Object catch (errorValue, stackTrace) {
      if (!ref.mounted || _emulationGeneration != activeGeneration) {
        return;
      }
      error(
        "Failed to emulate fit ${fitStorage.metadata.fitId}: $errorValue",
        stackTrace: stackTrace,
      );
      state = FitEmulatorState.error(
        messageKey: FitErrorMessageKey.fitStatsUnavailable,
        previous: state.emulated,
      );
    }
  }
}

@freezed
class NativeFitEngineState with _$NativeFitEngineState {
  const factory NativeFitEngineState.notInitialized() = _NativeFitEngineStateNotInitialized;
  const factory NativeFitEngineState.initializing() = _NativeFitEngineStateInitializing;
  const factory NativeFitEngineState.error({required FitErrorMessageKey messageKey}) =
      _NativeFitEngineStateError;
  const factory NativeFitEngineState.initialized({required native_server.FitEngine engine}) =
      _NativeFitEngineStateInitialized;

  const NativeFitEngineState._();

  String get debugOnlyDisplayState => switch (this) {
    _NativeFitEngineStateInitialized(engine: final _) => "initialized",
    _NativeFitEngineStateInitializing() => "initializing",
    _NativeFitEngineStateError(:final messageKey) => "error: ${messageKey.name}",
    _NativeFitEngineStateNotInitialized() => "not initialized",
    _ => throw Exception("Unreachable"),
  };
  bool get isInitializing => this is _NativeFitEngineStateInitializing;
  FitErrorMessageKey? get errorMessageKey => switch (this) {
    _NativeFitEngineStateError(:final messageKey) => messageKey,
    _ => null,
  };
  native_server.FitEngine? get engineOrNull => switch (this) {
    _NativeFitEngineStateInitialized(:final engine) => engine,
    _ => null,
  };
}

@riverpodSingleton
class NativeFitEngineService extends _$NativeFitEngineService {
  String? _lastSnapshotHash;
  ResourceIndex? _lastResourceIndex;
  Future<void>? _pendingInit;

  void _scheduleInit(String snapshotHash, ResourceIndex resourceIndex) {
    unawaited(Future(() => _initializeFromResourceIndex(snapshotHash, resourceIndex)));
  }

  @override
  NativeFitEngineState build() {
    final resolver = ref.read(nativeDirResolverProvider);
    final assetStore = ref.read(assetStoreProvider);
    ref
      ..onDispose(() => resolver.cleanup([]))
      ..listen(activeSnapshotHashProvider, (prev, next) {
        if (prev == next || next.isNone()) return;
        final hash = next.toNullable()!;
        final ri = assetStore.readResourceIndexSync(hash);
        if (ri.isNone()) return;
        _lastSnapshotHash = hash;
        _lastResourceIndex = ri.toNullable();
        _scheduleInit(hash, ri.toNullable()!);
      }, weak: true);

    final initialHash = ref.read(activeSnapshotHashProvider);
    if (initialHash case Some(:final value)) {
      final ri = assetStore.readResourceIndexSync(value);
      if (ri.isSome()) {
        _lastSnapshotHash = value;
        _lastResourceIndex = ri.toNullable();
        _scheduleInit(value, ri.toNullable()!);
      }
    }

    return const NativeFitEngineState.notInitialized();
  }

  Future<void> retry() async {
    final hash = _lastSnapshotHash;
    final ri = _lastResourceIndex;
    if (hash == null || ri == null) {
      final initialHash = ref.read(activeSnapshotHashProvider);
      if (initialHash case Some(:final value)) {
        final freshRi = ref.read(assetStoreProvider).readResourceIndexSync(value);
        if (freshRi.isSome()) {
          _lastSnapshotHash = value;
          _lastResourceIndex = freshRi.toNullable();
          await _initializeFromResourceIndex(value, freshRi.toNullable()!);
        }
      }
      return;
    }
    await _initializeFromResourceIndex(hash, ri);
  }

  Future<void> _initializeFromResourceIndex(
    String snapshotHash,
    ResourceIndex resourceIndex,
  ) async {
    if (!ref.mounted) return;
    if (_pendingInit != null) return _pendingInit!;

    final completer = Completer<void>();
    _pendingInit = completer.future;

    state = const NativeFitEngineState.initializing();
    try {
      final nativePath = await ref
          .read(nativeDirResolverProvider)
          .prepareNativeDir(snapshotHash, resourceIndex);
      if (!ref.mounted) return;
      final engine = native_server.FitEngine(
        data: await native_server.FitEngineData.init(staticRootPath: nativePath),
      );
      if (!ref.mounted) return;
      state = NativeFitEngineState.initialized(engine: engine);
      completer.complete();
    } on Object catch (errorValue, stackTrace) {
      if (!ref.mounted) return;
      error(
        "Failed to initialize native fit engine from resource index: $errorValue",
        stackTrace: stackTrace,
      );
      state = const NativeFitEngineState.error(
        messageKey: FitErrorMessageKey.fitCalculationsUnavailable,
      );
      completer.complete();
    } finally {
      if (!completer.isCompleted) {
        completer.complete();
      }
      _pendingInit = null;
    }
  }
}
