import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/checkout_reflog.pb.dart";
import "package:eve_fit_assistant/data/proto/generation_resources.pb.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/data/proto/server_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/checkout_registry_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_head_meta.dart";
import "package:eve_fit_assistant/storage/repo/models/snapshot_meta.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/utils.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

const _testServerId = "tranquility";
const _testChannelName = "testing";

const _testGenerationHashOld =
    "sha256:aaaa0000111122223333444455556666777788889999aaaabbbbccccddddeeeeffff";
const _testGenerationHashNew =
    "sha256:bbbb0000111122223333444455556666777788889999aaaabbbbccccddddeeeeffff";

class _TestSnapshot {
  _TestSnapshot({required this.hash, required this.meta, required this.resourceIndex});

  final String hash;
  final ResourceSnapshotMeta meta;
  final ResourceIndex resourceIndex;
}

class _FakeRemoteCatalogService extends RemoteCatalogService {
  _FakeRemoteCatalogService({
    this.headMetaResult,
    this.serverIndexResult,
    this.generationResourcesResult,
    this.resourceIndexResult,
    this.resourceSnapshotMetaResult,
  }) : super(dio: Dio(), originUrl: "https://test.local");

  Either<CatalogError, ChannelHeadMeta>? headMetaResult;
  Either<CatalogError, Uint8List>? serverIndexResult;
  Either<CatalogError, Uint8List>? generationResourcesResult;
  Either<CatalogError, Uint8List>? resourceIndexResult;
  Either<CatalogError, ResourceSnapshotMeta>? resourceSnapshotMetaResult;

  bool fetchGenerationResourcesCalled = false;
  String? lastFetchGenerationResourcesHash;

  @override
  Future<Either<CatalogError, ChannelHeadMeta>> fetchHeadMeta(
    String channelName, {
    Map<String, dynamic>? cachedPayload,
  }) async => headMetaResult ?? Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, Uint8List>> fetchServerIndex(String generationHash) async =>
      serverIndexResult ?? Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, Uint8List>> fetchGenerationResources(String generationHash) async {
    fetchGenerationResourcesCalled = true;
    lastFetchGenerationResourcesHash = generationHash;
    return generationResourcesResult ?? Left(const CatalogNetworkError(message: "not configured"));
  }

  @override
  Future<Either<CatalogError, Uint8List>> fetchResourceIndex(String snapshotHash) async =>
      resourceIndexResult ?? Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, ResourceSnapshotMeta>> fetchResourceSnapshotMeta(
    String snapshotHash, {
    Map<String, dynamic>? cachedPayload,
  }) async =>
      resourceSnapshotMetaResult ?? Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, Uint8List>> fetchBlob(String identHash, String contentHash) async =>
      Left(const CatalogNetworkError(message: "unexpected blob fetch"));
}

void main() {
  late String tempDir;
  late AssetStore assetStore;
  late CheckoutRegistryService checkoutRegistry;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_checkout_service_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_checkout_service_test_").path;
    PathProvider.documentsPath = tempDir;
    assetStore = const AssetStore();
    checkoutRegistry = CheckoutRegistryService();
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  CheckoutService _makeService(_FakeRemoteCatalogService fakeRemote) => CheckoutService(
    assetStore: assetStore,
    remoteCatalogService: fakeRemote,
    diffEngine: const DiffEngine(),
    checkoutRegistry: checkoutRegistry,
  );

  _TestSnapshot _makeSnapshot({required String createdAt}) {
    final blobContent = Uint8List.fromList([1, 2, 3, 4]);
    final ihash = RepoHash.hashIdent("resource://static/native/types.pb2");
    final blobResult = assetStore.writeBlobSync(ihash, blobContent);
    final resourceIndex = ResourceIndex(
      schemaVersion: 1,
      entries: [
        ResourceIndex_Entry(
          resourceId: "resource://static/native/types.pb2",
          contentHash: blobResult.contentHash,
          size: Int64(blobContent.length),
        ),
      ],
    );
    final meta = ResourceSnapshotMeta(
      schemaVersion: 1,
      serverId: _testServerId,
      gameBuild: "2026.06.15",
      gameVersion: "1.0",
      resourceCount: resourceIndex.entries.length,
      createdAt: createdAt,
    );
    final hash = assetStore.writeResourceSnapshotSync(meta: meta, resourceIndex: resourceIndex);
    return _TestSnapshot(hash: hash, meta: meta, resourceIndex: resourceIndex);
  }

  Future<String> _createCheckout(
    CheckoutService service, {
    required String snapshotHash,
    String generationHash = _testGenerationHashOld,
  }) async {
    final result = await service.createCheckout(
      channel: Channel.testing,
      serverId: _testServerId,
      name: IMap(const {"en": "Test Checkout"}),
      generationHash: generationHash,
      resourceSnapshotHash: snapshotHash,
    );
    expect(result.isSome(), isTrue);
    return result.toNullable()!;
  }

  ChannelHeadMeta _headMeta({required String generationHash}) => ChannelHeadMeta(
    schemaVersion: 1,
    generationHash: generationHash,
    updatedAt: "2026-06-16T12:00:00Z",
    label: IMap(const {"en": "Test Release"}),
  );

  void _writeChannelHead(String channelName, String generationHash) {
    final path = RepoPaths.channelHeadMetaPath(channelName);
    File(path).parent.createSync(recursive: true);
    File(path).writeAsStringSync(
      jsonEncode({
        "schemaVersion": 1,
        "generationHash": generationHash,
        "updatedAt": "2026-06-15T12:00:00Z",
      }),
    );
  }

  void _writeChannelResources(String channelName, String snapshotHash) {
    final genResources = GenerationResources(schemaVersion: 1)
      ..entries.add(GenerationResources_Entry(serverId: _testServerId, snapshotHash: snapshotHash));
    final path = RepoPaths.channelResourcesPath(channelName);
    File(path).parent.createSync(recursive: true);
    writeProtobufSync(path, genResources);
  }

  Uint8List _generationResourcesBytes(String snapshotHash) {
    final genResources = GenerationResources(schemaVersion: 1)
      ..entries.add(GenerationResources_Entry(serverId: _testServerId, snapshotHash: snapshotHash));
    return genResources.writeToBuffer();
  }

  group("applyDataUpdate", () {
    test(
      "unchanged generation but changed snapshot hash uses local GenerationResources and updates checkout",
      () async {
        final oldSnapshot = _makeSnapshot(createdAt: "2026-06-15T12:00:00Z");
        final newSnapshot = _makeSnapshot(createdAt: "2026-06-16T12:00:00Z");
        expect(oldSnapshot.hash, isNot(newSnapshot.hash));
        expect(
          oldSnapshot.resourceIndex.writeToBuffer(),
          orderedEquals(newSnapshot.resourceIndex.writeToBuffer()),
        );

        final service = _makeService(
          _FakeRemoteCatalogService(
            headMetaResult: Right(_headMeta(generationHash: _testGenerationHashNew)),
            serverIndexResult: Right(
              ServerIndex(
                schemaVersion: 1,
                servers: [
                  ServerIndex_Entry(
                    serverId: _testServerId,
                    gameBuild: "2026.06.16",
                    gameVersion: "1.0",
                  ),
                ],
              ).writeToBuffer(),
            ),
            resourceIndexResult: Right(newSnapshot.resourceIndex.writeToBuffer()),
            resourceSnapshotMetaResult: Right(newSnapshot.meta),
          ),
        );
        final checkoutId = await _createCheckout(service, snapshotHash: oldSnapshot.hash);
        _writeChannelHead(_testChannelName, _testGenerationHashNew);
        _writeChannelResources(_testChannelName, newSnapshot.hash);

        final fakeRemote = service.remoteCatalogService as _FakeRemoteCatalogService;

        final result = await service.applyDataUpdate(
          checkoutId: checkoutId,
          channel: Channel.testing,
          channelName: _testChannelName,
        );

        expect(result.isRight(), isTrue);
        expect(result.toNullable(), newSnapshot.hash);
        expect(fakeRemote.fetchGenerationResourcesCalled, isFalse);

        final updatedMeta = service.readCheckoutMeta(checkoutId).toNullable()!;
        expect(updatedMeta.resourceSnapshotHash, newSnapshot.hash);

        final registry = checkoutRegistry.readRegistry().toNullable()!;
        expect(registry.checkouts[checkoutId]!.resourceSnapshotHash, newSnapshot.hash);

        final reflog = service.readCheckoutReflog(checkoutId).toNullable()!;
        final transition = reflog.entries.last;
        expect(transition.from, oldSnapshot.hash);
        expect(transition.to, newSnapshot.hash);
      },
    );

    test(
      "unchanged generation and unchanged snapshot hash short-circuits via local GenerationResources",
      () async {
        final snapshot = _makeSnapshot(createdAt: "2026-06-15T12:00:00Z");

        final service = _makeService(
          _FakeRemoteCatalogService(
            headMetaResult: Right(_headMeta(generationHash: _testGenerationHashNew)),
          ),
        );
        final checkoutId = await _createCheckout(service, snapshotHash: snapshot.hash);
        _writeChannelHead(_testChannelName, _testGenerationHashNew);
        _writeChannelResources(_testChannelName, snapshot.hash);

        final fakeRemote = service.remoteCatalogService as _FakeRemoteCatalogService;
        final reflogBefore = service.readCheckoutReflog(checkoutId).toNullable()!;

        final result = await service.applyDataUpdate(
          checkoutId: checkoutId,
          channel: Channel.testing,
          channelName: _testChannelName,
        );

        expect(result.isRight(), isTrue);
        expect(result.toNullable(), snapshot.hash);
        expect(fakeRemote.fetchGenerationResourcesCalled, isFalse);

        final updatedMeta = service.readCheckoutMeta(checkoutId).toNullable()!;
        expect(updatedMeta.resourceSnapshotHash, snapshot.hash);

        final reflogAfter = service.readCheckoutReflog(checkoutId).toNullable()!;
        expect(reflogAfter.entries.length, reflogBefore.entries.length + 1);
        final transition = reflogAfter.entries.last;
        expect(transition.from, snapshot.hash);
        expect(transition.to, snapshot.hash);
      },
    );

    test("changed generation with changed snapshot hash performs full update", () async {
      final oldSnapshot = _makeSnapshot(createdAt: "2026-06-15T12:00:00Z");
      final newSnapshot = _makeSnapshot(createdAt: "2026-06-16T12:00:00Z");

      final fakeRemote = _FakeRemoteCatalogService(
        headMetaResult: Right(_headMeta(generationHash: _testGenerationHashNew)),
        serverIndexResult: Right(
          ServerIndex(
            schemaVersion: 1,
            servers: [
              ServerIndex_Entry(
                serverId: _testServerId,
                gameBuild: "2026.06.16",
                gameVersion: "1.0",
              ),
            ],
          ).writeToBuffer(),
        ),
        generationResourcesResult: Right(_generationResourcesBytes(newSnapshot.hash)),
        resourceIndexResult: Right(newSnapshot.resourceIndex.writeToBuffer()),
        resourceSnapshotMetaResult: Right(newSnapshot.meta),
      );
      final service = _makeService(fakeRemote);
      final checkoutId = await _createCheckout(service, snapshotHash: oldSnapshot.hash);
      _writeChannelHead(_testChannelName, _testGenerationHashOld);

      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
      );

      expect(result.isRight(), isTrue);
      expect(result.toNullable(), newSnapshot.hash);
      expect(fakeRemote.fetchGenerationResourcesCalled, isTrue);
      expect(fakeRemote.lastFetchGenerationResourcesHash, _testGenerationHashNew);

      final updatedMeta = service.readCheckoutMeta(checkoutId).toNullable()!;
      expect(updatedMeta.resourceSnapshotHash, newSnapshot.hash);

      final registry = checkoutRegistry.readRegistry().toNullable()!;
      expect(registry.checkouts[checkoutId]!.resourceSnapshotHash, newSnapshot.hash);

      final reflog = service.readCheckoutReflog(checkoutId).toNullable()!;
      final transition = reflog.entries.last;
      expect(transition.from, oldSnapshot.hash);
      expect(transition.to, newSnapshot.hash);
    });

    test("changed generation but unchanged snapshot hash performs metadata-only update", () async {
      final snapshot = _makeSnapshot(createdAt: "2026-06-15T12:00:00Z");

      final fakeRemote = _FakeRemoteCatalogService(
        headMetaResult: Right(_headMeta(generationHash: _testGenerationHashNew)),
        serverIndexResult: Right(
          ServerIndex(
            schemaVersion: 1,
            servers: [
              ServerIndex_Entry(
                serverId: _testServerId,
                gameBuild: "2026.06.16",
                gameVersion: "1.0",
              ),
            ],
          ).writeToBuffer(),
        ),
        generationResourcesResult: Right(_generationResourcesBytes(snapshot.hash)),
      );
      final service = _makeService(fakeRemote);
      final checkoutId = await _createCheckout(service, snapshotHash: snapshot.hash);
      _writeChannelHead(_testChannelName, _testGenerationHashOld);

      final reflogBefore = service.readCheckoutReflog(checkoutId).toNullable()!;

      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
      );

      expect(result.isRight(), isTrue);
      expect(result.toNullable(), snapshot.hash);
      expect(fakeRemote.fetchGenerationResourcesCalled, isTrue);
      expect(fakeRemote.lastFetchGenerationResourcesHash, _testGenerationHashNew);

      final updatedMeta = service.readCheckoutMeta(checkoutId).toNullable()!;
      expect(updatedMeta.resourceSnapshotHash, snapshot.hash);

      final reflogAfter = service.readCheckoutReflog(checkoutId).toNullable()!;
      expect(reflogAfter.entries.length, reflogBefore.entries.length + 1);
      final transition = reflogAfter.entries.last;
      expect(transition.from, snapshot.hash);
      expect(transition.to, snapshot.hash);
    });
  });
}
