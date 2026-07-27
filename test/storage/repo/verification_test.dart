import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/checkout_reflog.pb.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/checkout_registry_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_meta.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/models/snapshot_meta.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/utils.dart";
import "package:eve_fit_assistant/storage/repo/verification.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;

class _FakeRemoteCatalogService extends RemoteCatalogService {
  _FakeRemoteCatalogService() : super(dio: Dio(), originUrl: "https://test.local");
}

class _SlowFakeRemoteCatalogService extends RemoteCatalogService {
  _SlowFakeRemoteCatalogService({required this.completer})
    : super(dio: Dio(), originUrl: "https://test.local");

  final Completer<void> completer;

  @override
  Future<Either<CatalogError, Uint8List>> fetchBlob(
    String identHash,
    String contentHash, {
    ProgressCallback? onReceiveProgress,
  }) async {
    await completer.future;
    return const Left(CatalogNetworkError(message: "test"));
  }
}

class _ServingFakeRemoteCatalogService extends RemoteCatalogService {
  _ServingFakeRemoteCatalogService({required this.blobs})
    : super(dio: Dio(), originUrl: "https://test.local");

  final Map<String, Uint8List> blobs;

  @override
  Future<Either<CatalogError, Uint8List>> fetchBlob(
    String identHash,
    String contentHash, {
    ProgressCallback? onReceiveProgress,
  }) async {
    final data = blobs[contentHash];
    if (data == null) {
      return const Left(CatalogNotFoundError(message: "not found"));
    }
    return Right(data);
  }
}

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_verification_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  late String tempDir;
  late String checkoutId;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_verification_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.appSupportPath = tempDir;
    checkoutId = "test-checkout-001";
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  VerificationService makeService() {
    final fakeRemote = _FakeRemoteCatalogService();
    const assetStore = AssetStore();
    final registryService = CheckoutRegistryService();
    const diffEngine = DiffEngine();
    final checkoutService = CheckoutService(
      assetStore: assetStore,
      remoteCatalogService: fakeRemote,
      diffEngine: diffEngine,
      checkoutRegistry: registryService,
    );
    return VerificationService(
      checkoutService: checkoutService,
      assetStore: assetStore,
      checkoutRegistry: registryService,
      remoteCatalogService: fakeRemote,
    );
  }

  /// Sets up a full checkout environment with a resource snapshot,
  /// registry entry, metadata, reflog, and blobs.
  ///
  /// Returns the resource snapshot hash.
  String setupCheckout() {
    const assetStore = AssetStore();

    // 1. Create a ResourceIndex with two test entries
    const ridA = "resource://test/a.bin";
    const ridB = "resource://test/b.bin";
    final ihashA = RepoHash.hashIdent(ridA);
    final ihashB = RepoHash.hashIdent(ridB);

    final blobDataA = Uint8List.fromList([1, 2, 3, 4, 5]);
    final blobDataB = Uint8List.fromList([6, 7, 8, 9, 0]);
    final chashA = RepoHash.hashContent(blobDataA);
    final chashB = RepoHash.hashContent(blobDataB);

    final ri = ResourceIndex()
      ..schemaVersion = 1
      ..entries.add(
        ResourceIndex_Entry()
          ..resourceId = ridA
          ..contentHash = chashA
          ..size = Int64(blobDataA.length),
      )
      ..entries.add(
        ResourceIndex_Entry()
          ..resourceId = ridB
          ..contentHash = chashB
          ..size = Int64(blobDataB.length),
      );

    // 2. Write the resource snapshot to get a deterministic snapshot hash
    final meta = ResourceSnapshotMeta(
      schemaVersion: 1,
      serverId: "tranquility",
      gameBuild: "1.0",
      gameVersion: "v1.0.0",
      resourceCount: ri.entries.length,
      createdAt: "2026-06-17T12:00:00Z",
    );
    final snapshotHash = assetStore.writeResourceSnapshotSync(meta: meta, resourceIndex: ri);

    // 3. Write blobs at the expected paths
    final blobPathA = RepoPaths.blobPath(ihashA, chashA);
    final blobPathB = RepoPaths.blobPath(ihashB, chashB);
    File(blobPathA).parent.createSync(recursive: true);
    File(blobPathB).parent.createSync(recursive: true);
    File(blobPathA).writeAsBytesSync(blobDataA, flush: true);
    File(blobPathB).writeAsBytesSync(blobDataB, flush: true);

    // 4. Write checkout metadata
    final metaPath = RepoPaths.checkoutMetaPath(checkoutId);
    final checkoutMeta = CheckoutMeta(
      schemaVersion: 1,
      channel: "testing",
      resourceSnapshotHash: snapshotHash,
      serverId: "tranquility",
      createdAt: "2026-06-17T12:00:00Z",
      name: IMap(const {"en": "Test Checkout"}),
      gameBuild: "1.0",
      gameVersion: "v1.0.0",
    );
    File(metaPath).parent.createSync(recursive: true);
    final tmpMeta = File("$metaPath.tmp");
    tmpMeta
      ..writeAsStringSync(jsonEncode(checkoutMeta.toJson()), flush: true)
      ..renameSync(metaPath);

    // 5. Write reflog protobuf
    final reflogPath = RepoPaths.checkoutReflogPath(checkoutId);
    final reflog = CheckoutReflog()
      ..schemaVersion = 1
      ..entries.add(
        CheckoutReflog_Entry()
          ..from = ""
          ..to = snapshotHash
          ..timestamp = "2026-06-17T12:00:00Z",
      );
    writeProtobufSync(reflogPath, reflog);

    // 6. Write checkout registry
    final entry = CheckoutRegistryEntry(
      channel: "testing",
      serverId: "tranquility",
      resourceSnapshotHash: snapshotHash,
      createdAt: "2026-06-17T12:00:00Z",
      name: IMap(const {"en": "Test Checkout"}),
    );
    final registry = CheckoutRegistry(
      schemaVersion: 1,
      activeCheckoutId: checkoutId,
      checkouts: IMap({checkoutId: entry}),
    );
    final registryPath = RepoPaths.checkoutRegistryPath;
    File(registryPath).parent.createSync(recursive: true);
    final tmpRegistry = File("$registryPath.tmp");
    tmpRegistry
      ..writeAsStringSync(jsonEncode(registry.toJson()), flush: true)
      ..renameSync(registryPath);

    return snapshotHash;
  }

  group("prune preserves active checkout resources", () {
    test("snapshot directory is not deleted by prune", () {
      final snapshotHash = setupCheckout();
      final service = makeService();

      final snapshotDir = RepoPaths.resourceSnapshotPath(snapshotHash);
      final indexPath = RepoPaths.resourceIndexPath(snapshotHash);

      // Verify setup is correct
      expect(
        Directory(snapshotDir).existsSync(),
        isTrue,
        reason: "Snapshot directory should exist before prune",
      );
      expect(
        File(indexPath).existsSync(),
        isTrue,
        reason: "resources.pb2 should exist before prune",
      );

      // Run prune
      final deleted = service.prune();

      // Snapshot directory should still exist
      expect(
        Directory(snapshotDir).existsSync(),
        isTrue,
        reason: "Snapshot directory should NOT be deleted by prune (checkout references it)",
      );
      expect(
        File(indexPath).existsSync(),
        isTrue,
        reason: "resources.pb2 should NOT be deleted by prune",
      );

      expect(deleted, 0, reason: "No files should be deleted when checkout references everything");
    });

    test("blob files are not deleted by prune", () {
      final snapshotHash = setupCheckout();
      final service = makeService();

      // Load the ResourceIndex to get expected blob paths
      final assetStore = const AssetStore();
      final riOpt = assetStore.readResourceIndexSync(snapshotHash);
      expect(riOpt.isSome(), isTrue);
      final ri = riOpt.toNullable()!;

      // Collect expected blob paths
      final expectedBlobPaths = <String>{};
      for (final entry in ri.entries) {
        final ihash = RepoHash.hashIdent(entry.resourceId);
        expectedBlobPaths.add(RepoPaths.blobPath(ihash, entry.contentHash));
      }

      // Verify blobs exist before prune
      for (final path in expectedBlobPaths) {
        expect(File(path).existsSync(), isTrue, reason: "Blob should exist before prune: $path");
      }

      // Run prune
      final deleted = service.prune();
      expect(deleted, 0, reason: "No files should be deleted");

      // Verify blobs still exist after prune
      for (final path in expectedBlobPaths) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason: "Blob should NOT be deleted by prune: $path",
        );
      }
    });

    test("unreferenced snapshot IS deleted by prune", () {
      setupCheckout(); // Sets up checkout referencing known snapshot

      // Create an unreferenced snapshot directly (not linked to any checkout)
      const assetStore = AssetStore();
      final orphanRi = ResourceIndex()
        ..schemaVersion = 1
        ..entries.add(
          ResourceIndex_Entry()
            ..resourceId = "resource://test/orphan.bin"
            ..contentHash =
                "orphan_hash_0000000000000000000000000000000000000000000000000000000000000000"
            ..size = Int64(10),
        );
      final orphanMeta = ResourceSnapshotMeta(
        schemaVersion: 1,
        serverId: "tranquility",
        gameBuild: "1.0",
        gameVersion: "v1.0.0",
        resourceCount: orphanRi.entries.length,
        createdAt: "2026-06-17T13:00:00Z",
      );
      final orphanHash = assetStore.writeResourceSnapshotSync(
        meta: orphanMeta,
        resourceIndex: orphanRi,
      );
      final orphanDir = RepoPaths.resourceSnapshotPath(orphanHash);
      expect(
        Directory(orphanDir).existsSync(),
        isTrue,
        reason: "Orphan snapshot should exist before prune",
      );

      // Run prune
      final service = makeService();
      final deleted = service.prune();

      // Referenced snapshot should be preserved, unreferenced deleted
      expect(
        Directory(orphanDir).existsSync(),
        isFalse,
        reason: "Orphan snapshot should be deleted by prune",
      );
      // deleted should be >= 1 (at least the orphan snapshot)
      expect(deleted >= 1, isTrue, reason: "At least 1 item should be deleted");
    });

    test("basename matches registry resourceSnapshotHash", () {
      final snapshotHash = setupCheckout();

      final registryService = CheckoutRegistryService();
      final registry = registryService.readRegistry();
      expect(registry.isSome(), isTrue);

      final entry = registry.toNullable()!.checkouts[checkoutId];
      expect(entry, isNotNull);
      final registryHash = entry!.resourceSnapshotHash;
      expect(registryHash.isNotEmpty, isTrue);

      final snapshotDir = RepoPaths.resourceSnapshotPath(snapshotHash);
      expect(Directory(snapshotDir).existsSync(), isTrue);

      final resourcesDir = Directory("${RepoPaths.assetsPath}/resources");
      expect(resourcesDir.existsSync(), isTrue);

      var foundHash = false;
      for (final dir in resourcesDir.listSync().whereType<Directory>()) {
        final name = p.basename(dir.path);
        if (name == registryHash) {
          foundHash = true;
          break;
        }
      }
      expect(
        foundHash,
        isTrue,
        reason: "p.basename(dir.path) should match registry resourceSnapshotHash",
      );
    });

    test("uri.pathSegments.last returns empty string for Directory (documents the bug)", () {
      setupCheckout();
      final resourcesDir = Directory("${RepoPaths.assetsPath}/resources");
      final dirs = resourcesDir.listSync().whereType<Directory>().toList();
      expect(dirs.isNotEmpty, isTrue);

      final nameFromUri = dirs.first.uri.pathSegments.last;
      // Documents the root cause: uri.pathSegments.last returns ""
      // for Directory URIs because they have a trailing slash
      expect(
        nameFromUri,
        isEmpty,
        reason:
            "uri.pathSegments.last returns '' for Directory objects "
            "because the URI has a trailing slash. "
            "Use p.basename(dir.path) instead.",
      );

      final nameFromBasename = p.basename(dirs.first.path);
      expect(nameFromBasename.isNotEmpty, isTrue);
      expect(nameFromBasename, isNot(isEmpty));
    });
  });

  group("concurrency guard", () {
    test("verify() can be called sequentially after completion", () {
      setupCheckout();
      final service = makeService();

      final result1 = service.verify();
      expect(result1, isEmpty);

      final result2 = service.verify();
      expect(result2, isEmpty);

      expect(service.isRunning, isFalse);
    });

    test("prune() can be called sequentially after completion", () {
      setupCheckout();
      final service = makeService();

      final count1 = service.prune();
      expect(count1, 0);

      final count2 = service.prune();
      expect(count2, 0);

      expect(service.isRunning, isFalse);
    });

    test("verifyAsync() can be called sequentially after completion", () async {
      setupCheckout();
      final service = makeService();

      final result1 = await service.verifyAsync();
      expect(result1, isEmpty);

      final result2 = await service.verifyAsync();
      expect(result2, isEmpty);

      expect(service.isRunning, isFalse);
    });

    test("pruneAsync() can be called sequentially after completion", () async {
      setupCheckout();
      final service = makeService();

      final count1 = await service.pruneAsync();
      expect(count1, 0);

      final count2 = await service.pruneAsync();
      expect(count2, 0);

      expect(service.isRunning, isFalse);
    });

    test("verifyAsync() rejects concurrent invocation", () async {
      setupCheckout();
      final service = makeService();

      final first = service.verifyAsync();
      expect(service.isRunning, isTrue);
      expect(() => service.verify(), throwsA(isA<StateError>()));
      expect(() => service.prune(), throwsA(isA<StateError>()));
      expect(service.verifyAsync, throwsA(isA<StateError>()));

      await first;
      expect(service.isRunning, isFalse);
    });

    test("verifyAsync() detects missing blobs", () async {
      final snapshotHash = setupCheckout();
      const assetStore = AssetStore();

      final riOpt = assetStore.readResourceIndexSync(snapshotHash);
      expect(riOpt.isSome(), isTrue);
      final ri = riOpt.toNullable()!;

      final entryA = ri.entries.first;
      final ihashA = RepoHash.hashIdent(entryA.resourceId);
      final blobPathA = RepoPaths.blobPath(ihashA, entryA.contentHash);
      File(blobPathA).deleteSync();

      final service = makeService();
      final issues = await service.verifyAsync();
      expect(issues.length, 1);
      expect(issues.first, isA<VerificationMissingFiles>());
      expect(service.isRunning, isFalse);
    });

    test("repairAll() rejects concurrent invocation", () async {
      final snapshotHash = setupCheckout();
      const assetStore = AssetStore();

      final riOpt = assetStore.readResourceIndexSync(snapshotHash);
      expect(riOpt.isSome(), isTrue);
      final ri = riOpt.toNullable()!;
      final entryA = ri.entries.first;
      final ihashA = RepoHash.hashIdent(entryA.resourceId);
      final blobPathA = RepoPaths.blobPath(ihashA, entryA.contentHash);
      File(blobPathA).deleteSync();

      final completer = Completer<void>();
      final fakeRemote = _SlowFakeRemoteCatalogService(completer: completer);
      final registryService = CheckoutRegistryService();
      const diffEngine = DiffEngine();
      final checkoutService = CheckoutService(
        assetStore: assetStore,
        remoteCatalogService: fakeRemote,
        diffEngine: diffEngine,
        checkoutRegistry: registryService,
      );
      final service = VerificationService(
        checkoutService: checkoutService,
        assetStore: assetStore,
        checkoutRegistry: registryService,
        remoteCatalogService: fakeRemote,
      );

      final first = service.repairAll(channel: Channel.testing);

      expect(service.isRunning, isTrue);
      expect(() => service.repairAll(channel: Channel.testing), throwsA(isA<StateError>()));
      expect(() => service.verify(), throwsA(isA<StateError>()));
      expect(() => service.prune(), throwsA(isA<StateError>()));

      completer.complete();
      final unresolved = await first;

      expect(service.isRunning, isFalse);
      expect(unresolved.length, 1);
      expect(unresolved.first, isA<VerificationMissingFiles>());
    });

    test("guard releases after repairAll() failure", () async {
      final snapshotHash = setupCheckout();
      const assetStore = AssetStore();

      final riOpt = assetStore.readResourceIndexSync(snapshotHash);
      expect(riOpt.isSome(), isTrue);
      final ri = riOpt.toNullable()!;
      final entryA = ri.entries.first;
      final ihashA = RepoHash.hashIdent(entryA.resourceId);
      final blobPathA = RepoPaths.blobPath(ihashA, entryA.contentHash);
      File(blobPathA).deleteSync();

      final completer = Completer<void>();
      final fakeRemote = _SlowFakeRemoteCatalogService(completer: completer);
      final registryService = CheckoutRegistryService();
      const diffEngine = DiffEngine();
      final checkoutService = CheckoutService(
        assetStore: assetStore,
        remoteCatalogService: fakeRemote,
        diffEngine: diffEngine,
        checkoutRegistry: registryService,
      );
      final service = VerificationService(
        checkoutService: checkoutService,
        assetStore: assetStore,
        checkoutRegistry: registryService,
        remoteCatalogService: fakeRemote,
      );

      final first = service.repairAll(channel: Channel.testing);
      completer.complete();
      final unresolved = await first;

      expect(service.isRunning, isFalse);
      expect(unresolved.length, 1);
      expect(unresolved.first, isA<VerificationMissingFiles>());
      final result = service.verify();
      expect(result.length, 1);
      expect(result.first, isA<VerificationMissingFiles>());
    });
  });

  group("repairAll downloads missing blobs", () {
    test("re-downloads a deleted blob and verify passes afterward", () async {
      final snapshotHash = setupCheckout();
      const assetStore = AssetStore();

      final riOpt = assetStore.readResourceIndexSync(snapshotHash);
      expect(riOpt.isSome(), isTrue);
      final ri = riOpt.toNullable()!;
      expect(ri.entries.length, 2);

      final entryA = ri.entries.first;
      final ihashA = RepoHash.hashIdent(entryA.resourceId);
      final blobPathA = RepoPaths.blobPath(ihashA, entryA.contentHash);

      final originalData = File(blobPathA).readAsBytesSync();
      File(blobPathA).deleteSync();

      final service = makeService();
      final issuesBefore = service.verify();
      expect(issuesBefore.length, 1);
      expect(issuesBefore.first, isA<VerificationMissingFiles>());

      final servingRemote = _ServingFakeRemoteCatalogService(
        blobs: {entryA.contentHash: Uint8List.fromList(originalData)},
      );
      final registryService = CheckoutRegistryService();
      const diffEngine = DiffEngine();
      final checkoutService = CheckoutService(
        assetStore: assetStore,
        remoteCatalogService: servingRemote,
        diffEngine: diffEngine,
        checkoutRegistry: registryService,
      );
      final repairService = VerificationService(
        checkoutService: checkoutService,
        assetStore: assetStore,
        checkoutRegistry: registryService,
        remoteCatalogService: servingRemote,
      );

      final unresolved = await repairService.repairAll(channel: Channel.testing);
      expect(unresolved, isEmpty);

      expect(File(blobPathA).existsSync(), isTrue);
      expect(File(blobPathA).readAsBytesSync(), originalData);

      final issuesAfter = repairService.verify();
      expect(issuesAfter, isEmpty);
    });

    test("reports unresolved when remote does not have the blob", () async {
      final snapshotHash = setupCheckout();
      const assetStore = AssetStore();

      final riOpt = assetStore.readResourceIndexSync(snapshotHash);
      expect(riOpt.isSome(), isTrue);
      final ri = riOpt.toNullable()!;

      final entryA = ri.entries.first;
      final ihashA = RepoHash.hashIdent(entryA.resourceId);
      final blobPathA = RepoPaths.blobPath(ihashA, entryA.contentHash);
      File(blobPathA).deleteSync();

      final servingRemote = _ServingFakeRemoteCatalogService(blobs: {});
      final registryService = CheckoutRegistryService();
      const diffEngine = DiffEngine();
      final checkoutService = CheckoutService(
        assetStore: assetStore,
        remoteCatalogService: servingRemote,
        diffEngine: diffEngine,
        checkoutRegistry: registryService,
      );
      final repairService = VerificationService(
        checkoutService: checkoutService,
        assetStore: assetStore,
        checkoutRegistry: registryService,
        remoteCatalogService: servingRemote,
      );

      final unresolved = await repairService.repairAll(channel: Channel.testing);
      expect(unresolved.length, 1);
      expect(unresolved.first, isA<VerificationMissingFiles>());
    });
  });
}
