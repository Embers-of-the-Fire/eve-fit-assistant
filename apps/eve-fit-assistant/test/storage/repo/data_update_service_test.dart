@TestOn("vm")
library;

import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:efa_proto/generation_resources.pb.dart";
import "package:efa_proto/resource_index.pb.dart";
import "package:efa_proto/server_history.pb.dart";
import "package:eve_fit_assistant/features/remote_content/cadence.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/channel_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_registry_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/data_update_service.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_head_meta.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/models/snapshot_meta.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/service.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

class MockRepoService extends Mock implements RepoService {}

class MockChannelService extends Mock implements ChannelService {}

class MockCheckoutService extends Mock implements CheckoutService {}

class MockAssetStore extends Mock implements AssetStore {}

class MockRemoteCatalogService extends Mock implements RemoteCatalogService {}

class MockCheckoutRegistryService extends Mock implements CheckoutRegistryService {}

void main() {
  late String tempDir;
  late MockRepoService mockRepoService;
  late MockChannelService mockChannelService;
  late MockCheckoutService mockCheckoutService;
  late MockAssetStore mockAssetStore;
  late MockRemoteCatalogService mockRemoteCatalogService;
  late MockCheckoutRegistryService mockRegistryService;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_data_update_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
    registerFallbackValue("");
    registerFallbackValue(Channel.testing);
    registerFallbackValue(
      ResourceIndex()
        ..schemaVersion = 1
        ..entries.add(
          ResourceIndex_Entry()
            ..resourceId = "resource://test/a.bin"
            ..contentHash = "hash_a"
            ..size = Int64(5),
        ),
    );
    registerFallbackValue(
      const ResourceSnapshotMeta(
        schemaVersion: 1,
        serverId: "tq",
        gameBuild: "1.0",
        gameVersion: "v1.0.0",
        resourceCount: 1,
        createdAt: "2026-06-17T12:00:00Z",
      ),
    );
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_data_update_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.appSupportPath = tempDir;

    mockRepoService = MockRepoService();
    mockChannelService = MockChannelService();
    mockCheckoutService = MockCheckoutService();
    mockAssetStore = MockAssetStore();
    mockRemoteCatalogService = MockRemoteCatalogService();
    mockRegistryService = MockCheckoutRegistryService();

    when(() => mockRepoService.checkoutRegistry).thenReturn(mockRegistryService);

    // Default: no promoted history anywhere (pre-rollout channels).
    when(
      () => mockChannelService.readServerHistory(any()),
    ).thenAnswer((_) async => const None());
    when(
      () => mockRemoteCatalogService.fetchServerHistory(any()),
    ).thenAnswer((_) async => const Left(CatalogNotFoundError(message: "no history")));
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  const testLocalHash =
      "sha256:aaaa0000111122223333444455556666777788889999aaaabbbbccccddddeeeeffff";
  const testRemoteHash =
      "sha256:ffff0000111122223333444455556666777788889999aaaabbbbccccddddeeeeffff";

  DataUpdateService makeService({DataCadence cadence = DataCadence.immediate}) =>
      DataUpdateService(
        repoService: mockRepoService,
        channelService: mockChannelService,
        checkoutService: mockCheckoutService,
        assetStore: mockAssetStore,
        remoteCatalogService: mockRemoteCatalogService,
        cadence: cadence,
      );

  CheckoutRegistryEntry testEntry({String channel = "testing"}) => CheckoutRegistryEntry(
    channel: channel,
    serverId: "tq",
    resourceSnapshotHash: "old_snapshot_hash",
    name: IMap(const {"en": "Test"}),
    createdAt: "2026-06-17T12:00:00Z",
  );

  GenerationResources _generationResources({
    required String serverId,
    required String snapshotHash,
  }) => GenerationResources(
    schemaVersion: 1,
    entries: [GenerationResources_Entry(serverId: serverId, snapshotHash: snapshotHash)],
  );

  Uint8List _generationResourcesBytes({required String serverId, required String snapshotHash}) =>
      _generationResources(serverId: serverId, snapshotHash: snapshotHash).writeToBuffer();

  void stubRegistry(Map<String, CheckoutRegistryEntry> checkouts) {
    when(() => mockRegistryService.readRegistry()).thenReturn(
      Some(
        CheckoutRegistry(
          schemaVersion: 1,
          activeCheckoutId: checkouts.keys.firstOrNull,
          checkouts: IMap(checkouts),
        ),
      ),
    );
  }

  group("checkForCheckout", () {
    test("returns upToDate when local and remote generation hashes match", () async {
      stubRegistry({"checkout-1": testEntry()});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer((_) async => testLocalHash);
      when(() => mockChannelService.readHeadMeta("testing")).thenAnswer((_) async => 
        Some(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );
      when(
        () => mockChannelService.readGenerationResources("testing"),
      ).thenAnswer((_) async => Some(_generationResources(serverId: "tq", snapshotHash: "old_snapshot_hash")));
      when(() => mockRemoteCatalogService.fetchHeadMeta("testing")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );

      final service = makeService();
      final result = await service.checkForCheckout("checkout-1");

      expect(result, isA<DataUpdateCheckResultUpToDate>());
      expect((result as DataUpdateCheckResultUpToDate).currentGenerationHash, testLocalHash);
    });

    test("returns available when remote hash differs", () async {
      stubRegistry({"checkout-1": testEntry()});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer((_) async => testLocalHash);
      when(() => mockChannelService.readHeadMeta("testing")).thenAnswer((_) async => 
        Some(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );
      when(() => mockRemoteCatalogService.fetchHeadMeta("testing")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testRemoteHash,
            updatedAt: "2026-06-18T12:00:00Z",
            label: IMap(const {"en": "Newer"}),
          ),
        ),
      );
      when(() => mockRemoteCatalogService.fetchGenerationResources(testRemoteHash)).thenAnswer(
        (_) async =>
            Right(_generationResourcesBytes(serverId: "tq", snapshotHash: "new_snapshot_hash")),
      );

      final service = makeService();
      final result = await service.checkForCheckout("checkout-1");

      expect(result, isA<DataUpdateCheckResultAvailable>());
      final avail = result as DataUpdateCheckResultAvailable;
      expect(avail.currentGenerationHash, testLocalHash);
      expect(avail.newGenerationHash, testRemoteHash);
    });

    test("returns available when generation matches but snapshot differs", () async {
      stubRegistry({"checkout-1": testEntry()});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer((_) async => testLocalHash);
      when(() => mockChannelService.readHeadMeta("testing")).thenAnswer((_) async => 
        Some(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );
      when(
        () => mockChannelService.readGenerationResources("testing"),
      ).thenAnswer((_) async => Some(_generationResources(serverId: "tq", snapshotHash: "new_snapshot_hash")));
      when(() => mockRemoteCatalogService.fetchHeadMeta("testing")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );

      final service = makeService();
      final result = await service.checkForCheckout("checkout-1");

      expect(result, isA<DataUpdateCheckResultAvailable>());
      final avail = result as DataUpdateCheckResultAvailable;
      expect(avail.currentGenerationHash, testLocalHash);
      expect(avail.newGenerationHash, testLocalHash);
    });

    test("returns failed when server is missing from generation resources", () async {
      stubRegistry({"checkout-1": testEntry()});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer((_) async => testLocalHash);
      when(() => mockChannelService.readHeadMeta("testing")).thenAnswer((_) async => 
        Some(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );
      when(() => mockChannelService.readGenerationResources("testing")).thenAnswer((_) async => 
        Some(_generationResources(serverId: "other", snapshotHash: "other_snapshot_hash")),
      );
      when(() => mockRemoteCatalogService.fetchHeadMeta("testing")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );

      final service = makeService();
      final result = await service.checkForCheckout("checkout-1");

      expect(result, isA<DataUpdateCheckResultFailed>());
      final failed = result as DataUpdateCheckResultFailed;
      expect(failed.message, "Server not found in latest generation");
      expect(failed.canRetry, isTrue);
    });
    test("returns failed when checkout is missing", () async {
      stubRegistry({});

      final service = makeService();
      final result = await service.checkForCheckout("missing-checkout");

      expect(result, isA<DataUpdateCheckResultFailed>());
      final failed = result as DataUpdateCheckResultFailed;
      expect(failed.message, "Checkout not found");
      expect(failed.canRetry, isFalse);
    });

    test("returns upToDate when no local head metadata exists", () async {
      stubRegistry({"checkout-1": testEntry()});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer((_) async => null);

      final service = makeService();
      final result = await service.checkForCheckout("checkout-1");

      expect(result, isA<DataUpdateCheckResultUpToDate>());
      expect((result as DataUpdateCheckResultUpToDate).currentGenerationHash, "");
    });

    test("returns failed with canRetry: true when remote head fetch fails", () async {
      stubRegistry({"checkout-1": testEntry()});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer((_) async => testLocalHash);
      when(() => mockChannelService.readHeadMeta("testing")).thenAnswer((_) async => 
        Some(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );
      when(
        () => mockRemoteCatalogService.fetchHeadMeta("testing"),
      ).thenAnswer((_) async => Left(const CatalogNetworkError(message: "connection refused")));

      final service = makeService();
      final result = await service.checkForCheckout("checkout-1");

      expect(result, isA<DataUpdateCheckResultFailed>());
      final failed = result as DataUpdateCheckResultFailed;
      expect(failed.message, contains("connection refused"));
      expect(failed.canRetry, isTrue);
    });
  });

  group("applyCheckoutUpdate", () {
    test("returns Left when checkout is missing", () async {
      stubRegistry({});

      final service = makeService();
      final result = await service.applyCheckoutUpdate("missing-checkout", onProgress: (_, _) {});

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), "Checkout not found");
    });

    test("returns Left when checkout service applyDataUpdate fails", () async {
      stubRegistry({"checkout-1": testEntry()});
      when(() => mockChannelService.localGenerationHash(any())).thenAnswer((_) async => null);
      when(
        () => mockCheckoutService.applyDataUpdate(
          checkoutId: any(named: "checkoutId"),
          channel: any(named: "channel"),
          channelName: any(named: "channelName"),
          targetSnapshotHash: any(named: "targetSnapshotHash"),
          onProgress: any(named: "onProgress"),
        ),
      ).thenAnswer((_) async => const Left("Failed to download changed files"));

      final service = makeService();
      final result = await service.applyCheckoutUpdate("checkout-1", onProgress: (_, _) {});

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), "Failed to download changed files");
    });

    test("prepares native directory and returns new snapshot hash on success", () async {
      stubRegistry({"checkout-1": testEntry()});
      when(() => mockChannelService.localGenerationHash(any())).thenAnswer((_) async => null);
      when(
        () => mockCheckoutService.applyDataUpdate(
          checkoutId: any(named: "checkoutId"),
          channel: any(named: "channel"),
          channelName: any(named: "channelName"),
          targetSnapshotHash: any(named: "targetSnapshotHash"),
          onProgress: any(named: "onProgress"),
        ),
      ).thenAnswer((_) async => Right("new_snapshot_hash"));

      final ri = ResourceIndex()
        ..schemaVersion = 1
        ..entries.add(
          ResourceIndex_Entry()
            ..resourceId = "resource://test/a.bin"
            ..contentHash = "hash_a"
            ..size = Int64(5),
        );
      when(() => mockAssetStore.readResourceIndex("new_snapshot_hash")).thenAnswer((_) async => Some(ri));

      final service = makeService();
      final result = await service.applyCheckoutUpdate("checkout-1", onProgress: (_, _) {});

      expect(result.isRight(), isTrue);
      expect(result.getRight().toNullable(), "new_snapshot_hash");
    });

    test("returns Left when resource index is missing after update", () async {
      stubRegistry({"checkout-1": testEntry()});
      when(() => mockChannelService.localGenerationHash(any())).thenAnswer((_) async => null);
      when(
        () => mockCheckoutService.applyDataUpdate(
          checkoutId: any(named: "checkoutId"),
          channel: any(named: "channel"),
          channelName: any(named: "channelName"),
          targetSnapshotHash: any(named: "targetSnapshotHash"),
          onProgress: any(named: "onProgress"),
        ),
      ).thenAnswer((_) async => Right("new_snapshot_hash"));
      when(
        () => mockAssetStore.readResourceIndex("new_snapshot_hash"),
      ).thenAnswer((_) async => const None());

      final service = makeService();
      final result = await service.applyCheckoutUpdate("checkout-1", onProgress: (_, _) {});

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), "Updated snapshot is missing its resource index");
    });
  });

  group("checkAllCheckouts", () {
    test("returns all upToDate when all checkouts are up to date", () async {
      stubRegistry({"checkout-1": testEntry(), "checkout-2": testEntry()});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer((_) async => testLocalHash);
      when(() => mockChannelService.readHeadMeta("testing")).thenAnswer((_) async => 
        Some(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );
      when(
        () => mockChannelService.readGenerationResources("testing"),
      ).thenAnswer((_) async => Some(_generationResources(serverId: "tq", snapshotHash: "old_snapshot_hash")));
      when(() => mockRemoteCatalogService.fetchHeadMeta("testing")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );

      final service = makeService();
      final results = await service.checkAllCheckouts();

      expect(results.length, 2);
      expect(results["checkout-1"], isA<DataUpdateCheckResultUpToDate>());
      expect(results["checkout-2"], isA<DataUpdateCheckResultUpToDate>());
    });

    test("shares one head and generation-resources fetch per channel", () async {
      stubRegistry({"checkout-1": testEntry(), "checkout-2": testEntry()});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer((_) async => testLocalHash);
      when(() => mockChannelService.readHeadMeta("testing")).thenAnswer((_) async => 
        Some(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );
      when(() => mockRemoteCatalogService.fetchHeadMeta("testing")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testRemoteHash,
            updatedAt: "2026-06-18T12:00:00Z",
            label: IMap(const {"en": "Newer"}),
          ),
        ),
      );
      when(() => mockRemoteCatalogService.fetchGenerationResources(testRemoteHash)).thenAnswer(
        (_) async =>
            Right(_generationResourcesBytes(serverId: "tq", snapshotHash: "new_snapshot_hash")),
      );

      final service = makeService();
      final results = await service.checkAllCheckouts();

      expect(results.length, 2);
      expect(results["checkout-1"], isA<DataUpdateCheckResultAvailable>());
      expect(results["checkout-2"], isA<DataUpdateCheckResultAvailable>());
      verify(() => mockRemoteCatalogService.fetchHeadMeta("testing")).called(1);
      verify(() => mockRemoteCatalogService.fetchGenerationResources(testRemoteHash)).called(1);
    });

    test("groups checkouts by channel", () async {
      stubRegistry({"checkout-1": testEntry(), "checkout-2": testEntry(channel: "stable")});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer((_) async => testLocalHash);
      when(() => mockChannelService.localGenerationHash("stable")).thenAnswer((_) async => testLocalHash);
      when(() => mockChannelService.readHeadMeta("testing")).thenAnswer((_) async => 
        Some(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );
      when(() => mockChannelService.readHeadMeta("stable")).thenAnswer((_) async => 
        Some(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Stable"}),
          ),
        ),
      );
      when(() => mockRemoteCatalogService.fetchHeadMeta("testing")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testRemoteHash,
            updatedAt: "2026-06-18T12:00:00Z",
            label: IMap(const {"en": "Newer"}),
          ),
        ),
      );
      when(() => mockRemoteCatalogService.fetchHeadMeta("stable")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Stable"}),
          ),
        ),
      );
      when(() => mockRemoteCatalogService.fetchGenerationResources(testRemoteHash)).thenAnswer(
        (_) async =>
            Right(_generationResourcesBytes(serverId: "tq", snapshotHash: "new_snapshot_hash")),
      );
      when(
        () => mockChannelService.readGenerationResources("stable"),
      ).thenAnswer((_) async => Some(_generationResources(serverId: "tq", snapshotHash: "old_snapshot_hash")));

      final service = makeService();
      final results = await service.checkAllCheckouts();

      expect(results["checkout-1"], isA<DataUpdateCheckResultAvailable>());
      expect(results["checkout-2"], isA<DataUpdateCheckResultUpToDate>());
      verify(() => mockRemoteCatalogService.fetchHeadMeta("testing")).called(1);
      verify(() => mockRemoteCatalogService.fetchHeadMeta("stable")).called(1);
      verify(() => mockRemoteCatalogService.fetchGenerationResources(testRemoteHash)).called(1);
    });

    test("returns all available when all checkouts have updates", () async {
      stubRegistry({"checkout-1": testEntry(), "checkout-2": testEntry()});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer((_) async => testLocalHash);
      when(() => mockChannelService.readHeadMeta("testing")).thenAnswer((_) async => 
        Some(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );
      when(() => mockRemoteCatalogService.fetchHeadMeta("testing")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testRemoteHash,
            updatedAt: "2026-06-18T12:00:00Z",
            label: IMap(const {"en": "Newer"}),
          ),
        ),
      );
      when(() => mockRemoteCatalogService.fetchGenerationResources(testRemoteHash)).thenAnswer(
        (_) async =>
            Right(_generationResourcesBytes(serverId: "tq", snapshotHash: "new_snapshot_hash")),
      );

      final service = makeService();
      final results = await service.checkAllCheckouts();

      expect(results.length, 2);
      expect(results["checkout-1"], isA<DataUpdateCheckResultAvailable>());
      expect(results["checkout-2"], isA<DataUpdateCheckResultAvailable>());
    });

    test("only iterates registered checkouts", () async {
      stubRegistry({"checkout-1": testEntry()});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer(
        (_) async => null,
      );

      final service = makeService();
      final results = await service.checkAllCheckouts();

      expect(results["checkout-1"], isA<DataUpdateCheckResultUpToDate>());
      expect(results["missing-checkout"], isNull);
    });
  });

  group("applyAllCheckouts", () {
    test("updates all available checkouts", () async {
      stubRegistry({"checkout-1": testEntry(), "checkout-2": testEntry()});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer((_) async => testLocalHash);
      when(() => mockChannelService.readHeadMeta("testing")).thenAnswer((_) async => 
        Some(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );
      when(() => mockRemoteCatalogService.fetchHeadMeta("testing")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testRemoteHash,
            updatedAt: "2026-06-18T12:00:00Z",
            label: IMap(const {"en": "Newer"}),
          ),
        ),
      );
      when(() => mockRemoteCatalogService.fetchGenerationResources(testRemoteHash)).thenAnswer(
        (_) async =>
            Right(_generationResourcesBytes(serverId: "tq", snapshotHash: "new_snapshot_hash")),
      );
      when(
        () => mockCheckoutService.applyDataUpdate(
          checkoutId: any(named: "checkoutId"),
          channel: any(named: "channel"),
          channelName: any(named: "channelName"),
          targetSnapshotHash: any(named: "targetSnapshotHash"),
          onProgress: any(named: "onProgress"),
        ),
      ).thenAnswer((_) async => Right("new_snapshot_hash"));

      final ri = ResourceIndex()
        ..schemaVersion = 1
        ..entries.add(
          ResourceIndex_Entry()
            ..resourceId = "resource://test/a.bin"
            ..contentHash = "hash_a"
            ..size = Int64(5),
        );
      when(() => mockAssetStore.readResourceIndex("new_snapshot_hash")).thenAnswer((_) async => Some(ri));
      when(() => mockRepoService.pruneAsync()).thenAnswer((_) async => 0);

      final service = makeService();
      final progressCalls = <BatchUpdateProgress>[];
      final result = await service.applyAllCheckouts(onProgress: progressCalls.add);

      expect(result.successes, containsAll(["checkout-1", "checkout-2"]));
      expect(result.failures, isEmpty);
      expect(result.skipped, isEmpty);
      expect(progressCalls, isNotEmpty);
      verify(() => mockRepoService.pruneAsync()).called(1);
    });

    test("continues on failure and reports summary", () async {
      stubRegistry({"checkout-1": testEntry(), "checkout-2": testEntry()});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer((_) async => testLocalHash);
      when(() => mockChannelService.readHeadMeta("testing")).thenAnswer((_) async => 
        Some(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );
      when(() => mockRemoteCatalogService.fetchHeadMeta("testing")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testRemoteHash,
            updatedAt: "2026-06-18T12:00:00Z",
            label: IMap(const {"en": "Newer"}),
          ),
        ),
      );
      when(() => mockRemoteCatalogService.fetchGenerationResources(testRemoteHash)).thenAnswer(
        (_) async =>
            Right(_generationResourcesBytes(serverId: "tq", snapshotHash: "new_snapshot_hash")),
      );
      when(
        () => mockCheckoutService.applyDataUpdate(
          checkoutId: any(named: "checkoutId"),
          channel: any(named: "channel"),
          channelName: any(named: "channelName"),
          targetSnapshotHash: any(named: "targetSnapshotHash"),
          onProgress: any(named: "onProgress"),
        ),
      ).thenAnswer((invocation) async {
        final checkoutId = invocation.namedArguments[#checkoutId] as String;
        if (checkoutId == "checkout-1") {
          return const Left("Network error");
        }
        return Right("new_snapshot_hash");
      });

      final ri = ResourceIndex()
        ..schemaVersion = 1
        ..entries.add(
          ResourceIndex_Entry()
            ..resourceId = "resource://test/a.bin"
            ..contentHash = "hash_a"
            ..size = Int64(5),
        );
      when(() => mockAssetStore.readResourceIndex("new_snapshot_hash")).thenAnswer((_) async => Some(ri));
      when(() => mockRepoService.pruneAsync()).thenAnswer((_) async => 0);

      final service = makeService();
      final result = await service.applyAllCheckouts(onProgress: (_) {});

      expect(result.successes, ["checkout-2"]);
      expect(result.failures["checkout-1"], "Network error");
      expect(result.skipped, isEmpty);
    });

    test("skips up-to-date checkouts", () async {
      stubRegistry({"checkout-1": testEntry(), "checkout-2": testEntry()});
      when(() => mockChannelService.localGenerationHash("testing")).thenAnswer((_) async => testLocalHash);
      when(() => mockChannelService.readHeadMeta("testing")).thenAnswer((_) async => 
        Some(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );
      when(
        () => mockChannelService.readGenerationResources("testing"),
      ).thenAnswer((_) async => Some(_generationResources(serverId: "tq", snapshotHash: "old_snapshot_hash")));
      when(() => mockRemoteCatalogService.fetchHeadMeta("testing")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Test"}),
          ),
        ),
      );
      when(() => mockRepoService.pruneAsync()).thenAnswer((_) async => 0);

      final service = makeService();
      final result = await service.applyAllCheckouts(onProgress: (_) {});

      expect(result.successes, isEmpty);
      expect(result.failures, isEmpty);
      expect(result.skipped, containsAll(["checkout-1", "checkout-2"]));
    });
  });

  group("cadence tiers", () {
    const newHash = "snap_new";
    const oldHash = "snap_old";

    String ts(DateTime dt) => dt.toIso8601String();

    // Deterministic promoted timestamps around the current weekly boundary:
    // oldTs precedes it, newTs follows it.
    (String oldTs, String newTs) boundaryTimestamps() {
      final boundary = weekBoundaryUtc(DateTime.now().toUtc());
      return (ts(boundary.subtract(const Duration(days: 3))), ts(boundary.add(const Duration(hours: 1))));
    }

    ServerHistory historyFor(String oldTs, String newTs) => ServerHistory(
      schemaVersion: 1,
      servers: [
        ServerHistory_ServerEntry(
          serverId: "tq",
          snapshots: [
            ServerHistory_Snapshot(snapshotHash: newHash, timestamp: newTs),
            ServerHistory_Snapshot(snapshotHash: oldHash, timestamp: oldTs),
          ],
        ),
      ],
    );

    void stubStableChannel(ServerHistory history) {
      when(
        () => mockChannelService.localGenerationHash("stable"),
      ).thenAnswer((_) async => testLocalHash);
      when(() => mockRemoteCatalogService.fetchHeadMeta("stable")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Stable"}),
          ),
        ),
      );
      when(
        () => mockChannelService.readGenerationResources("stable"),
      ).thenAnswer((_) async => Some(_generationResources(serverId: "tq", snapshotHash: newHash)));
      when(
        () => mockChannelService.readServerHistory("stable"),
      ).thenAnswer((_) async => Some(history));
    }

    test("weekly lags behind the head", () async {
      final (oldTs, newTs) = boundaryTimestamps();
      stubStableChannel(historyFor(oldTs, newTs));
      stubRegistry({
        "checkout-1": CheckoutRegistryEntry(
          channel: "stable",
          serverId: "tq",
          resourceSnapshotHash: oldHash,
          name: IMap(const {"en": "Test"}),
          createdAt: oldTs,
          promotedAt: oldTs,
        ),
      });

      final result = await makeService(cadence: DataCadence.weekly).checkForCheckout("checkout-1");
      expect(result, isA<DataUpdateCheckResultUpToDate>());
    });

    test("immediate tracks the head", () async {
      final (oldTs, newTs) = boundaryTimestamps();
      stubStableChannel(historyFor(oldTs, newTs));
      stubRegistry({
        "checkout-1": CheckoutRegistryEntry(
          channel: "stable",
          serverId: "tq",
          resourceSnapshotHash: oldHash,
          name: IMap(const {"en": "Test"}),
          createdAt: oldTs,
          promotedAt: oldTs,
        ),
      });

      final result = await makeService().checkForCheckout("checkout-1");
      expect(result, isA<DataUpdateCheckResultAvailable>());
    });

    test("switching to a slower tier mid-cycle is a lag, not a rewind", () async {
      final (oldTs, newTs) = boundaryTimestamps();
      stubStableChannel(historyFor(oldTs, newTs));
      stubRegistry({
        "checkout-1": CheckoutRegistryEntry(
          channel: "stable",
          serverId: "tq",
          resourceSnapshotHash: newHash,
          name: IMap(const {"en": "Test"}),
          createdAt: newTs,
          promotedAt: newTs,
        ),
      });

      final result = await makeService(cadence: DataCadence.weekly).checkForCheckout("checkout-1");
      expect(result, isA<DataUpdateCheckResultUpToDate>());
    });

    test("unknown-age active hash re-binds to the resolved target", () async {
      final (oldTs, newTs) = boundaryTimestamps();
      stubStableChannel(historyFor(oldTs, newTs));
      stubRegistry({
        "checkout-1": CheckoutRegistryEntry(
          channel: "stable",
          serverId: "tq",
          resourceSnapshotHash: "elsewhere_hash",
          name: IMap(const {"en": "Test"}),
          createdAt: oldTs,
        ),
      });

      final result = await makeService(cadence: DataCadence.weekly).checkForCheckout("checkout-1");
      expect(result, isA<DataUpdateCheckResultAvailable>());
    });

    test("pre-cadence install on the head snapshot is up to date", () async {
      final (oldTs, newTs) = boundaryTimestamps();
      stubStableChannel(historyFor(oldTs, newTs));
      stubRegistry({
        "checkout-1": CheckoutRegistryEntry(
          channel: "stable",
          serverId: "tq",
          resourceSnapshotHash: newHash,
          name: IMap(const {"en": "Test"}),
          createdAt: newTs,
        ),
      });

      final result = await makeService(cadence: DataCadence.weekly).checkForCheckout("checkout-1");
      expect(result, isA<DataUpdateCheckResultUpToDate>());
    });

    test("cadence tier without promoted history fails retryably", () async {
      stubRegistry({"checkout-1": testEntry(channel: "stable")});
      when(
        () => mockChannelService.localGenerationHash("stable"),
      ).thenAnswer((_) async => testLocalHash);
      when(() => mockRemoteCatalogService.fetchHeadMeta("stable")).thenAnswer(
        (_) async => Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: testLocalHash,
            updatedAt: "2026-06-17T12:00:00Z",
            label: IMap(const {"en": "Stable"}),
          ),
        ),
      );
      when(
        () => mockChannelService.readGenerationResources("stable"),
      ).thenAnswer((_) async => Some(_generationResources(serverId: "tq", snapshotHash: newHash)));

      final result = await makeService(cadence: DataCadence.weekly).checkForCheckout("checkout-1");
      expect(result, isA<DataUpdateCheckResultFailed>());
      expect((result as DataUpdateCheckResultFailed).message, "Promoted history unavailable");
      expect(result.canRetry, isTrue);
    });
  });

  group("rebindCheckoutsToChannel", () {
    test("re-binds every checkout, keeping data and admission timestamps", () async {
      final registryService = CheckoutRegistryService.seeded(
        CheckoutRegistry(
          schemaVersion: 1,
          checkouts: IMap({
            "checkout-1": testEntry(),
            "checkout-2": testEntry(
              channel: "stable",
            ).copyWith(promotedAt: "2026-06-01T00:00:00Z"),
          }),
        ),
      );
      when(() => mockRepoService.checkoutRegistry).thenReturn(registryService);

      await makeService().rebindCheckoutsToChannel("stable");

      final registry = registryService.readRegistry().toNullable()!;
      expect(registry.checkouts["checkout-1"]!.channel, "stable");
      expect(registry.checkouts["checkout-1"]!.resourceSnapshotHash, "old_snapshot_hash");
      expect(registry.checkouts["checkout-2"]!.channel, "stable");
      expect(registry.checkouts["checkout-2"]!.promotedAt, "2026-06-01T00:00:00Z");
    });
  });
}
