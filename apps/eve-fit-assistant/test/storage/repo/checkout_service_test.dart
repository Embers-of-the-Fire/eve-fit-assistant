@TestOn("vm")
library;

import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/fs/file_blob_store.dart";
import "package:efa_proto/generation_resources.pb.dart";
import "package:efa_proto/resource_index.pb.dart";
import "package:efa_proto/server_index.pb.dart";
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
import "package:eve_fit_assistant/storage/repo/resource_resolution.dart";
import "package:eve_fit_assistant/storage/repo/utils.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

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

ChannelHeadMeta _headMeta({required String generationHash}) => ChannelHeadMeta(
  schemaVersion: 1,
  generationHash: generationHash,
  updatedAt: "2026-06-16T12:00:00Z",
  label: IMap(const {"en": "Test Release"}),
);

class MockRemoteCatalogService extends Mock implements RemoteCatalogService {}

MockRemoteCatalogService _mockRemote({
  ChannelHeadMeta? headMetaResult,
  Uint8List? serverIndexResult,
  Uint8List? generationResourcesResult,
  Uint8List? resourceIndexResult,
  ResourceSnapshotMeta? resourceSnapshotMetaResult,
}) {
  final mock = MockRemoteCatalogService();
  when(() => mock.fetchHeadMeta(_testChannelName)).thenAnswer(
    (_) async => Right(headMetaResult ?? _headMeta(generationHash: _testGenerationHashNew)),
  );
  when(() => mock.blobUri(any(), any())).thenAnswer(
    (inv) => Uri.parse(
      "http://test/efa/v2/assets/blobs/00/${inv.positionalArguments[0]}/${inv.positionalArguments[1]}",
    ),
  );
  if (serverIndexResult != null) {
    when(
      () => mock.fetchServerIndex(_testGenerationHashNew),
    ).thenAnswer((_) async => Right(serverIndexResult));
  }
  if (generationResourcesResult != null) {
    when(
      () => mock.fetchGenerationResources(_testGenerationHashNew),
    ).thenAnswer((_) async => Right(generationResourcesResult));
  }
  if (resourceIndexResult != null) {
    when(() => mock.fetchResourceIndex(any())).thenAnswer((_) async => Right(resourceIndexResult));
  }
  if (resourceSnapshotMetaResult != null) {
    when(
      () => mock.fetchResourceSnapshotMeta(any()),
    ).thenAnswer((_) async => Right(resourceSnapshotMetaResult));
  }
  return mock;
}

void main() {
  late String tempDir;
  late AssetStore assetStore;
  late CheckoutRegistryService checkoutRegistry;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_checkout_service_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);

    registerFallbackValue("");
    registerFallbackValue(Channel.testing);
    registerFallbackValue(
      const ResourceSnapshotMeta(
        schemaVersion: 1,
        serverId: _testServerId,
        gameBuild: "",
        gameVersion: "",
        resourceCount: 0,
        createdAt: "",
      ),
    );
    registerFallbackValue(ResourceIndex());
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(IMap(const <String, String>{}));
    registerFallbackValue(Uri.parse("http://localhost/"));
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_checkout_service_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.appSupportPath = tempDir;
    PathProvider.cachesPath = tempDir;
    assetStore = AssetStore(FileBlobStore());
    checkoutRegistry = CheckoutRegistryService();
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  CheckoutService _makeService(MockRemoteCatalogService mockRemote, {String locale = "en"}) =>
      CheckoutService(
        assetStore: assetStore,
        remoteCatalogService: mockRemote,
        diffEngine: const DiffEngine(),
        checkoutRegistry: checkoutRegistry,
        resolutionContext: ResourceResolutionContext(locale: locale),
      );

  Future<_TestSnapshot> _makeSnapshot({
    required String createdAt,
    Uint8List? blobContent,
    bool writeBlob = true,
  }) async {
    final content = blobContent ?? Uint8List.fromList([1, 2, 3, 4]);
    final ihash = RepoHash.hashIdent("resource://static/native/types.pb2");
    if (writeBlob) {
      await assetStore.writeBlob(ihash, content);
    }
    final resourceIndex = ResourceIndex(
      schemaVersion: 1,
      entries: [
        ResourceIndex_Entry(
          resourceId: "resource://static/native/types.pb2",
          contentHash: RepoHash.hashContent(content),
          size: Int64(content.length),
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
    final hash = await assetStore.writeResourceSnapshot(meta: meta, resourceIndex: resourceIndex);
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
        final oldSnapshot = await _makeSnapshot(createdAt: "2026-06-15T12:00:00Z");
        final newSnapshot = await _makeSnapshot(createdAt: "2026-06-16T12:00:00Z");
        expect(oldSnapshot.hash, isNot(newSnapshot.hash));
        expect(
          oldSnapshot.resourceIndex.writeToBuffer(),
          orderedEquals(newSnapshot.resourceIndex.writeToBuffer()),
        );

        final mockRemote = _mockRemote(
          serverIndexResult: ServerIndex(
            schemaVersion: 1,
            servers: [
              ServerIndex_Entry(
                serverId: _testServerId,
                gameBuild: "2026.06.16",
                gameVersion: "1.0",
              ),
            ],
          ).writeToBuffer(),
          resourceIndexResult: newSnapshot.resourceIndex.writeToBuffer(),
          resourceSnapshotMetaResult: newSnapshot.meta,
        );
        final service = _makeService(mockRemote);
        final checkoutId = await _createCheckout(service, snapshotHash: oldSnapshot.hash);
        _writeChannelHead(_testChannelName, _testGenerationHashNew);
        _writeChannelResources(_testChannelName, newSnapshot.hash);

        final result = await service.applyDataUpdate(
          checkoutId: checkoutId,
          channel: Channel.testing,
          channelName: _testChannelName,
        );

        expect(result.isRight(), isTrue);
        expect(result.toNullable(), newSnapshot.hash);
        verifyNever(() => mockRemote.fetchGenerationResources(any()));

        final updatedMeta = (await service.readCheckoutMeta(checkoutId)).toNullable()!;
        expect(updatedMeta.resourceSnapshotHash, newSnapshot.hash);

        final registry = checkoutRegistry.readRegistry().toNullable()!;
        expect(registry.checkouts[checkoutId]!.resourceSnapshotHash, newSnapshot.hash);

        final reflog = (await service.readCheckoutReflog(checkoutId)).toNullable()!;
        final transition = reflog.entries.last;
        expect(transition.from, oldSnapshot.hash);
        expect(transition.to, newSnapshot.hash);
      },
    );

    test(
      "unchanged generation and unchanged snapshot hash short-circuits via local GenerationResources",
      () async {
        final snapshot = await _makeSnapshot(createdAt: "2026-06-15T12:00:00Z");

        final mockRemote = _mockRemote();
        final service = _makeService(mockRemote);
        final checkoutId = await _createCheckout(service, snapshotHash: snapshot.hash);
        _writeChannelHead(_testChannelName, _testGenerationHashNew);
        _writeChannelResources(_testChannelName, snapshot.hash);

        final reflogBefore = (await service.readCheckoutReflog(checkoutId)).toNullable()!;

        final result = await service.applyDataUpdate(
          checkoutId: checkoutId,
          channel: Channel.testing,
          channelName: _testChannelName,
        );

        expect(result.isRight(), isTrue);
        expect(result.toNullable(), snapshot.hash);
        verifyNever(() => mockRemote.fetchGenerationResources(any()));

        final updatedMeta = (await service.readCheckoutMeta(checkoutId)).toNullable()!;
        expect(updatedMeta.resourceSnapshotHash, snapshot.hash);

        final reflogAfter = (await service.readCheckoutReflog(checkoutId)).toNullable()!;
        expect(reflogAfter.entries.length, reflogBefore.entries.length + 1);
        final transition = reflogAfter.entries.last;
        expect(transition.from, snapshot.hash);
        expect(transition.to, snapshot.hash);
      },
    );

    test("same snapshot after a locale switch downloads newly eager entries", () async {
      // Snapshot with per-locale dbs: under locale "en", en.db is eager and
      // zh.db is lazy, so only en.db is present locally. After switching to
      // "zh" (the provider rebuilds the service with the new locale), zh.db
      // becomes eager and must be downloaded even though the snapshot hash is
      // unchanged.
      const typesRid = "resource://static/native/types.pb2";
      const enRid = "resource://localization/locales/en.db";
      const zhRid = "resource://localization/locales/zh.db";
      final typesContent = Uint8List.fromList([1, 2, 3, 4]);
      final enContent = Uint8List.fromList([5, 6, 7, 8]);
      final zhContent = Uint8List.fromList([9, 10, 11, 12]);
      final zhCH = RepoHash.hashContent(zhContent);
      final zhIH = RepoHash.hashIdent(zhRid);

      await assetStore.writeBlob(RepoHash.hashIdent(typesRid), typesContent);
      await assetStore.writeBlob(RepoHash.hashIdent(enRid), enContent);

      final index = ResourceIndex(
        schemaVersion: 1,
        formatVersion: 2,
        entries: [
          ResourceIndex_Entry(
            resourceId: typesRid,
            contentHash: RepoHash.hashContent(typesContent),
            size: Int64(typesContent.length),
          ),
          ResourceIndex_Entry(
            resourceId: enRid,
            contentHash: RepoHash.hashContent(enContent),
            size: Int64(enContent.length),
            downloadPolicy: ResourceIndex_DownloadPolicy.NON_FORCE,
          ),
          ResourceIndex_Entry(
            resourceId: zhRid,
            contentHash: zhCH,
            size: Int64(zhContent.length),
            downloadPolicy: ResourceIndex_DownloadPolicy.NON_FORCE,
          ),
        ],
      );
      final meta = ResourceSnapshotMeta(
        schemaVersion: 1,
        serverId: _testServerId,
        gameBuild: "2026.06.15",
        gameVersion: "1.0",
        resourceCount: index.entries.length,
        createdAt: "2026-06-15T12:00:00Z",
      );
      final snapshotHash = await assetStore.writeResourceSnapshot(meta: meta, resourceIndex: index);

      final mockRemote = _mockRemote();
      when(() => mockRemote.fetchBlob(any(), any())).thenAnswer((_) async => Right(zhContent));
      final service = _makeService(mockRemote, locale: "zh");
      final checkoutId = await _createCheckout(service, snapshotHash: snapshotHash);
      _writeChannelHead(_testChannelName, _testGenerationHashNew);
      _writeChannelResources(_testChannelName, snapshotHash);

      final progressCalls = <(int, int)>[];
      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
        onProgress: (downloaded, total) => progressCalls.add((downloaded, total)),
      );

      expect(result.isRight(), isTrue);
      expect(result.toNullable(), snapshotHash);

      // Only the newly eager zh.db downloads; already-present eager entries
      // are not re-fetched and the snapshot is never re-resolved remotely.
      verify(() => mockRemote.fetchBlob(zhIH, zhCH)).called(1);
      verifyNever(() => mockRemote.fetchBlob(RepoHash.hashIdent(enRid), any()));
      verifyNever(() => mockRemote.fetchResourceIndex(any()));
      expect(await assetStore.blobExists(zhIH, zhCH), isTrue);

      // Progress totals count both eager entries under the new locale.
      expect(progressCalls.first, (1, 2));
      expect(progressCalls.last, (2, 2));

      final updatedMeta = (await service.readCheckoutMeta(checkoutId)).toNullable()!;
      expect(updatedMeta.resourceSnapshotHash, snapshotHash);
    });

    test("changed snapshot downloads unchanged-hash entries that became eager", () async {
      // Regression: a snapshot change used to pre-count eager entries whose
      // content hash matched the previous snapshot without checking the blob
      // store. After a locale switch ("en" -> "zh") combined with a snapshot
      // update, zh.db is eager with an unchanged content hash but its blob was
      // never downloaded; the update must fetch it instead of reporting
      // success while the active locale blob is absent.
      const typesRid = "resource://static/native/types.pb2";
      const enRid = "resource://localization/locales/en.db";
      const zhRid = "resource://localization/locales/zh.db";
      final typesContent = Uint8List.fromList([1, 2, 3, 4]);
      final enContent = Uint8List.fromList([5, 6, 7, 8]);
      final zhContent = Uint8List.fromList([9, 10, 11, 12]);
      final zhCH = RepoHash.hashContent(zhContent);
      final zhIH = RepoHash.hashIdent(zhRid);

      await assetStore.writeBlob(RepoHash.hashIdent(typesRid), typesContent);
      await assetStore.writeBlob(RepoHash.hashIdent(enRid), enContent);

      ResourceIndex buildIndex() => ResourceIndex(
        schemaVersion: 1,
        formatVersion: 2,
        entries: [
          ResourceIndex_Entry(
            resourceId: typesRid,
            contentHash: RepoHash.hashContent(typesContent),
            size: Int64(typesContent.length),
          ),
          ResourceIndex_Entry(
            resourceId: enRid,
            contentHash: RepoHash.hashContent(enContent),
            size: Int64(enContent.length),
            downloadPolicy: ResourceIndex_DownloadPolicy.NON_FORCE,
          ),
          ResourceIndex_Entry(
            resourceId: zhRid,
            contentHash: zhCH,
            size: Int64(zhContent.length),
            downloadPolicy: ResourceIndex_DownloadPolicy.NON_FORCE,
          ),
        ],
      );
      ResourceSnapshotMeta buildMeta(String createdAt) => ResourceSnapshotMeta(
        schemaVersion: 1,
        serverId: _testServerId,
        gameBuild: "2026.06.15",
        gameVersion: "1.0",
        resourceCount: 3,
        createdAt: createdAt,
      );

      final oldIndex = buildIndex();
      final oldHash = await assetStore.writeResourceSnapshot(
        meta: buildMeta("2026-06-15T12:00:00Z"),
        resourceIndex: oldIndex,
      );
      // Identical entries (same content hashes), different snapshot hash.
      final newIndex = buildIndex();
      final newMeta = buildMeta("2026-06-16T12:00:00Z");
      final newHash = await assetStore.writeResourceSnapshot(
        meta: newMeta,
        resourceIndex: newIndex,
      );
      expect(newHash, isNot(oldHash));

      final mockRemote = _mockRemote(
        serverIndexResult: ServerIndex(
          schemaVersion: 1,
          servers: [
            ServerIndex_Entry(serverId: _testServerId, gameBuild: "2026.06.16", gameVersion: "1.0"),
          ],
        ).writeToBuffer(),
        generationResourcesResult: _generationResourcesBytes(newHash),
        resourceIndexResult: newIndex.writeToBuffer(),
        resourceSnapshotMetaResult: newMeta,
      );
      when(() => mockRemote.fetchBlob(any(), any())).thenAnswer((_) async => Right(zhContent));

      final service = _makeService(mockRemote, locale: "zh");
      final checkoutId = await _createCheckout(service, snapshotHash: oldHash);
      _writeChannelHead(_testChannelName, _testGenerationHashOld);

      final progressCalls = <(int, int)>[];
      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
        onProgress: (downloaded, total) => progressCalls.add((downloaded, total)),
      );

      expect(result.isRight(), isTrue);
      expect(result.toNullable(), newHash);

      // zh.db's unchanged content hash must not exempt it from blob
      // reconciliation; the missing blob is downloaded exactly once.
      verify(() => mockRemote.fetchBlob(zhIH, zhCH)).called(1);
      verifyNever(() => mockRemote.fetchBlob(RepoHash.hashIdent(enRid), any()));
      verifyNever(() => mockRemote.fetchBlob(RepoHash.hashIdent(typesRid), any()));
      expect(await assetStore.blobExists(zhIH, zhCH), isTrue);

      // Progress totals count both eager entries under the new locale.
      expect(progressCalls.last, (2, 2));

      final updatedMeta = (await service.readCheckoutMeta(checkoutId)).toNullable()!;
      expect(updatedMeta.resourceSnapshotHash, newHash);
    });

    test("same snapshot fails when the local resource index is missing", () async {
      // A checkout whose local snapshot index was lost or corrupted must not
      // reconcile against an empty candidate list and report success.
      final snapshot = await _makeSnapshot(createdAt: "2026-06-15T12:00:00Z");

      final mockRemote = _mockRemote();
      final service = _makeService(mockRemote);
      final checkoutId = await _createCheckout(service, snapshotHash: snapshot.hash);
      _writeChannelHead(_testChannelName, _testGenerationHashNew);
      _writeChannelResources(_testChannelName, snapshot.hash);

      // Remove the local index to simulate a missing snapshot.
      File(RepoPaths.resourceIndexPath(snapshot.hash)).deleteSync();

      final reflogBefore = (await service.readCheckoutReflog(checkoutId)).toNullable()!;

      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
      );

      expect(result.isLeft(), isTrue);
      verifyNever(() => mockRemote.fetchBlob(any(), any()));

      // The checkout pointer and reflog are untouched.
      final updatedMeta = (await service.readCheckoutMeta(checkoutId)).toNullable()!;
      expect(updatedMeta.resourceSnapshotHash, snapshot.hash);
      final reflogAfter = (await service.readCheckoutReflog(checkoutId)).toNullable()!;
      expect(reflogAfter.entries.length, reflogBefore.entries.length);
    });

    test("changed generation with changed snapshot hash performs full update", () async {
      final oldSnapshot = await _makeSnapshot(createdAt: "2026-06-15T12:00:00Z");
      final newSnapshot = await _makeSnapshot(createdAt: "2026-06-16T12:00:00Z");

      final mockRemote = _mockRemote(
        serverIndexResult: ServerIndex(
          schemaVersion: 1,
          servers: [
            ServerIndex_Entry(serverId: _testServerId, gameBuild: "2026.06.16", gameVersion: "1.0"),
          ],
        ).writeToBuffer(),
        generationResourcesResult: _generationResourcesBytes(newSnapshot.hash),
        resourceIndexResult: newSnapshot.resourceIndex.writeToBuffer(),
        resourceSnapshotMetaResult: newSnapshot.meta,
      );
      final service = _makeService(mockRemote);
      final checkoutId = await _createCheckout(service, snapshotHash: oldSnapshot.hash);
      _writeChannelHead(_testChannelName, _testGenerationHashOld);

      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
      );

      expect(result.isRight(), isTrue);
      expect(result.toNullable(), newSnapshot.hash);
      verify(() => mockRemote.fetchGenerationResources(_testGenerationHashNew)).called(1);

      final updatedMeta = (await service.readCheckoutMeta(checkoutId)).toNullable()!;
      expect(updatedMeta.resourceSnapshotHash, newSnapshot.hash);

      final registry = checkoutRegistry.readRegistry().toNullable()!;
      expect(registry.checkouts[checkoutId]!.resourceSnapshotHash, newSnapshot.hash);

      final reflog = (await service.readCheckoutReflog(checkoutId)).toNullable()!;
      final transition = reflog.entries.last;
      expect(transition.from, oldSnapshot.hash);
      expect(transition.to, newSnapshot.hash);
    });

    test("changed generation but unchanged snapshot hash performs metadata-only update", () async {
      final snapshot = await _makeSnapshot(createdAt: "2026-06-15T12:00:00Z");

      final mockRemote = _mockRemote(
        serverIndexResult: ServerIndex(
          schemaVersion: 1,
          servers: [
            ServerIndex_Entry(serverId: _testServerId, gameBuild: "2026.06.16", gameVersion: "1.0"),
          ],
        ).writeToBuffer(),
        generationResourcesResult: _generationResourcesBytes(snapshot.hash),
      );
      final service = _makeService(mockRemote);
      final checkoutId = await _createCheckout(service, snapshotHash: snapshot.hash);
      _writeChannelHead(_testChannelName, _testGenerationHashOld);

      final reflogBefore = (await service.readCheckoutReflog(checkoutId)).toNullable()!;

      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
      );

      expect(result.isRight(), isTrue);
      expect(result.toNullable(), snapshot.hash);
      verify(() => mockRemote.fetchGenerationResources(_testGenerationHashNew)).called(1);

      final updatedMeta = (await service.readCheckoutMeta(checkoutId)).toNullable()!;
      expect(updatedMeta.resourceSnapshotHash, snapshot.hash);

      final reflogAfter = (await service.readCheckoutReflog(checkoutId)).toNullable()!;
      expect(reflogAfter.entries.length, reflogBefore.entries.length + 1);
      final transition = reflogAfter.entries.last;
      expect(transition.from, snapshot.hash);
      expect(transition.to, snapshot.hash);
    });

    test("preserves snapshot metadata name field so local hash matches remote", () async {
      final oldSnapshot = await _makeSnapshot(createdAt: "2026-06-15T12:00:00Z");

      final newMeta = ResourceSnapshotMeta(
        schemaVersion: 1,
        serverId: _testServerId,
        name: IMap(const {"en": "Tranquility", "zh": "宁静"}),
        gameBuild: "2026.06.16",
        gameVersion: "1.0",
        resourceCount: 1,
        createdAt: "2026-06-16T12:00:00Z",
      );
      final newIndex = ResourceIndex(
        schemaVersion: 1,
        entries: [
          ResourceIndex_Entry(
            resourceId: "resource://static/native/types.pb2",
            contentHash: oldSnapshot.resourceIndex.entries.first.contentHash,
            size: oldSnapshot.resourceIndex.entries.first.size,
          ),
        ],
      );
      final expectedHash = await assetStore.writeResourceSnapshot(
        meta: newMeta,
        resourceIndex: newIndex,
      );

      final mockRemote = _mockRemote(
        serverIndexResult: ServerIndex(
          schemaVersion: 1,
          servers: [
            ServerIndex_Entry(serverId: _testServerId, gameBuild: "2026.06.16", gameVersion: "1.0"),
          ],
        ).writeToBuffer(),
        generationResourcesResult: _generationResourcesBytes(expectedHash),
        resourceIndexResult: newIndex.writeToBuffer(),
        resourceSnapshotMetaResult: newMeta,
      );
      final service = _makeService(mockRemote);
      final checkoutId = await _createCheckout(service, snapshotHash: oldSnapshot.hash);
      _writeChannelHead(_testChannelName, _testGenerationHashOld);

      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
      );

      expect(result.isRight(), isTrue);
      expect(result.toNullable(), expectedHash);

      // A second update should see the checkout as current and not re-fetch
      // the resource index.
      final secondResult = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
      );
      expect(secondResult.toNullable(), expectedHash);
      verify(() => mockRemote.fetchResourceIndex(expectedHash)).called(1);
    });

    test("changed blob content triggers fetchBlob download", () async {
      final oldBlobContent = Uint8List.fromList([1, 2, 3, 4]);
      final newBlobContent = Uint8List.fromList([5, 6, 7, 8]);
      final oldSnapshot = await _makeSnapshot(
        createdAt: "2026-06-15T12:00:00Z",
        blobContent: oldBlobContent,
      );
      final newSnapshot = await _makeSnapshot(
        createdAt: "2026-06-16T12:00:00Z",
        blobContent: newBlobContent,
        writeBlob: false,
      );

      final mockRemote = _mockRemote(
        serverIndexResult: ServerIndex(
          schemaVersion: 1,
          servers: [
            ServerIndex_Entry(serverId: _testServerId, gameBuild: "2026.06.16", gameVersion: "1.0"),
          ],
        ).writeToBuffer(),
        generationResourcesResult: _generationResourcesBytes(newSnapshot.hash),
        resourceIndexResult: newSnapshot.resourceIndex.writeToBuffer(),
        resourceSnapshotMetaResult: newSnapshot.meta,
      );
      when(() => mockRemote.fetchBlob(any(), any())).thenAnswer((_) async => Right(newBlobContent));

      final service = _makeService(mockRemote);
      final checkoutId = await _createCheckout(service, snapshotHash: oldSnapshot.hash);
      _writeChannelHead(_testChannelName, _testGenerationHashOld);

      final progressCalls = <(int, int)>[];
      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
        onProgress: (downloaded, total) => progressCalls.add((downloaded, total)),
      );

      expect(result.isRight(), isTrue);
      expect(result.toNullable(), newSnapshot.hash);
      verify(() => mockRemote.fetchBlob(any(), any())).called(1);
      expect(progressCalls, contains((0, 1)));
      expect(progressCalls.last, (1, 1));

      final updatedMeta = (await service.readCheckoutMeta(checkoutId)).toNullable()!;
      expect(updatedMeta.resourceSnapshotHash, newSnapshot.hash);
    });

    test("skips changed lazy entries during update download", () async {
      final oldBlobContent = Uint8List.fromList([1, 2, 3, 4]);
      final oldSnapshot = await _makeSnapshot(
        createdAt: "2026-06-15T12:00:00Z",
        blobContent: oldBlobContent,
      );

      // New snapshot: the eager entry changed, and a lazy image entry is
      // added. Only the eager entry may be downloaded.
      const lazyRid = "resource://static/images/graphics/1.png";
      final newForceContent = Uint8List.fromList([5, 6, 7, 8]);
      final lazyContent = Uint8List.fromList([9, 9, 9]);
      final forceRid = "resource://static/native/types.pb2";
      final forceCH = RepoHash.hashContent(newForceContent);
      final forceIH = RepoHash.hashIdent(forceRid);
      final lazyCH = RepoHash.hashContent(lazyContent);
      final lazyIH = RepoHash.hashIdent(lazyRid);

      final newIndex = ResourceIndex(
        schemaVersion: 1,
        formatVersion: 2,
        entries: [
          ResourceIndex_Entry(
            resourceId: forceRid,
            contentHash: forceCH,
            size: Int64(newForceContent.length),
            downloadPolicy: ResourceIndex_DownloadPolicy.FORCE,
          ),
          ResourceIndex_Entry(
            resourceId: lazyRid,
            contentHash: lazyCH,
            size: Int64(lazyContent.length),
            downloadPolicy: ResourceIndex_DownloadPolicy.NON_FORCE,
          ),
        ],
      );
      final newMeta = ResourceSnapshotMeta(
        schemaVersion: 1,
        serverId: _testServerId,
        gameBuild: "2026.06.16",
        gameVersion: "1.0",
        resourceCount: newIndex.entries.length,
        createdAt: "2026-06-16T12:00:00Z",
      );
      final newHash = await assetStore.writeResourceSnapshot(
        meta: newMeta,
        resourceIndex: newIndex,
      );

      final mockRemote = _mockRemote(
        serverIndexResult: ServerIndex(
          schemaVersion: 1,
          servers: [
            ServerIndex_Entry(serverId: _testServerId, gameBuild: "2026.06.16", gameVersion: "1.0"),
          ],
        ).writeToBuffer(),
        generationResourcesResult: _generationResourcesBytes(newHash),
        resourceIndexResult: newIndex.writeToBuffer(),
        resourceSnapshotMetaResult: newMeta,
      );
      when(
        () => mockRemote.fetchBlob(any(), any()),
      ).thenAnswer((_) async => Right(newForceContent));

      final service = _makeService(mockRemote);
      final checkoutId = await _createCheckout(service, snapshotHash: oldSnapshot.hash);
      _writeChannelHead(_testChannelName, _testGenerationHashOld);

      final progressCalls = <(int, int)>[];
      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
        onProgress: (downloaded, total) => progressCalls.add((downloaded, total)),
      );

      expect(result.isRight(), isTrue);
      expect(result.toNullable(), newHash);

      // Only the eager entry downloads; the lazy entry is left absent.
      verify(() => mockRemote.fetchBlob(forceIH, forceCH)).called(1);
      verifyNever(() => mockRemote.fetchBlob(lazyIH, lazyCH));
      expect(await assetStore.blobExists(forceIH, forceCH), isTrue);
      expect(await assetStore.blobExists(lazyIH, lazyCH), isFalse);

      // Progress totals count only the eager entry.
      expect(progressCalls.last, (1, 1));
    });

    test("excluded entries never enter the update download or progress accounting", () async {
      final oldBlobContent = Uint8List.fromList([1, 2, 3, 4]);
      final oldSnapshot = await _makeSnapshot(
        createdAt: "2026-06-15T12:00:00Z",
        blobContent: oldBlobContent,
      );

      // New snapshot with per-locale dbs: R1 excludes the legacy combined db,
      // R2 makes the active locale ("en") eager, R3 keeps "zh" lazy.
      const legacyRid = "resource://localization/localization.db";
      const activeRid = "resource://localization/locales/en.db";
      const otherRid = "resource://localization/locales/zh.db";
      final activeContent = Uint8List.fromList([5, 6, 7, 8]);
      final activeCH = RepoHash.hashContent(activeContent);
      final activeIH = RepoHash.hashIdent(activeRid);

      final newIndex = ResourceIndex(
        schemaVersion: 1,
        formatVersion: 2,
        entries: [
          ResourceIndex_Entry(
            resourceId: legacyRid,
            contentHash: "dd" * 32,
            size: Int64(100),
            downloadPolicy: ResourceIndex_DownloadPolicy.FORCE,
          ),
          ResourceIndex_Entry(
            resourceId: activeRid,
            contentHash: activeCH,
            size: Int64(activeContent.length),
            downloadPolicy: ResourceIndex_DownloadPolicy.NON_FORCE,
          ),
          ResourceIndex_Entry(
            resourceId: otherRid,
            contentHash: "ff" * 32,
            size: Int64(50),
            downloadPolicy: ResourceIndex_DownloadPolicy.NON_FORCE,
          ),
        ],
      );
      final newMeta = ResourceSnapshotMeta(
        schemaVersion: 1,
        serverId: _testServerId,
        gameBuild: "2026.06.16",
        gameVersion: "1.0",
        resourceCount: newIndex.entries.length,
        createdAt: "2026-06-16T12:00:00Z",
      );
      final newHash = await assetStore.writeResourceSnapshot(
        meta: newMeta,
        resourceIndex: newIndex,
      );

      final mockRemote = _mockRemote(
        serverIndexResult: ServerIndex(
          schemaVersion: 1,
          servers: [
            ServerIndex_Entry(serverId: _testServerId, gameBuild: "2026.06.16", gameVersion: "1.0"),
          ],
        ).writeToBuffer(),
        generationResourcesResult: _generationResourcesBytes(newHash),
        resourceIndexResult: newIndex.writeToBuffer(),
        resourceSnapshotMetaResult: newMeta,
      );
      when(() => mockRemote.fetchBlob(any(), any())).thenAnswer((_) async => Right(activeContent));

      final service = _makeService(mockRemote);
      final checkoutId = await _createCheckout(service, snapshotHash: oldSnapshot.hash);
      _writeChannelHead(_testChannelName, _testGenerationHashOld);

      final progressCalls = <(int, int)>[];
      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
        onProgress: (downloaded, total) => progressCalls.add((downloaded, total)),
      );

      expect(result.isRight(), isTrue);

      // Only the active locale's db downloads; the excluded legacy db and the
      // lazy other-locale db are never fetched.
      verify(() => mockRemote.fetchBlob(activeIH, activeCH)).called(1);
      verifyNever(() => mockRemote.fetchBlob(RepoHash.hashIdent(legacyRid), any()));
      verifyNever(() => mockRemote.fetchBlob(RepoHash.hashIdent(otherRid), any()));

      // Progress totals count only the eager entry.
      expect(progressCalls.last, (1, 1));
    });

    test("returns Left when fetchBlob fails with a non-304 error", () async {
      final oldBlobContent = Uint8List.fromList([1, 2, 3, 4]);
      final newBlobContent = Uint8List.fromList([5, 6, 7, 8]);
      final oldSnapshot = await _makeSnapshot(
        createdAt: "2026-06-15T12:00:00Z",
        blobContent: oldBlobContent,
      );
      final newSnapshot = await _makeSnapshot(
        createdAt: "2026-06-16T12:00:00Z",
        blobContent: newBlobContent,
        writeBlob: false,
      );

      final mockRemote = _mockRemote(
        serverIndexResult: ServerIndex(
          schemaVersion: 1,
          servers: [
            ServerIndex_Entry(serverId: _testServerId, gameBuild: "2026.06.16", gameVersion: "1.0"),
          ],
        ).writeToBuffer(),
        generationResourcesResult: _generationResourcesBytes(newSnapshot.hash),
        resourceIndexResult: newSnapshot.resourceIndex.writeToBuffer(),
        resourceSnapshotMetaResult: newSnapshot.meta,
      );
      when(
        () => mockRemote.fetchBlob(any(), any()),
      ).thenAnswer((_) async => const Left(CatalogNetworkError(message: "boom")));

      final service = _makeService(mockRemote);
      final checkoutId = await _createCheckout(service, snapshotHash: oldSnapshot.hash);
      _writeChannelHead(_testChannelName, _testGenerationHashOld);

      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
      );

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), "Failed to download changed files");
      verify(() => mockRemote.fetchBlob(any(), any())).called(1);

      final unchangedMeta = (await service.readCheckoutMeta(checkoutId)).toNullable()!;
      expect(unchangedMeta.resourceSnapshotHash, oldSnapshot.hash);
    });

    test("returns Left when fetchResourceSnapshotMeta fails", () async {
      final oldBlobContent = Uint8List.fromList([1, 2, 3, 4]);
      final newBlobContent = Uint8List.fromList([5, 6, 7, 8]);
      final oldSnapshot = await _makeSnapshot(
        createdAt: "2026-06-15T12:00:00Z",
        blobContent: oldBlobContent,
      );
      final newSnapshot = await _makeSnapshot(
        createdAt: "2026-06-16T12:00:00Z",
        blobContent: newBlobContent,
        writeBlob: false,
      );

      final mockRemote = _mockRemote(
        serverIndexResult: ServerIndex(
          schemaVersion: 1,
          servers: [
            ServerIndex_Entry(serverId: _testServerId, gameBuild: "2026.06.16", gameVersion: "1.0"),
          ],
        ).writeToBuffer(),
        generationResourcesResult: _generationResourcesBytes(newSnapshot.hash),
        resourceIndexResult: newSnapshot.resourceIndex.writeToBuffer(),
      );
      when(
        () => mockRemote.fetchResourceSnapshotMeta(any()),
      ).thenAnswer((_) async => const Left(CatalogNetworkError(message: "metadata timeout")));
      when(() => mockRemote.fetchBlob(any(), any())).thenAnswer((_) async => Right(newBlobContent));

      final service = _makeService(mockRemote);
      final checkoutId = await _createCheckout(service, snapshotHash: oldSnapshot.hash);
      _writeChannelHead(_testChannelName, _testGenerationHashOld);

      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
      );

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), "metadata timeout");

      final unchangedMeta = (await service.readCheckoutMeta(checkoutId)).toNullable()!;
      expect(unchangedMeta.resourceSnapshotHash, oldSnapshot.hash);

      final registry = checkoutRegistry.readRegistry().toNullable()!;
      expect(registry.checkouts[checkoutId]!.resourceSnapshotHash, oldSnapshot.hash);

      final reflog = (await service.readCheckoutReflog(checkoutId)).toNullable()!;
      expect(reflog.entries.length, 1);
    });

    test("returns Left when fetchServerIndex fails", () async {
      final oldBlobContent = Uint8List.fromList([1, 2, 3, 4]);
      final newBlobContent = Uint8List.fromList([5, 6, 7, 8]);
      final oldSnapshot = await _makeSnapshot(
        createdAt: "2026-06-15T12:00:00Z",
        blobContent: oldBlobContent,
      );
      final newSnapshot = await _makeSnapshot(
        createdAt: "2026-06-16T12:00:00Z",
        blobContent: newBlobContent,
        writeBlob: false,
      );

      final mockRemote = _mockRemote(
        generationResourcesResult: _generationResourcesBytes(newSnapshot.hash),
        resourceIndexResult: newSnapshot.resourceIndex.writeToBuffer(),
        resourceSnapshotMetaResult: newSnapshot.meta,
      );
      when(
        () => mockRemote.fetchServerIndex(_testGenerationHashNew),
      ).thenAnswer((_) async => const Left(CatalogNetworkError(message: "server index timeout")));
      when(() => mockRemote.fetchBlob(any(), any())).thenAnswer((_) async => Right(newBlobContent));

      final service = _makeService(mockRemote);
      final checkoutId = await _createCheckout(service, snapshotHash: oldSnapshot.hash);
      _writeChannelHead(_testChannelName, _testGenerationHashOld);

      final result = await service.applyDataUpdate(
        checkoutId: checkoutId,
        channel: Channel.testing,
        channelName: _testChannelName,
      );

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), "server index timeout");

      final unchangedMeta = (await service.readCheckoutMeta(checkoutId)).toNullable()!;
      expect(unchangedMeta.resourceSnapshotHash, oldSnapshot.hash);
    });
  });
}
