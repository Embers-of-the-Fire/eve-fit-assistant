import "dart:async";
import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/native/api/server.dart" as native_server;
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/utils/riverpod.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:freezed_annotation/freezed_annotation.dart";
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
  const factory FitServiceState.loaded({
    required FitServiceStatus status,
    required FitStorage fit,
  }) = _FitServiceStateLoaded;

  const FitServiceState._();
  bool get isInitialized => when(notInitialized: () => false, loaded: (status, fit) => true);
  FitStorage get fit => when(
    notInitialized: () {
      final stackTrace = StackTrace.current;
      error("Invalid fit service access: fit not initialized", stackTrace: stackTrace);
      throw StateError("Fit service not initialized");
    },
    loaded: (status, fit) => fit,
  );
  FitServiceStatus get status =>
      when(notInitialized: FitServiceStatus.uninitialized, loaded: (status, fit) => status);
}

@riverpodSingleton
FitStorage fit(Ref ref) => ref.watch(fitServiceProvider.select((value) => value.fit));

@riverpodSingleton
FitServiceStatus fitStatus(Ref ref) =>
    ref.watch(fitServiceProvider.select((value) => value.status));

@riverpodSingleton
class FitService extends _$FitService {
  @override
  FitServiceState build() => const FitServiceState.notInitialized();

  Future<void> _loadFromDisk(String fitId) async {
    if (state.isInitialized) {
      warning("Fit service already initialized, force loading");
    }
    state = const FitServiceState.notInitialized();
    final path = File(FitStorage.fitStoragePathForId(fitId));
    if (!path.existsSync()) {
      error("Fit file does not exist: ${path.path}");
      throw StateError("Fit file does not exist: ${path.path}");
    }
    final text = await path.readAsString();
    final json = jsonDecode(text) as Map<String, dynamic>;
    final fit = FitStorage.fromJson(json);
    state = FitServiceState.loaded(
      status: FitServiceStatus.loaded(lastSync: DateTime.now()),
      fit: fit,
    );
  }

  Future<void> _syncToDisk({bool setState = true}) async {
    if (!state.isInitialized) {
      error("Cannot sync fit service: not initialized");
      return;
    }
    final fit = state.fit;
    state = FitServiceState.loaded(status: const FitServiceStatus.syncing(), fit: fit);
    final path = File(fit.fitStoragePath);
    final text = jsonEncode(fit.toJson());
    if (!path.existsSync()) {
      await path.parent.create(recursive: true);
    }
    await path.writeAsString(text);
    if (setState) {
      state = FitServiceState.loaded(
        status: FitServiceStatus.loaded(lastSync: DateTime.now()),
        fit: state.fit,
      );
    }
  }

  Future<void> mount(String fitId) async {
    await _loadFromDisk(fitId);
  }

  Future<void> unmount() async {
    await _syncToDisk();
    state = const FitServiceState.notInitialized();
  }

  Future<void> update(FitStorage Function(FitStorage) updater) async {
    if (!state.isInitialized) {
      error("Cannot update fit service: not initialized");
      return;
    }
    final fit = updater(
      state.fit,
    ).copyWith(metadata: state.fit.metadata.copyWith(lastModified: DateTime.now().second));
    state = FitServiceState.loaded(status: const FitServiceStatus.syncing(), fit: fit);
    ref.read(fitRegistryManagerProvider.notifier).updateFit(fit.metadata);
    await _syncToDisk(setState: false);
  }
}

@freezed
class FitEmulatorState with _$FitEmulatorState {
  const factory FitEmulatorState.notInitialized() = _FitEmulatorStateNotInitialized;
  const factory FitEmulatorState.emulating({required native.Ship? previous}) =
      _FitEmulatorStateEmulating;
  const factory FitEmulatorState.emulated({required native.Ship output}) =
      _FitEmulatorStateEmulated;

  const FitEmulatorState._();

  FitEmulatorState get emulating => switch (this) {
    _FitEmulatorStateEmulated(:final output) => _FitEmulatorStateEmulating(previous: output),
    _FitEmulatorStateEmulating(previous: final _) => this,
    _ => const _FitEmulatorStateEmulating(previous: null),
  };
}

@riverpodSingleton
class FitEmulatorService extends _$FitEmulatorService {
  @override
  FitEmulatorState build() => const FitEmulatorState.notInitialized();

  Future<void> emulate(FitStorage fitStorage) async {
    // We do no guard here because we want to refresh the output
    // if the state changes during the emulation.

    state = state.emulating;
    final nativeCompatible = convertToNative(fitStorage);
    final emulatedOutput = await ref
        .watch(nativeFitEngineServerProvider)
        .engine
        .emulate(fit: nativeCompatible);
    state = FitEmulatorState.emulated(output: emulatedOutput);
  }
}

@freezed
class NativeFitEngine with _$NativeFitEngine {
  const factory NativeFitEngine.notInitialized() = _NativeFitEngineNotInitialized;
  const factory NativeFitEngine.initializing() = _NativeFitEngineInitializing;
  const factory NativeFitEngine.initialized({required native_server.FitEngine engine}) =
      _NativeFitEngineInitialized;

  const NativeFitEngine._();

  String get debugOnlyDisplayState => switch (this) {
    _NativeFitEngineInitialized(engine: final _) => "initialized",
    _NativeFitEngineInitializing() => "initializing",
    _NativeFitEngineNotInitialized() => "not initialized",
    _ => throw Exception("Unreachable"),
  };
  bool get isInitializing => this is _NativeFitEngineInitializing;
  native_server.FitEngine get engine => switch (this) {
    _NativeFitEngineInitialized(:final engine) => engine,
    _ => throw StateError("Native fit engine not initialized"),
  };
}

@riverpodSingleton
class NativeFitEngineServer extends _$NativeFitEngineServer {
  @override
  NativeFitEngine build() {
    ref.listen(
      currentBundleProvider,
      (prev, next) {
        if (prev == next || next == null) return;
        // Laten initialize routine to avoid influence the widget tree
        // when we change bundle.
        // DO NOT AWAIT THIS OR THE MUTATION WILL BE TRIGGERED IN THE WIDGET BUILD STAGE.
        unawaited(Future(() => _initialize(next)));
      },
      // we don't want the engine to load the bundle provider
      // because the provider will be initialized later
      weak: true,
    );
    return const NativeFitEngine.notInitialized();
  }

  Future<void> _initialize(BundleMetadata bundle) async {
    if (state.isInitializing) return;

    state = const NativeFitEngine.initializing();
    final engine = native_server.FitEngine(
      data: await native_server.FitEngineData.init(staticRootPath: bundle.paths.getNativePath()),
    );
    state = NativeFitEngine.initialized(engine: engine);
  }
}
