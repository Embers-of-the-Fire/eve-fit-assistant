import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native_output;
import "package:eve_fit_assistant/native/api/server.dart" as native_server;
import "package:eve_fit_assistant/native/api/storage.dart" as native_storage;
import "package:eve_fit_assistant/native/frb_generated.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/native_dir.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:riverpod/riverpod.dart";

// ── Stubs for FRB types ─────────────────────────────────────────────────────────

class _StubFitEngineData implements native_server.FitEngineData {
  @override
  void dispose() {}

  @override
  bool get isDisposed => false;
}

class _StubFitEngine implements native_server.FitEngine {
  @override
  void dispose() {}

  @override
  bool get isDisposed => false;

  @override
  Future<native_output.Ship> emulate({required native_storage.FitStorage fit}) =>
      throw UnimplementedError();
}

class _StubRustLibApi extends RustLibApi {
  @override
  Future<native_server.FitEngineData> crateApiServerFitEngineDataInit({
    required String staticRootPath,
  }) async => _StubFitEngineData();

  @override
  native_server.FitEngine crateApiServerFitEngineNew({required native_server.FitEngineData data}) =>
      _StubFitEngine();

  @override
  Future<native_output.Ship> crateApiServerFitEngineEmulate({
    required native_server.FitEngine that,
    required native_storage.FitStorage fit,
  }) => throw UnimplementedError();

  @override
  native_storage.FitStorage crateApiStorageFitStorageNew({
    required native_storage.Fit fit,
    required Map<int, int> skills,
    required Map<int, native_storage.DynamicItem> dynamicItems,
  }) => throw UnimplementedError();

  @override
  RustArcIncrementStrongCountFnType get rust_arc_increment_strong_count_FitEngine =>
      throw UnimplementedError();

  @override
  RustArcDecrementStrongCountFnType get rust_arc_decrement_strong_count_FitEngine =>
      throw UnimplementedError();

  @override
  CrossPlatformFinalizerArg get rust_arc_decrement_strong_count_FitEnginePtr =>
      throw UnimplementedError();

  @override
  RustArcIncrementStrongCountFnType get rust_arc_increment_strong_count_FitEngineData =>
      throw UnimplementedError();

  @override
  RustArcDecrementStrongCountFnType get rust_arc_decrement_strong_count_FitEngineData =>
      throw UnimplementedError();

  @override
  CrossPlatformFinalizerArg get rust_arc_decrement_strong_count_FitEngineDataPtr =>
      throw UnimplementedError();

  @override
  RustArcIncrementStrongCountFnType get rust_arc_increment_strong_count_FitStorage =>
      throw UnimplementedError();

  @override
  RustArcDecrementStrongCountFnType get rust_arc_decrement_strong_count_FitStorage =>
      throw UnimplementedError();

  @override
  CrossPlatformFinalizerArg get rust_arc_decrement_strong_count_FitStoragePtr =>
      throw UnimplementedError();
}

// ── Test stubs ──────────────────────────────────────────────────────────────────

class _StubNativeDirResolver implements NativeDirResolver {
  _StubNativeDirResolver({required this.resolveResult});

  final Future<String> Function(AssetManifest) resolveResult;

  @override
  final AssetStore assetStore = const AssetStore();

  @override
  String resolvePathFromManifest(AssetManifest manifest) => "/tmp/efa/native/stub";

  @override
  Future<String> prepareNativeDir(AssetManifest manifest) => resolveResult(manifest);

  @override
  void cleanup(Iterable<AssetManifest> activeManifests) {}
}

// ── Helpers ─────────────────────────────────────────────────────────────────────

AssetManifest _emptyManifest() => const AssetManifest(assetsVersion: 1);

late String _tempDir;

ProviderContainer _container({
  required Option<AssetManifest> manifest,
  required NativeDirResolver nativeDirResolver,
}) => ProviderContainer(
  overrides: [
    activeCheckoutManifestProvider.overrideWithValue(manifest),
    nativeDirResolverProvider.overrideWithValue(nativeDirResolver),
  ],
);

void main() {
  setUpAll(() {
    RustLib.initMock(api: _StubRustLibApi());
    final logDir = Directory.systemTemp.createTempSync("efa_engine_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    _tempDir = Directory.systemTemp.createTempSync("efa_engine_test_").path;
    PathProvider.documentsPath = _tempDir;
  });

  tearDown(() {
    final dir = Directory(_tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("NativeFitEngineService", () {
    test("starts in notInitialized state", () {
      final container = _container(
        manifest: const None(),
        nativeDirResolver: _StubNativeDirResolver(resolveResult: (_) async => _tempDir),
      );
      addTearDown(container.dispose);

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, "not initialized");
    });

    test("initializes via retry when manifest is available", () async {
      final resolver = _StubNativeDirResolver(resolveResult: (_) async => _tempDir);
      final container = _container(manifest: Some(_emptyManifest()), nativeDirResolver: resolver);
      addTearDown(container.dispose);

      await container.read(nativeFitEngineServiceProvider.notifier).retry();

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, "initialized");
    });

    test("retry re-initializes successfully on second call", () async {
      final resolver = _StubNativeDirResolver(resolveResult: (_) async => _tempDir);
      final container = _container(manifest: Some(_emptyManifest()), nativeDirResolver: resolver);
      addTearDown(container.dispose);

      await container.read(nativeFitEngineServiceProvider.notifier).retry();
      await container.read(nativeFitEngineServiceProvider.notifier).retry();

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, "initialized");
    });

    test("transitions to error when native dir resolution fails", () async {
      final resolver = _StubNativeDirResolver(
        resolveResult: (_) async => throw Exception("Simulated failure"),
      );
      final container = _container(manifest: Some(_emptyManifest()), nativeDirResolver: resolver);
      addTearDown(container.dispose);

      await container.read(nativeFitEngineServiceProvider.notifier).retry();

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, contains("error"));
    });

    test("retry is no-op when no manifest is available", () async {
      final container = _container(
        manifest: const None(),
        nativeDirResolver: _StubNativeDirResolver(resolveResult: (_) async => _tempDir),
      );
      addTearDown(container.dispose);

      await container.read(nativeFitEngineServiceProvider.notifier).retry();

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, "not initialized");
    });

    test("cleanup is called on dispose", () async {
      var cleanupCalled = false;
      final resolver = _TrackingNativeDirResolver(
        resolveResult: (_) async => _tempDir,
        onCleanup: () => cleanupCalled = true,
      );
      final container = _container(manifest: Some(_emptyManifest()), nativeDirResolver: resolver);

      // Trigger init
      await container.read(nativeFitEngineServiceProvider.notifier).retry();

      // Cleanup is not called on init/retry
      expect(cleanupCalled, isFalse);

      // Dispose should trigger cleanup
      container.dispose();
      expect(cleanupCalled, isTrue);
    });
  });
}

class _TrackingNativeDirResolver implements NativeDirResolver {
  _TrackingNativeDirResolver({required this.resolveResult, required this.onCleanup});

  final Future<String> Function(AssetManifest) resolveResult;
  final void Function() onCleanup;

  @override
  final AssetStore assetStore = const AssetStore();

  @override
  String resolvePathFromManifest(AssetManifest manifest) => "/tmp/efa/native/tracking";

  @override
  Future<String> prepareNativeDir(AssetManifest manifest) => resolveResult(manifest);

  @override
  void cleanup(Iterable<AssetManifest> activeManifests) => onCleanup();
}
