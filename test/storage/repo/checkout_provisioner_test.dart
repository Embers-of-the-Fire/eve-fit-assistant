import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart" show PathProvider;
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/data/proto/server_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/checkout_provisioner.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/blob_ident.dart";
import "package:eve_fit_assistant/storage/repo/models/snapshot_meta.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

const _testGenerationHash = "gen-0000000000000000000000000000000000000000000000000000000000000001";
const _testSnapshotHash = "snap-0000000000000000000000000000000000000000000000000000000000000002";
const _testChannelName = "testing";
const _testServerId = "tranquility";

// ── Test doubles ─────────────────────────────────────────────────────────────

class MockRemoteCatalogService extends Mock implements RemoteCatalogService {}

class MockCheckoutService extends Mock implements CheckoutService {}

/// Returns a [CheckoutService] whose [createCheckout] returns [createResult]
/// or `Some("checkout-default")` by default.
CheckoutService _testCheckoutService({Option<String>? createResult}) {
  final mock = MockCheckoutService();
  when(
    () => mock.createCheckout(
      channel: any(named: "channel"),
      serverId: any(named: "serverId"),
      name: any(named: "name"),
      generationHash: any(named: "generationHash"),
      resourceSnapshotHash: any(named: "resourceSnapshotHash"),
    ),
  ).thenAnswer((_) async => createResult ?? Some("checkout-default"));
  return mock;
}

/// In-memory asset store that records blobs without touching the real
/// filesystem. Each test gets a fresh instance.
class _FakeAssetStore implements AssetStore {
  final _blobs = <String, Uint8List>{};

  @override
  ({String identHash, String contentHash}) writeBlobSync(String identHash, Uint8List content) {
    final contentHash = RepoHash.hashContent(content);
    _blobs[identHash] = content;
    return (identHash: identHash, contentHash: contentHash);
  }

  @override
  ({String identHash, String contentHash}) writeBlobByIdentSync(
    BlobIdent ident,
    Uint8List content,
  ) => writeBlobSync(ident.identHash, content);

  @override
  bool blobExistsSync(String identHash, String contentHash) => _blobs.containsKey(identHash);

  @override
  void deleteBlobSync(String identHash, String contentHash) {
    _blobs.remove(identHash);
  }

  @override
  String writeResourceSnapshotSync({
    required ResourceSnapshotMeta meta,
    required ResourceIndex resourceIndex,
  }) {
    return "snap-${meta.serverId}";
  }

  @override
  Option<Uint8List> readBlobSync(String identHash, String contentHash) =>
      Option.fromNullable(_blobs[identHash]);

  @override
  Option<ResourceIndex> readResourceIndexSync(String snapshotHash) => const None();

  @override
  Option<ResourceSnapshotMeta> readResourceSnapshotMetaSync(String snapshotHash) => const None();

  @override
  IList<String> verifyResourceIndexSync(ResourceIndex resourceIndex) => const IList.empty();

  @override
  int pruneSync({
    required Set<String> activeSnapshotHashes,
    required List<ResourceIndex> activeResourceIndexes,
  }) => 0;

  @override
  void recoverSync() {}

  @override
  Future<void> writeBlobUnchecked(String identHash, String contentHash, Uint8List content) async {
    _blobs[identHash] = content;
  }

  @override
  Future<void> writeBlobUncheckedAt(String assetPath, Uint8List content) async {
    // Extract identHash from the last path segment's parent directory.
    // Path format: .../blobs/{2c}/{identHash}/{contentHash}
    final parts = assetPath.split("/");
    if (parts.length >= 2) {
      _blobs[parts[parts.length - 2]] = content;
    }
  }

  @override
  void ensureBlobIdentDirs(Iterable<String> identHashes) {}
}

/// Builds a [ResourceIndex] protobuf from a list of (resourceId, contentHash,
/// size) tuples.
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

// ── Helpers ──────────────────────────────────────────────────────────────────

String? _logDirPath;

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_provisioner_test_log_");
    _logDirPath = logDir.path;
    GlobalLogger.init(logDir.path, enableDebugLog: false);
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(
      ResourceSnapshotMeta(
        schemaVersion: 1,
        serverId: "",
        gameBuild: "",
        gameVersion: "",
        resourceCount: 0,
        createdAt: "",
      ),
    );
    registerFallbackValue(ResourceIndex());
    registerFallbackValue(Channel.testing);
    registerFallbackValue(IMap(const <String, String>{}));
    registerFallbackValue(Uri.parse("http://localhost/"));
  });

  tearDownAll(() {
    if (_logDirPath != null) {
      Directory(_logDirPath!).deleteSync(recursive: true);
    }
  });

  late MockRemoteCatalogService mockRemoteCatalog;
  late _FakeAssetStore fakeAssetStore;
  late CheckoutProvisioner provisioner;

  /// Configures [provisioner] with the standard test parameters.
  void configureProvisioner() {
    provisioner.configure(
      channel: Channel.testing,
      channelName: _testChannelName,
      serverId: _testServerId,
      name: IMap(const {"en": "Tranquility"}),
      generationHash: _testGenerationHash,
      resourceSnapshotHash: _testSnapshotHash,
    );
  }

  late String tempDir;

  setUp(() {
    // _persistServerIndex accesses RepoPaths (and therefore
    // PathProvider.documentsPath) directly via dart:io.  Point it at a temp
    // dir so the Code doesn't crash even though no files are actually read.
    tempDir = Directory.systemTemp.createTempSync("efa_provisioner_test_").path;
    PathProvider.documentsPath = tempDir;

    mockRemoteCatalog = MockRemoteCatalogService();
    fakeAssetStore = _FakeAssetStore();

    // Stub fetchServerIndex to return Left so _persistServerIndex never
    // writes to the real filesystem.
    when(
      () => mockRemoteCatalog.fetchServerIndex(any()),
    ).thenAnswer((_) async => Left(CatalogNetworkError(message: "stubbed")));

    // Default blob stub — individual tests override with specific content.
    when(
      () => mockRemoteCatalog.fetchBlob(any(), any()),
    ).thenAnswer((_) async => Right(Uint8List.fromList([1, 2, 3, 4])));

    // Stub blobUri so pre-built URI construction works in the hot loop.
    when(() => mockRemoteCatalog.blobUri(any(), any())).thenAnswer(
      (inv) => Uri.parse(
        "http://test/efa/v2/assets/blobs/00/${inv.positionalArguments[0]}/${inv.positionalArguments[1]}",
      ),
    );

    provisioner = CheckoutProvisioner(
      remoteCatalog: mockRemoteCatalog,
      assetStore: fakeAssetStore,
      checkoutService: _testCheckoutService(),
    );
    addTearDown(provisioner.dispose);
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  /// Collects all states emitted by [provisioner] during [execute].
  Future<List<ProvisionerState>> collectStates() async {
    final states = <ProvisionerState>[];
    final sub = provisioner.state.listen(states.add);
    await provisioner.execute();
    await sub.cancel();
    return states;
  }

  group("Happy path", () {
    test("completes with checkoutId and resource snapshot on disk", () async {
      const rid = "resource://test/ships.pb2";
      final blobBytes = Uint8List.fromList([0x01, 0x02, 0x03, 0x04]);
      final contentHash = RepoHash.hashContent(blobBytes);
      final identHash = RepoHash.hashIdent(rid);
      final ri = _buildResourceIndex([(resourceId: rid, contentHash: contentHash, size: 4)]);
      final si = _buildServerIndex(_testServerId);

      provisioner = CheckoutProvisioner(
        remoteCatalog: mockRemoteCatalog,
        assetStore: fakeAssetStore,
        checkoutService: _testCheckoutService(createResult: Some("checkout-001")),
      );
      addTearDown(provisioner.dispose);

      when(
        () => mockRemoteCatalog.fetchResourceIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(ri.writeToBuffer())));
      when(() => mockRemoteCatalog.fetchResourceSnapshotMeta(any())).thenAnswer(
        (_) async => Right(
          ResourceSnapshotMeta(
            schemaVersion: 1,
            serverId: _testServerId,
            gameBuild: "21.0",
            gameVersion: "1.0",
            resourceCount: 1,
            createdAt: "2026-06-15T12:00:00Z",
          ),
        ),
      );
      when(
        () => mockRemoteCatalog.fetchServerIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(si.writeToBuffer())));
      when(
        () => mockRemoteCatalog.fetchBlob(identHash, contentHash),
      ).thenAnswer((_) async => Right(blobBytes));

      configureProvisioner();
      final states = await collectStates();

      expect(states.length, greaterThanOrEqualTo(4));
      expect(states.first, isA<ProvisionerPreparing>());
      expect(states.any((s) => s is ProvisionerDownloading), isTrue);
      expect(states.any((s) => s is ProvisionerFinalizing), isTrue);
      expect(states.last, isA<ProvisionerComplete>());

      final complete = states.last as ProvisionerComplete;
      expect(complete.checkoutId, "checkout-001");
      expect(complete.resourceSnapshotHash, isNotEmpty);
      expect(complete.failedBlobs, isEmpty);

      // Verify blob was stored in the fake store
      expect(fakeAssetStore.blobExistsSync(identHash, contentHash), isTrue);
    });

    test("emits final Preparing with cached and total counts", () async {
      const rid = "resource://test/cached.pb2";
      final blobBytes = Uint8List.fromList([0xAA, 0xBB]);
      final contentHash = RepoHash.hashContent(blobBytes);
      final identHash = RepoHash.hashIdent(rid);
      final ri = _buildResourceIndex([(resourceId: rid, contentHash: contentHash, size: 2)]);
      final si = _buildServerIndex(_testServerId);

      provisioner = CheckoutProvisioner(
        remoteCatalog: mockRemoteCatalog,
        assetStore: fakeAssetStore,
        checkoutService: _testCheckoutService(),
      );
      addTearDown(provisioner.dispose);

      // Pre-write the blob so it counts as cached
      fakeAssetStore.writeBlobSync(identHash, blobBytes);

      when(
        () => mockRemoteCatalog.fetchResourceIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(ri.writeToBuffer())));
      when(() => mockRemoteCatalog.fetchResourceSnapshotMeta(any())).thenAnswer(
        (_) async => Right(
          ResourceSnapshotMeta(
            schemaVersion: 1,
            serverId: _testServerId,
            gameBuild: "21.0",
            gameVersion: "1.0",
            resourceCount: 1,
            createdAt: "2026-06-15T12:00:00Z",
          ),
        ),
      );
      when(
        () => mockRemoteCatalog.fetchServerIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(si.writeToBuffer())));

      configureProvisioner();
      final states = await collectStates();

      final preparingStates = states.whereType<ProvisionerPreparing>().toList();
      final last = preparingStates.last;
      expect(last.totalBlobs, 1);
      expect(last.cachedBlobs, 1);

      final downloadingStates = states.whereType<ProvisionerDownloading>().toList();
      expect(downloadingStates.isNotEmpty, isTrue);
      expect(downloadingStates.last.progress, 1.0);

      verifyNever(() => mockRemoteCatalog.fetchBlob(any(), any()));
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

      provisioner = CheckoutProvisioner(
        remoteCatalog: mockRemoteCatalog,
        assetStore: fakeAssetStore,
        checkoutService: _testCheckoutService(),
      );
      addTearDown(provisioner.dispose);

      when(
        () => mockRemoteCatalog.fetchResourceIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(ri.writeToBuffer())));
      when(() => mockRemoteCatalog.fetchResourceSnapshotMeta(any())).thenAnswer(
        (_) async => Right(
          ResourceSnapshotMeta(
            schemaVersion: 1,
            serverId: _testServerId,
            gameBuild: "21.0",
            gameVersion: "1.0",
            resourceCount: 2,
            createdAt: "2026-06-15T12:00:00Z",
          ),
        ),
      );
      when(
        () => mockRemoteCatalog.fetchServerIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(si.writeToBuffer())));
      when(
        () => mockRemoteCatalog.fetchBlob(goodIH, goodCH),
      ).thenAnswer((_) async => Right(goodBytes));
      when(
        () => mockRemoteCatalog.fetchBlob(badIH, badCH),
      ).thenAnswer((_) async => Left(CatalogNetworkError(message: "timeout")));

      configureProvisioner();
      final states = await collectStates();

      expect(states.last, isA<ProvisionerComplete>());
      final complete = states.last as ProvisionerComplete;
      expect(complete.failedBlobs.length, 1);
      expect(complete.failedBlobs.first, ridBad);

      final downloadingStates = states.whereType<ProvisionerDownloading>().toList();
      expect(downloadingStates.last.failedCount, 1);
    });
  });

  group("Error states", () {
    test("emits Fatal(retryable: true) on resource index network error", () async {
      provisioner = CheckoutProvisioner(
        remoteCatalog: mockRemoteCatalog,
        assetStore: fakeAssetStore,
        checkoutService: _testCheckoutService(),
      );
      addTearDown(provisioner.dispose);

      when(
        () => mockRemoteCatalog.fetchResourceIndex(any()),
      ).thenAnswer((_) async => Left(CatalogNetworkError(message: "connection refused")));

      configureProvisioner();
      final states = await collectStates();

      expect(states.last, isA<ProvisionerFatal>());
      final fatal = states.last as ProvisionerFatal;
      expect(fatal.retryable, isTrue);
      expect(fatal.message, contains("connection refused"));
    });

    test("emits Fatal(retryable: false) on parse error fetching index", () async {
      provisioner = CheckoutProvisioner(
        remoteCatalog: mockRemoteCatalog,
        assetStore: fakeAssetStore,
        checkoutService: _testCheckoutService(),
      );
      addTearDown(provisioner.dispose);

      when(
        () => mockRemoteCatalog.fetchResourceIndex(any()),
      ).thenAnswer((_) async => Left(CatalogParseError(message: "invalid protobuf")));

      configureProvisioner();
      final states = await collectStates();

      expect(states.last, isA<ProvisionerFatal>());
      final fatal = states.last as ProvisionerFatal;
      expect(fatal.retryable, isFalse);
      expect(fatal.message, contains("Failed to fetch resource index"));
    });

    test("emits Fatal when checkout creation fails", () async {
      const rid = "resource://test/ships.pb2";
      final blobBytes = Uint8List.fromList([0x01]);
      final contentHash = RepoHash.hashContent(blobBytes);
      final identHash = RepoHash.hashIdent(rid);
      final ri = _buildResourceIndex([(resourceId: rid, contentHash: contentHash, size: 1)]);
      final si = _buildServerIndex(_testServerId);

      provisioner = CheckoutProvisioner(
        remoteCatalog: mockRemoteCatalog,
        assetStore: fakeAssetStore,
        checkoutService: _testCheckoutService(createResult: const None()),
      );
      addTearDown(provisioner.dispose);

      when(
        () => mockRemoteCatalog.fetchResourceIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(ri.writeToBuffer())));
      when(() => mockRemoteCatalog.fetchResourceSnapshotMeta(any())).thenAnswer(
        (_) async => Right(
          ResourceSnapshotMeta(
            schemaVersion: 1,
            serverId: _testServerId,
            gameBuild: "21.0",
            gameVersion: "1.0",
            resourceCount: 1,
            createdAt: "2026-06-15T12:00:00Z",
          ),
        ),
      );
      when(
        () => mockRemoteCatalog.fetchServerIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(si.writeToBuffer())));
      when(
        () => mockRemoteCatalog.fetchBlob(identHash, contentHash),
      ).thenAnswer((_) async => Right(blobBytes));

      configureProvisioner();
      final states = await collectStates();

      expect(states.last, isA<ProvisionerFatal>());
      final fatal = states.last as ProvisionerFatal;
      expect(fatal.retryable, isFalse);
      expect(fatal.message, contains("Failed to create checkout"));
    });

    test("emits Fatal when not configured", () async {
      provisioner = CheckoutProvisioner(
        remoteCatalog: mockRemoteCatalog,
        assetStore: fakeAssetStore,
        checkoutService: _testCheckoutService(),
      );
      addTearDown(provisioner.dispose);

      // execute without configure
      final states = await collectStates();

      expect(states.length, 1);
      expect(states.first, isA<ProvisionerFatal>());
      final fatal = states.first as ProvisionerFatal;
      expect(fatal.message, "Provisioner not configured");
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

      provisioner = CheckoutProvisioner(
        remoteCatalog: mockRemoteCatalog,
        assetStore: fakeAssetStore,
        checkoutService: _testCheckoutService(),
      );
      addTearDown(provisioner.dispose);

      when(
        () => mockRemoteCatalog.fetchResourceIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(ri.writeToBuffer())));
      when(() => mockRemoteCatalog.fetchResourceSnapshotMeta(any())).thenAnswer(
        (_) async => Right(
          ResourceSnapshotMeta(
            schemaVersion: 1,
            serverId: _testServerId,
            gameBuild: "21.0",
            gameVersion: "1.0",
            resourceCount: 1,
            createdAt: "2026-06-15T12:00:00Z",
          ),
        ),
      );
      when(
        () => mockRemoteCatalog.fetchServerIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(si.writeToBuffer())));
      when(
        () => mockRemoteCatalog.fetchBlob(identHash, contentHash),
      ).thenAnswer((_) async => Right(blobBytes));

      configureProvisioner();

      final states = <ProvisionerState>[];
      final sub = provisioner.state.listen((s) {
        states.add(s);
        if (s is ProvisionerDownloading) {
          provisioner.cancel();
        }
      });

      await provisioner.execute();
      await sub.cancel();

      expect(states.any((s) => s is ProvisionerComplete), isFalse);
      expect(states.any((s) => s is ProvisionerFinalizing), isFalse);

      // No checkout should be created
      // (verified implicitly since provisioner never calls checkoutService)
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

      provisioner = CheckoutProvisioner(
        remoteCatalog: mockRemoteCatalog,
        assetStore: fakeAssetStore,
        checkoutService: _testCheckoutService(),
      );
      addTearDown(provisioner.dispose);

      when(
        () => mockRemoteCatalog.fetchResourceIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(ri.writeToBuffer())));
      when(() => mockRemoteCatalog.fetchResourceSnapshotMeta(any())).thenAnswer(
        (_) async => Right(
          ResourceSnapshotMeta(
            schemaVersion: 1,
            serverId: _testServerId,
            gameBuild: "21.0",
            gameVersion: "1.0",
            resourceCount: rids.length,
            createdAt: "2026-06-15T12:00:00Z",
          ),
        ),
      );
      when(
        () => mockRemoteCatalog.fetchServerIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(si.writeToBuffer())));
      for (final entry in blobs.entries) {
        when(
          () => mockRemoteCatalog.fetchBlob(entry.key, entry.value.contentHash),
        ).thenAnswer((_) async => Right(entry.value.bytes));
      }

      configureProvisioner();
      final states = await collectStates();

      final downloadingStates = states.whereType<ProvisionerDownloading>().toList();
      expect(downloadingStates.isNotEmpty, isTrue);

      var lastProgress = -1.0;
      for (final ds in downloadingStates) {
        expect(ds.progress, greaterThanOrEqualTo(lastProgress));
        expect(ds.progress, lessThanOrEqualTo(1.0));
        lastProgress = ds.progress;
      }
      expect(lastProgress, 1.0);
    });
  });

  group("Snapshot metadata fetch", () {
    test("emits Fatal(retryable: true) when resource snapshot metadata fetch fails", () async {
      const rid = "resource://test/ships.pb2";
      final blobBytes = Uint8List.fromList([0x01]);
      final contentHash = RepoHash.hashContent(blobBytes);
      final identHash = RepoHash.hashIdent(rid);
      final ri = _buildResourceIndex([(resourceId: rid, contentHash: contentHash, size: 1)]);
      final si = _buildServerIndex(_testServerId);

      provisioner = CheckoutProvisioner(
        remoteCatalog: mockRemoteCatalog,
        assetStore: fakeAssetStore,
        checkoutService: _testCheckoutService(),
      );
      addTearDown(provisioner.dispose);

      when(
        () => mockRemoteCatalog.fetchResourceIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(ri.writeToBuffer())));
      when(
        () => mockRemoteCatalog.fetchResourceSnapshotMeta(any()),
      ).thenAnswer((_) async => const Left(CatalogNetworkError(message: "metadata timeout")));
      when(
        () => mockRemoteCatalog.fetchServerIndex(any()),
      ).thenAnswer((_) async => Right(Uint8List.fromList(si.writeToBuffer())));
      when(
        () => mockRemoteCatalog.fetchBlob(identHash, contentHash),
      ).thenAnswer((_) async => Right(blobBytes));

      configureProvisioner();
      final states = await collectStates();

      expect(states.last, isA<ProvisionerFatal>());
      final fatal = states.last as ProvisionerFatal;
      expect(fatal.retryable, isTrue);
      expect(fatal.message, contains("metadata timeout"));
    });
  });
}
