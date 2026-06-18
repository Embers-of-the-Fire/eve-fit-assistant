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
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:fixnum/fixnum.dart";
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
    required native_server.FitEnginePath path,
  }) async => _StubFitEngineData();

  @override
  Future<native_server.FitEnginePath> crateApiServerFitEnginePathFromFiles({
    required String types,
    required String dogmaAttributes,
    required String dogmaEffects,
    required String typeDogma,
    required String buffCollections,
  }) async => native_server.FitEnginePath(
    types: types,
    dogmaAttributes: dogmaAttributes,
    dogmaEffects: dogmaEffects,
    typeDogma: typeDogma,
    buffCollections: buffCollections,
  );

  @override
  Future<native_server.FitEnginePath> crateApiServerFitEnginePathFromRoot({
    required String root,
  }) async => native_server.FitEnginePath(
    types: "$root/types.pb2",
    dogmaAttributes: "$root/dogmaAttributes.pb2",
    dogmaEffects: "$root/dogmaEffects.pb2",
    typeDogma: "$root/typeDogma.pb2",
    buffCollections: "$root/dbuffcollections.pb2",
  );

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

// ── Helpers ─────────────────────────────────────────────────────────────────────

ResourceIndex _testResourceIndex() {
  final ri = ResourceIndex()..schemaVersion = 1;
  for (final id in const [
    "resource://static/native/types.pb2",
    "resource://static/native/dogmaAttributes.pb2",
    "resource://static/native/dogmaEffects.pb2",
    "resource://static/native/typeDogma.pb2",
    "resource://static/native/dbuffcollections.pb2",
  ]) {
    ri.entries.add(
      ResourceIndex_Entry()
        ..resourceId = id
        ..contentHash = "0" * 64
        ..size = Int64(0),
    );
  }
  return ri;
}

/// Writes a ResourceIndex with the five engine `.pb2` entries to disk so that
/// [NativeFitEngineService] can resolve them from the content-addressed blob store.
/// Returns the snapshot hash.
String _writeTestResourceSnapshot() {
  final assetStore = const AssetStore();
  final resourceIndex = _testResourceIndex();
  final meta = ResourceSnapshotMeta(
    schemaVersion: 1,
    serverId: "test-server",
    gameBuild: "test-build",
    gameVersion: "test-version",
    resourceCount: 5,
    createdAt: "2024-01-01T00:00:00Z",
  );
  return assetStore.writeResourceSnapshotSync(meta: meta, resourceIndex: resourceIndex);
}

late String _tempDir;
late String _snapshotHash;

ProviderContainer _container({required Option<String> activeSnapshotHash}) => ProviderContainer(
  overrides: [activeSnapshotHashProvider.overrideWithValue(activeSnapshotHash)],
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
      final container = _container(activeSnapshotHash: const None());
      addTearDown(container.dispose);

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, "not initialized");
    });

    test("initializes via retry when snapshot hash is available", () async {
      final container = _container(activeSnapshotHash: Some(_snapshotHash));
      addTearDown(container.dispose);

      await container.read(nativeFitEngineServiceProvider.notifier).retry();

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, "initialized");
    });

    test("retry re-initializes successfully on second call", () async {
      final container = _container(activeSnapshotHash: Some(_snapshotHash));
      addTearDown(container.dispose);

      await container.read(nativeFitEngineServiceProvider.notifier).retry();
      await container.read(nativeFitEngineServiceProvider.notifier).retry();

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, "initialized");
    });

    test("transitions to error when resource index is missing engine entries", () async {
      final ri = ResourceIndex()..schemaVersion = 1;
      final meta = ResourceSnapshotMeta(
        schemaVersion: 1,
        serverId: "test-server",
        gameBuild: "test-build",
        gameVersion: "test-version",
        resourceCount: 0,
        createdAt: "2024-06-18T00:00:00Z",
      );
      final brokenHash = const AssetStore().writeResourceSnapshotSync(
        meta: meta,
        resourceIndex: ri,
      );

      final container = _container(activeSnapshotHash: Some(brokenHash));
      addTearDown(container.dispose);

      await container.read(nativeFitEngineServiceProvider.notifier).retry();

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, contains("error"));
    });

    test("retry is no-op when no snapshot hash is available", () async {
      final container = _container(activeSnapshotHash: const None());
      addTearDown(container.dispose);

      await container.read(nativeFitEngineServiceProvider.notifier).retry();

      final state = container.read(nativeFitEngineServiceProvider);
      expect(state.debugOnlyDisplayState, "not initialized");
    });
  });
}
