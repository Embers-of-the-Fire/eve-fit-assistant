import "dart:async";
import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/native/api/server.dart" as native_server;
import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/character/schema.dart";
import "package:eve_fit_assistant/storage/fit/compatibility.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:freezed_annotation/freezed_annotation.dart";
import "package:riverpod/riverpod.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "service.freezed.dart";
part "service.g.dart";

@freezed
abstract class FitServiceStatus with _$FitServiceStatus {
  const factory FitServiceStatus.uninitialized() = _FitServiceStatusUninitialized;
  const factory FitServiceStatus.error({required String message}) = _FitServiceStatusError;
  const factory FitServiceStatus.syncing() = _FitServiceStatusSyncing;
  const factory FitServiceStatus.loaded({required DateTime lastSync}) = _FitServiceStatusLoaded;
}

@freezed
abstract class FitServiceState with _$FitServiceState {
  const factory FitServiceState.notInitialized() = _FitServiceStateNotInitialized;
  const factory FitServiceState.error({required String message}) = _FitServiceStateError;
  const factory FitServiceState.loaded({
    required FitServiceStatus status,
    required FitStorage fit,
  }) = _FitServiceStateLoaded;

  const FitServiceState._();
  bool get isInitialized =>
      when(notInitialized: () => false, error: (message) => false, loaded: (status, fit) => true);
  bool get hasError =>
      when(notInitialized: () => false, error: (message) => true, loaded: (status, fit) => false);
  String? get errorMessage =>
      when(notInitialized: () => null, error: (message) => message, loaded: (status, fit) => null);
  FitStorage get fit => when(
    notInitialized: () {
      final stackTrace = StackTrace.current;
      error("Invalid fit service access: fit not initialized", stackTrace: stackTrace);
      throw StateError("Fit service not initialized");
    },
    error: (message) {
      final stackTrace = StackTrace.current;
      error("Invalid fit service access: $message", stackTrace: stackTrace);
      throw StateError(message);
    },
    loaded: (status, fit) => fit,
  );
  FitServiceStatus get status => when(
    notInitialized: FitServiceStatus.uninitialized,
    error: (message) => FitServiceStatus.error(message: message),
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

  void _setLoadError(String fitId, String message, Object errorValue, StackTrace stackTrace) {
    error("Failed to load fit $fitId: $errorValue", stackTrace: stackTrace);
    state = FitServiceState.error(message: message);
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
      final message = path.existsSync()
          ? "This fit could not be loaded."
          : "This fit file is missing.";
      _setLoadError(fitId, message, errorValue, stackTrace);
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
        status: const FitServiceStatus.error(message: "Failed to save fit changes."),
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

  FitBundleCompatibility _compatibilityFor(FitStorage fit) => evaluateFitBundleCompatibility(
    fit.metadata,
    ref.read(currentBundleProvider),
    savedBundleAvailability: resolveSavedBundleAvailability(
      fit.metadata.bundleSnapshot,
      ref.read(currentBundleProvider),
      savedBundleInstalled: ref
          .read(bundleRegistryManagerProvider)
          .bundles
          .containsKey(fit.metadata.bundleSnapshot.bundleId),
    ),
  );

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
        status: const FitServiceStatus.error(
          message: "This fit is read-only until a compatible bundle is active.",
        ),
        fit: currentFit,
      );
      return;
    }

    final activeBundle = ref.read(currentBundleProvider);
    final updatedMetadata = currentFit.metadata.copyWith(
      lastModified: DateTime.now().millisecondsSinceEpoch,
      bundleId: activeBundle?.bundleId ?? currentFit.metadata.bundleId,
      bundleSnapshot: activeBundle == null
          ? currentFit.metadata.bundleSnapshot
          : FitBundleSnapshot.fromBundleMetadata(activeBundle),
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
  const factory FitEmulatorState.error({required String message, required native.Ship? previous}) =
      _FitEmulatorStateError;
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
    error: (message, previous) => true,
    emulated: (output) => false,
  );

  String? get errorMessage => when(
    notInitialized: () => null,
    emulating: (previous) => null,
    error: (message, previous) => message,
    emulated: (output) => null,
  );

  native.Ship? get emulated => when(
    notInitialized: () => null,
    emulating: (previous) => previous,
    error: (message, previous) => previous,
    emulated: (output) => output,
  );
}

@riverpod
native.Ship? nativeEmulatedShip(Ref ref, String fitId) =>
    ref.watch(fitEmulatorServiceProvider(fitId).select((t) => t.emulated));

@riverpod
class FitEmulatorService extends _$FitEmulatorService {
  late String _fitId;

  void _scheduleEmulationForCurrentFit() {
    final fitState = ref.read(fitProvider(_fitId));
    if (!fitState.isInitialized) return;
    unawaited(Future(() => emulate(fitState.fit)));
  }

  @override
  FitEmulatorState build(String fitId) {
    _fitId = fitId;
    // Register listener for subsequent changes. Do NOT synchronously call
    // `emulate` from the listener when `fireImmediately` would trigger it
    // during `build` (that can cause `state` to be mutated before the
    // notifier is fully initialized). Instead defer actual emulation to a
    // microtask.
    ref
      ..listen<FitServiceState>(fitProvider(fitId), (prev, next) {
        if (prev == next) return;
        if (!next.isInitialized) {
          state = next.hasError
              ? FitEmulatorState.error(
                  message: next.errorMessage ?? "This fit is unavailable.",
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
      ..listen(bundleCollectionSkillTypeIdsProvider, (prev, next) {
        if (prev == next) return;
        _scheduleEmulationForCurrentFit();
      });

    return const FitEmulatorState.notInitialized();
  }

  Future<void> retry() async {
    final fitState = ref.read(fitProvider(_fitId));
    if (!fitState.isInitialized) return;
    await emulate(fitState.fit);
  }

  Future<void> emulate(FitStorage fitStorage) async {
    state = state.emulating;
    debug("Started emulating ${fitStorage.metadata.fitId}");
    try {
      final engineState = ref.read(nativeFitEngineServiceProvider);
      final engine = engineState.engineOrNull;
      if (engine == null) {
        final message = engineState.errorMessage;
        if (message == null) {
          debug(
            "Deferring emulation for ${fitStorage.metadata.fitId}: fit engine is still loading",
          );
          return;
        }
        warning("Failed to emulate ${fitStorage.metadata.fitId}: $message");
        state = FitEmulatorState.error(message: message, previous: state.emulated);
        return;
      }

      final availableSkillTypeIds = ref.read(bundleCollectionSkillTypeIdsProvider);
      if (fitStorage.body.characterId == predefinedMaxCharacterId &&
          availableSkillTypeIds.isEmpty &&
          ref.read(bundleCollectionProvider) == null) {
        debug(
          "Deferring emulation for ${fitStorage.metadata.fitId}: bundle skill definitions are still loading",
        );
        return;
      }

      final characterSkills = resolveCharacterSkillsSync(
        fitStorage.body.characterId,
        availableSkillTypeIds,
      );
      final nativeCompatible = convertToNative(fitStorage, characterSkills: characterSkills);
      final emulatedOutput = await engine.emulate(fit: nativeCompatible);
      state = FitEmulatorState.emulated(output: emulatedOutput);
      debug("Finished emulating ${fitStorage.metadata.fitId}");
    } on Object catch (errorValue, stackTrace) {
      error(
        "Failed to emulate fit ${fitStorage.metadata.fitId}: $errorValue",
        stackTrace: stackTrace,
      );
      state = FitEmulatorState.error(
        message: "Stats are temporarily unavailable for this fit.",
        previous: state.emulated,
      );
    }
  }
}

@freezed
class NativeFitEngineState with _$NativeFitEngineState {
  const factory NativeFitEngineState.notInitialized() = _NativeFitEngineStateNotInitialized;
  const factory NativeFitEngineState.initializing() = _NativeFitEngineStateInitializing;
  const factory NativeFitEngineState.error({required String message}) = _NativeFitEngineStateError;
  const factory NativeFitEngineState.initialized({required native_server.FitEngine engine}) =
      _NativeFitEngineStateInitialized;

  const NativeFitEngineState._();

  String get debugOnlyDisplayState => switch (this) {
    _NativeFitEngineStateInitialized(engine: final _) => "initialized",
    _NativeFitEngineStateInitializing() => "initializing",
    _NativeFitEngineStateError(:final message) => "error: $message",
    _NativeFitEngineStateNotInitialized() => "not initialized",
    _ => throw Exception("Unreachable"),
  };
  bool get isInitializing => this is _NativeFitEngineStateInitializing;
  String? get errorMessage => switch (this) {
    _NativeFitEngineStateError(:final message) => message,
    _ => null,
  };
  native_server.FitEngine? get engineOrNull => switch (this) {
    _NativeFitEngineStateInitialized(:final engine) => engine,
    _ => null,
  };
}

@riverpodSingleton
class NativeFitEngineService extends _$NativeFitEngineService {
  BundleMetadata? _lastBundle;

  @override
  NativeFitEngineState build() {
    ref.listen(
      currentBundleProvider,
      (prev, next) {
        if (prev == next || next == null) return;
        _lastBundle = next;
        // Laten initialize routine to avoid influence the widget tree
        // when we change bundle.
        // DO NOT AWAIT THIS OR THE MUTATION WILL BE TRIGGERED IN THE WIDGET BUILD STAGE.
        unawaited(Future(() => _initialize(next)));
      },
      // we don't want the engine to load the bundle provider
      // because the provider will be initialized later
      weak: true,
    );
    return const NativeFitEngineState.notInitialized();
  }

  Future<void> retry() async {
    final bundle = _lastBundle ?? ref.read(currentBundleProvider);
    if (bundle == null) return;
    await _initialize(bundle);
  }

  Future<void> _initialize(BundleMetadata bundle) async {
    if (state.isInitializing) return;

    state = const NativeFitEngineState.initializing();
    try {
      final engine = native_server.FitEngine(
        data: await native_server.FitEngineData.init(staticRootPath: bundle.paths.getNativePath()),
      );
      state = NativeFitEngineState.initialized(engine: engine);
    } on Object catch (errorValue, stackTrace) {
      error(
        "Failed to initialize native fit engine for bundle ${bundle.bundleId}: $errorValue",
        stackTrace: stackTrace,
      );
      state = const NativeFitEngineState.error(
        message: "Fit calculations are temporarily unavailable.",
      );
    }
  }
}
