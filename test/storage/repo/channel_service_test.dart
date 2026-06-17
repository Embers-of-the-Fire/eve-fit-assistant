import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/channel_service.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_head_meta.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_registry.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

const _testGenerationHash =
    "sha256:aaaa0000111122223333444455556666777788889999aaaabbbbccccddddeeeeffff";

/// A test double for [RemoteCatalogService] that returns canned responses.
class _FakeRemoteCatalogService extends RemoteCatalogService {
  _FakeRemoteCatalogService({
    this.channelRegistryResult,
    this.headMetaResult,
    this.serverIndexResult,
    this.generationResourcesResult,
    this.generationPointerResult,
  }) : super(dio: Dio(), originUrl: "https://test.local");

  Either<CatalogError, ChannelRegistry>? channelRegistryResult;
  Either<CatalogError, ChannelHeadMeta>? headMetaResult;
  Either<CatalogError, Uint8List>? serverIndexResult;
  Either<CatalogError, Uint8List>? generationResourcesResult;
  Either<CatalogError, Uint8List>? generationPointerResult;

  @override
  Future<Either<CatalogError, ChannelRegistry>> fetchChannelRegistry() async =>
      channelRegistryResult ?? Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, ChannelHeadMeta>> fetchHeadMeta(String channelName) async =>
      headMetaResult ?? Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, Uint8List>> fetchServerIndex(String generationHash) async =>
      serverIndexResult ?? Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, Uint8List>> fetchGenerationResources(String generationHash) async =>
      generationResourcesResult ?? Left(const CatalogNetworkError(message: "not configured"));

  @override
  Future<Either<CatalogError, Uint8List>> fetchGenerationPointer(String generationHash) async =>
      generationPointerResult ?? Left(const CatalogNetworkError(message: "not configured"));
}

void main() {
  late String tempDir;
  late AssetStore assetStore;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_channel_service_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_channel_service_test_").path;
    PathProvider.documentsPath = tempDir;
    assetStore = const AssetStore();
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  ChannelService _makeService(_FakeRemoteCatalogService fakeRemote) =>
      ChannelService(remoteCatalogService: fakeRemote, assetStore: assetStore);

  group("syncChannelGeneration", () {
    test("persists all files on success", () async {
      final fakeRemote = _FakeRemoteCatalogService(
        headMetaResult: Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: _testGenerationHash,
            updatedAt: "2026-06-15T12:00:00Z",
            label: IMap(const {"en": "Test Release"}),
          ),
        ),
        serverIndexResult: Right(Uint8List.fromList([10, 20, 30])),
        generationResourcesResult: Right(Uint8List.fromList([40, 50, 60])),
        generationPointerResult: Right(Uint8List.fromList([70, 80, 90])),
      );
      final service = _makeService(fakeRemote);

      final result = await service.syncChannelGeneration("testing");

      expect(result.isRight(), isTrue);

      // Verify all files exist
      expect(
        File(RepoPaths.channelHeadMetaPath("testing")).existsSync(),
        isTrue,
        reason: "metadata.json should exist",
      );
      expect(
        File(RepoPaths.channelServerIndexPath("testing")).existsSync(),
        isTrue,
        reason: "server.pb2 should exist",
      );
      expect(
        File(RepoPaths.channelResourcesPath("testing")).existsSync(),
        isTrue,
        reason: "resources.pb2 should exist",
      );
      expect(
        File(RepoPaths.channelReleasesPath("testing")).existsSync(),
        isTrue,
        reason: "releases.pb2 should exist",
      );

      // Verify file contents
      final metaJson =
          jsonDecode(File(RepoPaths.channelHeadMetaPath("testing")).readAsStringSync())
              as Map<String, dynamic>;
      expect(metaJson["generationHash"], _testGenerationHash);

      final serverBytes = File(RepoPaths.channelServerIndexPath("testing")).readAsBytesSync();
      expect(serverBytes, [10, 20, 30]);

      final resourcesBytes = File(RepoPaths.channelResourcesPath("testing")).readAsBytesSync();
      expect(resourcesBytes, [40, 50, 60]);

      final releasesBytes = File(RepoPaths.channelReleasesPath("testing")).readAsBytesSync();
      expect(releasesBytes, [70, 80, 90]);
    });

    test("best-effort: continues when individual file fetches fail", () async {
      final fakeRemote = _FakeRemoteCatalogService(
        headMetaResult: Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: _testGenerationHash,
            updatedAt: "2026-06-15T12:00:00Z",
            label: IMap(const {"en": "Test Release"}),
          ),
        ),
        serverIndexResult: Right(Uint8List.fromList([1, 2, 3])),
        generationResourcesResult: Left(const CatalogNetworkError(message: "timeout")),
        generationPointerResult: Left(const CatalogNotFoundError(message: "not found")),
      );
      final service = _makeService(fakeRemote);

      final result = await service.syncChannelGeneration("testing");

      // Overall sync should succeed (head meta was fetched)
      expect(result.isRight(), isTrue);

      // server.pb2 should be written
      expect(File(RepoPaths.channelServerIndexPath("testing")).existsSync(), isTrue);

      // Failed fetches should NOT produce files (but sync continues)
      expect(File(RepoPaths.channelResourcesPath("testing")).existsSync(), isFalse);
      expect(File(RepoPaths.channelReleasesPath("testing")).existsSync(), isFalse);

      // metadata.json should still be written
      expect(File(RepoPaths.channelHeadMetaPath("testing")).existsSync(), isTrue);
    });

    test("returns Right when channel not yet initialized on remote (404)", () async {
      final fakeRemote = _FakeRemoteCatalogService(
        headMetaResult: Left(const CatalogNotFoundError(message: "not found")),
      );
      final service = _makeService(fakeRemote);

      final result = await service.syncChannelGeneration("nonexistent");

      expect(result.isRight(), isTrue);
      expect(File(RepoPaths.channelHeadMetaPath("nonexistent")).existsSync(), isFalse);
    });

    test("returns Left on network error when fetching head meta", () async {
      final fakeRemote = _FakeRemoteCatalogService(
        headMetaResult: Left(const CatalogNetworkError(message: "connection refused")),
      );
      final service = _makeService(fakeRemote);

      final result = await service.syncChannelGeneration("testing");

      expect(result.isLeft(), isTrue);
      expect(result.getLeft().toNullable(), contains("connection refused"));
    });

    test("writes files atomically via tmp + rename", () async {
      final fakeRemote = _FakeRemoteCatalogService(
        headMetaResult: Right(
          ChannelHeadMeta(
            schemaVersion: 1,
            generationHash: _testGenerationHash,
            updatedAt: "2026-06-15T12:00:00Z",
            label: IMap(const {"en": "Test Release"}),
          ),
        ),
        serverIndexResult: Right(Uint8List.fromList([1, 2, 3])),
        generationResourcesResult: Right(Uint8List.fromList([4, 5, 6])),
        generationPointerResult: Right(Uint8List.fromList([7, 8, 9])),
      );
      final service = _makeService(fakeRemote);

      await service.syncChannelGeneration("testing");

      // No .tmp files should remain after successful writes
      expect(File("${RepoPaths.channelHeadMetaPath("testing")}.tmp").existsSync(), isFalse);
      expect(File("${RepoPaths.channelServerIndexPath("testing")}.tmp").existsSync(), isFalse);
      expect(File("${RepoPaths.channelResourcesPath("testing")}.tmp").existsSync(), isFalse);
      expect(File("${RepoPaths.channelReleasesPath("testing")}.tmp").existsSync(), isFalse);
    });
  });

  group("discoverChannels", () {
    test("fetches and persists channel registry", () async {
      final channels = IMap<String, ChannelEntry>({
        "testing": ChannelEntry(label: IMap<String, String>({"en": "Testing", "zh": "测试"})),
      });
      final fakeRemote = _FakeRemoteCatalogService(
        channelRegistryResult: Right(
          ChannelRegistry(schemaVersion: 1, active: "testing", channels: channels),
        ),
      );
      final service = _makeService(fakeRemote);

      final result = await service.discoverChannels();

      expect(result.isRight(), isTrue);
      expect(File(RepoPaths.channelRegistryPath).existsSync(), isTrue);

      final saved =
          jsonDecode(File(RepoPaths.channelRegistryPath).readAsStringSync())
              as Map<String, dynamic>;
      expect(saved["active"], "testing");
    });
  });
}
