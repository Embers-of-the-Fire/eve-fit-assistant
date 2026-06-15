import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/native/api/output.dart" as native_output;
import "package:eve_fit_assistant/native/api/server.dart" as native_server;
import "package:eve_fit_assistant/native/api/storage.dart" as native_storage;
import "package:eve_fit_assistant/native/frb_generated.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/models/snapshot_meta.dart";
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

  final Future<String> Function(String snapshotHash, ResourceIndex resourceIndex) resolveResult;

  @override
  final AssetStore assetStore = const AssetStore();

  @override
  String resolvePathFromSnapshot(String snapshotHash) => "/tmp/efa/native/stub";

  @override
  Future<String> prepareNativeDir(String snapshotHash, ResourceIndex resourceIndex) =>
      resolveResult(snapshotHash, resourceIndex);

  @override
  void cleanup(Iterable<String> activeSnapshotHashes) {}
}

class _TrackingNativeDirResolver implements NativeDirResolver {
  _TrackingNativeDirResolver({required this.resolveResult, required this.onCleanup});

  final Future<String> Function(String snapshotHash, ResourceIndex resourceIndex) resolveResult;
  final void Function() onCleanup;

  @override
  final AssetStore assetStore = const AssetStore();

  @override
  String resolvePathFromSnapshot(String snapshotHash) => "/tmp/efa/native/tracking";

  @override
  Future<String> prepareNativeDir(String snapshotHash, ResourceIndex resourceIndex) =>
      resolveResult(snapshotHash, resourceIndex);

  @override
  void cleanup(Iterable<String> activeSnapshotHashes) => onCleanup();
}

// ── Helpers ─────────────────────────────────────────────────────────────────────

/// Writes a minimal ResourceIndex to disk so that [NativeFitEngineService] can
/// resolve it during build. Returns the snapshot hash.
String _writeTestResourceSnapshot() {
  final assetStore = const AssetStore();
  final resourceIndex = ResourceIndex();
  final meta = const ResourceSnapshotMeta(
    schemaVersion: 1,
    serverId: "test-server",
    gameBuild: "test-build",
    gameVersion: "test-version",
    resourceCount: 0,
    createdAt: "2024-01-01T00:00:00Z",
  );
  return assetStore.writeResourceSnapshotSync(meta: meta, resourceIndex: resourceIndex);
}

late String _tempDir;
late String _snapshotHash;

ProviderContainer _container({
  required Option<String> activeSnapshotHash,
  required NativeDirResolver nativeDirResolver,
}) => ProviderContainer(
  overrides: [
    activeSnapshotHashProvider.overrideWithValue(activeSnapshotHash),
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
    _snapshotHash = _writeTestResourceSnapshot();
  });

  tearDown(() {
    final dir = Directory(_tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("NativeFitEngineService", () {
    test("starts in notInitialized state", () {
      final container = _container(
        activeSnapshotHash: const None(),
        nativeDirResolver: _StubNativeDirResolver(
          resolveResult: (_, __) async => _tempDir,
        ),
      );
      addTearDown(container.dispose);

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, "not initialized");
    });

    test("initializes via retry when snapshot hash is available", () async {
      final resolver = _StubNativeDirResolver(
        resolveResult: (_, __) async => _tempDir,
      );
      final container = _container(
        activeSnapshotHash: Some(_snapshotHash),
        nativeDirResolver: resolver,
      );
      addTearDown(container.dispose);

      await container.read(nativeFitEngineServiceProvider.notifier).retry();

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, "initialized");
    });

    test("retry re-initializes successfully on second call", () async {
      final resolver = _StubNativeDirResolver(
        resolveResult: (_, __) async => _tempDir,
      );
      final container = _container(
        activeSnapshotHash: Some(_snapshotHash),
        nativeDirResolver: resolver,
      );
      addTearDown(container.dispose);

      await container.read(nativeFitEngineServiceProvider.notifier).retry();
      await container.read(nativeFitEngineServiceProvider.notifier).retry();

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, "initialized");
    });

    test("transitions to error when native dir resolution fails", () async {
      final resolver = _StubNativeDirResolver(
        resolveResult: (_, __) async => throw Exception("Simulated failure"),
      );
      final container = _container(
        activeSnapshotHash: Some(_snapshotHash),
        nativeDirResolver: resolver,
      );
      addTearDown(container.dispose);

      await container.read(nativeFitEngineServiceProvider.notifier).retry();

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, contains("error"));
    });

    test("retry is no-op when no snapshot hash is available", () async {
      final container = _container(
        activeSnapshotHash: const None(),
        nativeDirResolver: _StubNativeDirResolver(
          resolveResult: (_, __) async => _tempDir,
        ),
      );
      addTearDown(container.dispose);

      await container.read(nativeFitEngineServiceProvider.notifier).retry();

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, "not initialized");
    });

    test("cleanup is called on dispose", () async {
      var cleanupCalled = false;
      final resolver = _TrackingNativeDirResolver(
        resolveResult: (_, __) async => _tempDir,
        onCleanup: () => cleanupCalled = true,
      );
      final container = _container(
        activeSnapshotHash: Some(_snapshotHash),
        nativeDirResolver: resolver,
      );

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
