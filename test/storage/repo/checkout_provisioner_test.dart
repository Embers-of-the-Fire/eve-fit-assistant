import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/data/proto/server_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/checkout_provisioner.dart";
import "package:eve_fit_assistant/storage/repo/checkout_registry_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/snapshot_meta.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

const _testGenerationHash = "gen-0000000000000000000000000000000000000000000000000000000000000001";
const _testSnapshotHash = "snap-0000000000000000000000000000000000000000000000000000000000000002";
const _testChannelName = "testing";
const _testServerId = "tranquility";

/// Test double for [RemoteCatalogService] that returns canned responses.
class _FakeRemoteCatalogService extends RemoteCatalogService {
  _FakeRemoteCatalogService({
    this.fetchResourceIndexResult,
    this.fetchResourceSnapshotMetaResult,
    this.fetchServerIndexResult,
    Map<(String, String), Either<CatalogError, Uint8List>>? blobResults,
  }) : _blobResults = blobResults ?? <(String, String), Either<CatalogError, Uint8List>>{},
       super(dio: Dio(), originUrl: "https://test.local");

  Either<CatalogError, Uint8List>? fetchResourceIndexResult;
  Either<CatalogError, ResourceSnapshotMeta>? fetchResourceSnapshotMetaResult;
  Either<CatalogError, Uint8List>? fetchServerIndexResult;
  final Map<(String, String), Either<CatalogError, Uint8List>> _blobResults;

  @override
  Future<Either<CatalogError, Uint8List>> fetchResourceIndex(String _) async =>
      fetchResourceIndexResult ?? Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, ResourceSnapshotMeta>> fetchResourceSnapshotMeta(String _) async =>
      fetchResourceSnapshotMetaResult ?? Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, Uint8List>> fetchServerIndex(String _) async =>
      fetchServerIndexResult ?? Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, Uint8List>> fetchBlob(String identHash, String contentHash) async =>
      _blobResults[(identHash, contentHash)] ??
      Left(const CatalogNetworkError(message: "blob not configured"));
}

extension on _FakeRemoteCatalogService {
  void setBlob(String identHash, String contentHash, Either<CatalogError, Uint8List> result) {
    _blobResults[(identHash, contentHash)] = result;
  }
}

/// Test double for [CheckoutService] whose [createCheckout] always returns [None].
class _FailingCheckoutService extends CheckoutService {
  _FailingCheckoutService()
    : super(
        assetStore: const AssetStore(),
        remoteCatalogService: _FakeRemoteCatalogService(),
        diffEngine: const DiffEngine(),
        checkoutRegistry: CheckoutRegistryService(),
      );

  @override
  Future<Option<String>> createCheckout({
    required Channel channel,
    required String serverId,
    required IMap<String, String> name,
    required String generationHash,
    required String resourceSnapshotHash,
  }) async => const None();
}

/// Builds a [ResourceIndex] protobuf from a list of (resourceId, contentHash, size) tuples.
ResourceIndex _buildResourceIndex(
  List<({String resourceId, String contentHash, int size})> entries,
) {
  final ri = ResourceIndex()..schemaVersion = 1;
  for (final e in entries) {
    ri.entries.add(
      ResourceIndex_Entry()
        ..resourceId = e.resourceId
        ..contentHash = e.contentHash
        ..size = Int64(e.size),
    );
  }
  return ri;
}

/// Builds a [ServerIndex] protobuf with one server entry.
ServerIndex _buildServerIndex(String serverId) {
  final si = ServerIndex()..schemaVersion = 1;
  si.servers.add(
    ServerIndex_Entry()
      ..serverId = serverId
      ..gameBuild = "21.0"
      ..gameVersion = "1.0"
      ..region = ""
      ..sync = ""
      ..branch = "",
  );
  return si;
}

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_provisioner_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  late String tempDir;
  late AssetStore assetStore;
  late CheckoutService checkoutService;
  late CheckoutRegistryService checkoutRegistry;
  late CheckoutProvisioner provisioner;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_provisioner_test_").path;
    PathProvider.documentsPath = tempDir;
    assetStore = const AssetStore();
    checkoutRegistry = CheckoutRegistryService();
    checkoutService = CheckoutService(
      assetStore: assetStore,
      remoteCatalogService: _FakeRemoteCatalogService(),
      diffEngine: const DiffEngine(),
      checkoutRegistry: checkoutRegistry,
    );
    provisioner = CheckoutProvisioner(
      remoteCatalog: _FakeRemoteCatalogService(),
      assetStore: assetStore,
      checkoutService: checkoutService,
    );
  });

  tearDown(() {
    provisioner.dispose();
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// Collects all states emitted by [provisioner] during [execute].
  Future<List<ProvisionerState>> collectStates(CheckoutProvisioner p) async {
    final states = <ProvisionerState>[];
    final sub = p.state.listen(states.add);
    await p.execute();
    await sub.cancel();
    return states;
  }

  group("Happy path", () {
    test("completes with checkoutId and resource snapshot on disk", () async {
      // Build known blobs
      const rid = "resource://test/ships.pb2";
      final blobBytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final contentHash = RepoHash.hashContent(blobBytes);
      final identHash = RepoHash.hashIdent(rid);
      final ri = _buildResourceIndex([(resourceId: rid, contentHash: contentHash, size: 4)]);
      final si = _buildServerIndex(_testServerId);

      final fakeRemote = _FakeRemoteCatalogService(
        fetchResourceIndexResult: Right(Uint8List.fromList(ri.writeToBuffer())),
        fetchResourceSnapshotMetaResult: Right(
          ResourceSnapshotMeta(
            schemaVersion: 1,
            serverId: _testServerId,
            gameBuild: "21.0",
            gameVersion: "1.0",
            resourceCount: 1,
            createdAt: "2026-06-15T12:00:00Z",
          ),
        ),
        fetchServerIndexResult: Right(Uint8List.fromList(si.writeToBuffer())),
      );
      fakeRemote.setBlob(identHash, contentHash, Right(blobBytes));

      final p = CheckoutProvisioner(
        remoteCatalog: fakeRemote,
        assetStore: assetStore,
        checkoutService: checkoutService,
      );

      p.configure(
        channel: Channel.testing,
        channelName: _testChannelName,
        serverId: _testServerId,
        name: IMap(const {"en": "Tranquility"}),
        generationHash: _testGenerationHash,
        resourceSnapshotHash: _testSnapshotHash,
      );

      final states = await collectStates(p);

      // Verify state sequence
      expect(states.length, greaterThanOrEqualTo(4));
      expect(states.first, isA<ProvisionerPreparing>());
      expect(states.any((s) => s is ProvisionerDownloading), isTrue);
      expect(states.any((s) => s is ProvisionerFinalizing), isTrue);
      expect(states.last, isA<ProvisionerComplete>());

      final complete = states.last as ProvisionerComplete;
      expect(complete.checkoutId, isNotEmpty);
      expect(complete.resourceSnapshotHash, isNotEmpty);
      expect(complete.failedBlobs, isEmpty);

      // Verify blob was written
      expect(assetStore.blobExistsSync(identHash, contentHash), isTrue);

      // Verify resource snapshot exists on disk
      final snapshotPath = RepoPaths.resourceSnapshotPath(complete.resourceSnapshotHash);
      expect(Directory(snapshotPath).existsSync(), isTrue);
      expect(File(RepoPaths.resourceIndexPath(complete.resourceSnapshotHash)).existsSync(), isTrue);

      // Verify checkout registry has the entry
      final registryOpt = checkoutRegistry.readRegistry();
      expect(registryOpt.isSome(), isTrue);
      final registry = registryOpt.toNullable()!;
      expect(registry.checkouts[complete.checkoutId], isNotNull);
      expect(registry.activeCheckoutId, complete.checkoutId);

      p.dispose();
    });

    test("emits final Preparing with cached and total counts", () async {
      const rid = "resource://test/cached.pb2";
      final blobBytes = Uint8List.fromList([0xAA, 0xBB]);
      final contentHash = RepoHash.hashContent(blobBytes);
      final identHash = RepoHash.hashIdent(rid);
      final ri = _buildResourceIndex([(resourceId: rid, contentHash: contentHash, size: 2)]);
      final si = _buildServerIndex(_testServerId);

      // Pre-write the blob so it counts as cached
      assetStore.writeBlobSync(identHash, blobBytes);

      final fakeRemote = _FakeRemoteCatalogService(
        fetchResourceIndexResult: Right(Uint8List.fromList(ri.writeToBuffer())),
        fetchResourceSnapshotMetaResult: Right(
          ResourceSnapshotMeta(
            schemaVersion: 1,
            serverId: _testServerId,
            gameBuild: "21.0",
            gameVersion: "1.0",
            resourceCount: 1,
            createdAt: "2026-06-15T12:00:00Z",
          ),
        ),
        fetchServerIndexResult: Right(Uint8List.fromList(si.writeToBuffer())),
      );

      final p = CheckoutProvisioner(
        remoteCatalog: fakeRemote,
        assetStore: assetStore,
        checkoutService: checkoutService,
      );

      p.configure(
        channel: Channel.testing,
        channelName: _testChannelName,
        serverId: _testServerId,
        name: IMap(const {"en": "Tranquility"}),
        generationHash: _testGenerationHash,
        resourceSnapshotHash: _testSnapshotHash,
      );

      final states = await collectStates(p);

      final preparingStates = states.whereType<ProvisionerPreparing>().toList();
      // The last Preparing state (emitted after cache scan) should have counts
      final last = preparingStates.last;
      expect(last.totalBlobs, 1);
      expect(last.cachedBlobs, 1);

      // Progress should start at 100% since all blobs are cached
      final downloadingStates = states.whereType<ProvisionerDownloading>().toList();
      expect(downloadingStates.isNotEmpty, isTrue);
      expect(downloadingStates.last.progress, 1.0);

      p.dispose();
    });

    test("tracks per-blob download failures in Complete", () async {
      const ridGood = "resource://test/good.bin";
      const ridBad = "resource://test/bad.bin";
      final goodBytes = Uint8List.fromList([0x01, 0x02]);
      final goodCH = RepoHash.hashContent(goodBytes);
      final goodIH = RepoHash.hashIdent(ridGood);
      final badIH = RepoHash.hashIdent(ridBad);
      const badCH = "sha256:deadbeef00000000000000000000000000000000000000000000000000000000";

      final ri = _buildResourceIndex([
        (resourceId: ridGood, contentHash: goodCH, size: 2),
        (resourceId: ridBad, contentHash: badCH, size: 8),
      ]);
      final si = _buildServerIndex(_testServerId);

      final fakeRemote = _FakeRemoteCatalogService(
        fetchResourceIndexResult: Right(Uint8List.fromList(ri.writeToBuffer())),
        fetchResourceSnapshotMetaResult: Right(
          ResourceSnapshotMeta(
            schemaVersion: 1,
            serverId: _testServerId,
            gameBuild: "21.0",
            gameVersion: "1.0",
            resourceCount: 2,
            createdAt: "2026-06-15T12:00:00Z",
          ),
        ),
        fetchServerIndexResult: Right(Uint8List.fromList(si.writeToBuffer())),
      );
      fakeRemote.setBlob(goodIH, goodCH, Right(goodBytes));
      fakeRemote.setBlob(badIH, badCH, Left(const CatalogNetworkError(message: "timeout")));

      final p = CheckoutProvisioner(
        remoteCatalog: fakeRemote,
        assetStore: assetStore,
        checkoutService: checkoutService,
      );

      p.configure(
        channel: Channel.testing,
        channelName: _testChannelName,
        serverId: _testServerId,
        name: IMap(const {"en": "Tranquility"}),
        generationHash: _testGenerationHash,
        resourceSnapshotHash: _testSnapshotHash,
      );

      final states = await collectStates(p);

      expect(states.last, isA<ProvisionerComplete>());
      final complete = states.last as ProvisionerComplete;
      expect(complete.failedBlobs.length, 1);
      expect(complete.failedBlobs.first, ridBad);

      // Downloading states should reflect failed count
      final downloadingStates = states.whereType<ProvisionerDownloading>().toList();
      expect(downloadingStates.last.failedCount, 1);

      p.dispose();
    });
  });

  group("Error states", () {
    test("emits Fatal(retryable: true) on resource index network error", () async {
      final fakeRemote = _FakeRemoteCatalogService(
        fetchResourceIndexResult: Left(const CatalogNetworkError(message: "connection refused")),
      );

      final p = CheckoutProvisioner(
        remoteCatalog: fakeRemote,
        assetStore: assetStore,
        checkoutService: checkoutService,
      );

      p.configure(
        channel: Channel.testing,
        channelName: _testChannelName,
        serverId: _testServerId,
        name: IMap(const {"en": "Tranquility"}),
        generationHash: _testGenerationHash,
        resourceSnapshotHash: _testSnapshotHash,
      );

      final states = await collectStates(p);

      expect(states.last, isA<ProvisionerFatal>());
      final fatal = states.last as ProvisionerFatal;
      expect(fatal.retryable, isTrue);
      expect(fatal.message, contains("connection refused"));

      p.dispose();
    });

    test("emits Fatal(retryable: false) on parse error fetching index", () async {
      final fakeRemote = _FakeRemoteCatalogService(
        fetchResourceIndexResult: Left(const CatalogParseError(message: "invalid protobuf")),
      );

      final p = CheckoutProvisioner(
        remoteCatalog: fakeRemote,
        assetStore: assetStore,
        checkoutService: checkoutService,
      );

      p.configure(
        channel: Channel.testing,
        channelName: _testChannelName,
        serverId: _testServerId,
        name: IMap(const {"en": "Tranquility"}),
        generationHash: _testGenerationHash,
        resourceSnapshotHash: _testSnapshotHash,
      );

      final states = await collectStates(p);

      expect(states.last, isA<ProvisionerFatal>());
      final fatal = states.last as ProvisionerFatal;
      expect(fatal.retryable, isFalse);
      expect(fatal.message, contains("Failed to fetch resource index"));

      p.dispose();
    });

    test("emits Fatal when checkout creation fails", () async {
      const rid = "resource://test/ships.pb2";
      final blobBytes = Uint8List.fromList([0x01]);
      final contentHash = RepoHash.hashContent(blobBytes);
      final identHash = RepoHash.hashIdent(rid);
      final ri = _buildResourceIndex([(resourceId: rid, contentHash: contentHash, size: 1)]);
      final si = _buildServerIndex(_testServerId);

      final fakeRemote = _FakeRemoteCatalogService(
        fetchResourceIndexResult: Right(Uint8List.fromList(ri.writeToBuffer())),
        fetchResourceSnapshotMetaResult: Right(
          ResourceSnapshotMeta(
            schemaVersion: 1,
            serverId: _testServerId,
            gameBuild: "21.0",
            gameVersion: "1.0",
            resourceCount: 1,
            createdAt: "2026-06-15T12:00:00Z",
          ),
        ),
        fetchServerIndexResult: Right(Uint8List.fromList(si.writeToBuffer())),
      );
      fakeRemote.setBlob(identHash, contentHash, Right(blobBytes));

      final failingCheckoutService = _FailingCheckoutService();

      final p = CheckoutProvisioner(
        remoteCatalog: fakeRemote,
        assetStore: assetStore,
        checkoutService: failingCheckoutService,
      );

      p.configure(
        channel: Channel.testing,
        channelName: _testChannelName,
        serverId: _testServerId,
        name: IMap(const {"en": "Tranquility"}),
        generationHash: _testGenerationHash,
        resourceSnapshotHash: _testSnapshotHash,
      );

      final states = await collectStates(p);

      expect(states.last, isA<ProvisionerFatal>());
      final fatal = states.last as ProvisionerFatal;
      expect(fatal.retryable, isFalse);
      expect(fatal.message, contains("Failed to create checkout"));

      p.dispose();
    });

    test("emits Fatal when not configured", () async {
      final fakeRemote = _FakeRemoteCatalogService();

      final p = CheckoutProvisioner(
        remoteCatalog: fakeRemote,
        assetStore: assetStore,
        checkoutService: checkoutService,
      );

      // execute without configure
      final states = await collectStates(p);

      expect(states.length, 1);
      expect(states.first, isA<ProvisionerFatal>());
      final fatal = states.first as ProvisionerFatal;
      expect(fatal.message, "Provisioner not configured");

      p.dispose();
    });
  });

  group("Cancellation", () {
    test("cancel stops the pipeline before creating checkout", () async {
      const rid = "resource://test/ships.pb2";
      final blobBytes = Uint8List.fromList([0x01, 0x02, 0x03]);
      final contentHash = RepoHash.hashContent(blobBytes);
      final identHash = RepoHash.hashIdent(rid);
      final ri = _buildResourceIndex([(resourceId: rid, contentHash: contentHash, size: 3)]);
      final si = _buildServerIndex(_testServerId);

      final fakeRemote = _FakeRemoteCatalogService(
        fetchResourceIndexResult: Right(Uint8List.fromList(ri.writeToBuffer())),
        fetchResourceSnapshotMetaResult: Right(
          ResourceSnapshotMeta(
            schemaVersion: 1,
            serverId: _testServerId,
            gameBuild: "21.0",
            gameVersion: "1.0",
            resourceCount: 1,
            createdAt: "2026-06-15T12:00:00Z",
          ),
        ),
        fetchServerIndexResult: Right(Uint8List.fromList(si.writeToBuffer())),
      );
      fakeRemote.setBlob(identHash, contentHash, Right(blobBytes));

      final p = CheckoutProvisioner(
        remoteCatalog: fakeRemote,
        assetStore: assetStore,
        checkoutService: checkoutService,
      );

      p.configure(
        channel: Channel.testing,
        channelName: _testChannelName,
        serverId: _testServerId,
        name: IMap(const {"en": "Tranquility"}),
        generationHash: _testGenerationHash,
        resourceSnapshotHash: _testSnapshotHash,
      );

      final states = <ProvisionerState>[];
      final sub = p.state.listen((s) {
        states.add(s);
        // Cancel after first Downloading state
        if (s is ProvisionerDownloading) {
          p.cancel();
        }
      });

      await p.execute();
      await sub.cancel();

      // Should NOT have a Complete state
      expect(states.any((s) => s is ProvisionerComplete), isFalse);
      expect(states.any((s) => s is ProvisionerFinalizing), isFalse);

      // Registry should be empty (no partial checkout)
      final registryOpt = checkoutRegistry.readRegistry();
      if (registryOpt.isSome()) {
        final r = registryOpt.toNullable()!;
        expect(r.checkouts.isEmpty || r.activeCheckoutId == null, isTrue);
      }

      p.dispose();
    });
  });

  group("Progress values", () {
    test("progress is monotonically increasing and ends at 1.0", () async {
      const rids = [
        "resource://test/a.bin",
        "resource://test/b.bin",
        "resource://test/c.bin",
        "resource://test/d.bin",
        "resource://test/e.bin",
      ];
      final blobs = <String, ({String contentHash, Uint8List bytes})>{};
      final entries = <({String resourceId, String contentHash, int size})>[];
      for (final rid in rids) {
        final bytes = Uint8List(10)..[0] = rid.hashCode & 0xFF;
        final ch = RepoHash.hashContent(bytes);
        final ih = RepoHash.hashIdent(rid);
        blobs[ih] = (contentHash: ch, bytes: bytes);
        entries.add((resourceId: rid, contentHash: ch, size: 10));
      }
      final ri = _buildResourceIndex(entries);
      final si = _buildServerIndex(_testServerId);

      final fakeRemote = _FakeRemoteCatalogService(
        fetchResourceIndexResult: Right(Uint8List.fromList(ri.writeToBuffer())),
        fetchResourceSnapshotMetaResult: Right(
          ResourceSnapshotMeta(
            schemaVersion: 1,
            serverId: _testServerId,
            gameBuild: "21.0",
            gameVersion: "1.0",
            resourceCount: rids.length,
            createdAt: "2026-06-15T12:00:00Z",
          ),
        ),
        fetchServerIndexResult: Right(Uint8List.fromList(si.writeToBuffer())),
      );
      for (final entry in blobs.entries) {
        fakeRemote.setBlob(entry.key, entry.value.contentHash, Right(entry.value.bytes));
      }

      final p = CheckoutProvisioner(
        remoteCatalog: fakeRemote,
        assetStore: assetStore,
        checkoutService: checkoutService,
      );

      p.configure(
        channel: Channel.testing,
        channelName: _testChannelName,
        serverId: _testServerId,
        name: IMap(const {"en": "Tranquility"}),
        generationHash: _testGenerationHash,
        resourceSnapshotHash: _testSnapshotHash,
      );

      final states = await collectStates(p);

      final downloadingStates = states.whereType<ProvisionerDownloading>().toList();
      expect(downloadingStates.isNotEmpty, isTrue);

      var lastProgress = -1.0;
      for (final ds in downloadingStates) {
        expect(ds.progress, greaterThanOrEqualTo(lastProgress));
        expect(ds.progress, lessThanOrEqualTo(1.0));
        lastProgress = ds.progress;
      }
      expect(lastProgress, 1.0);

      p.dispose();
    });
  });

  group("Default snapshot meta", () {
    test("writes fallback metadata when remote fetch fails", () async {
      const rid = "resource://test/fallback.bin";
      final blobBytes = Uint8List.fromList([0xFF]);
      final contentHash = RepoHash.hashContent(blobBytes);
      final identHash = RepoHash.hashIdent(rid);
      final ri = _buildResourceIndex([(resourceId: rid, contentHash: contentHash, size: 1)]);
      final si = _buildServerIndex(_testServerId);

      final fakeRemote = _FakeRemoteCatalogService(
        fetchResourceIndexResult: Right(Uint8List.fromList(ri.writeToBuffer())),
        // meta fetch fails
        fetchResourceSnapshotMetaResult: Left(
          const CatalogNetworkError(message: "metadata unavailable"),
        ),
        fetchServerIndexResult: Right(Uint8List.fromList(si.writeToBuffer())),
      );
      fakeRemote.setBlob(identHash, contentHash, Right(blobBytes));

      final p = CheckoutProvisioner(
        remoteCatalog: fakeRemote,
        assetStore: assetStore,
        checkoutService: checkoutService,
      );

      p.configure(
        channel: Channel.testing,
        channelName: _testChannelName,
        serverId: _testServerId,
        name: IMap(const {"en": "Tranquility"}),
        generationHash: _testGenerationHash,
        resourceSnapshotHash: _testSnapshotHash,
      );

      final states = await collectStates(p);

      expect(states.last, isA<ProvisionerComplete>());
      final complete = states.last as ProvisionerComplete;
      expect(complete.resourceSnapshotHash, isNotEmpty);

      // Verify snapshot exists with fallback metadata
      final metaPath = RepoPaths.resourceSnapshotMetaPath(complete.resourceSnapshotHash);
      expect(File(metaPath).existsSync(), isTrue);
      final metaJson = jsonDecode(File(metaPath).readAsStringSync()) as Map<String, dynamic>;
      expect(metaJson["serverId"], _testServerId);
      expect(metaJson["gameBuild"], "");

      p.dispose();
    });
  });
}
