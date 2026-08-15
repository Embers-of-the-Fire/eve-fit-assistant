@TestOn("vm")
library;

import "package:efa_compat/io.dart" show Directory;
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/generation_nav.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

import "generation_nav_fixtures.dart";

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_generation_nav_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  late MockRemoteCatalogService mockRemote;
  late GenerationNavigationService service;

  setUp(() {
    mockRemote = MockRemoteCatalogService();
    service = GenerationNavigationService(remoteCatalogService: mockRemote);
    stubGenerationCatalog(mockRemote, servers: {"serenity": "snap-a", "tranquility": "snap-b"});
  });

  Future<ServerSelectionData> fetchSelectionData() async {
    final result = await service.fetchServerSelectionData(
      channel: Channel.testing,
      channelName: fixtureChannelName,
    );
    return result.match((e) => fail("fetchServerSelectionData failed: $e"), (d) => d);
  }

  test("splits per-server blob maps by download policy", () async {
    when(() => mockRemote.fetchResourceIndex("snap-a")).thenAnswer(
      (_) async => Right(
        resourceIndexBytes(
          formatVersion: 2,
          entries: [
            (
              resourceId: "resource://static/collection.pb2",
              contentHash: "aa" * 32,
              size: 10,
              policy: ResourceIndex_DownloadPolicy.FORCE,
            ),
            (
              resourceId: "resource://static/images/icons/1.png",
              contentHash: "bb" * 32,
              size: 20,
              policy: ResourceIndex_DownloadPolicy.NON_FORCE,
            ),
          ],
        ),
      ),
    );
    when(() => mockRemote.fetchResourceIndex("snap-b")).thenAnswer(
      (_) async => Right(
        resourceIndexBytes(
          formatVersion: 2,
          entries: [
            (
              resourceId: "resource://static/images/graphics/1.png",
              contentHash: "cc" * 32,
              size: 30,
              policy: ResourceIndex_DownloadPolicy.NON_FORCE,
            ),
          ],
        ),
      ),
    );

    final data = await fetchSelectionData();

    expect(data.blobsForServer["serenity"], {"aa" * 32: 10});
    expect(data.lazyBlobsForServer["serenity"], {"bb" * 32: 20});
    expect(data.blobsForServer["tranquility"], isEmpty);
    expect(data.lazyBlobsForServer["tranquility"], {"cc" * 32: 30});
  });

  test("legacy pre-policy indexes land entirely in the eager map on native", () async {
    when(() => mockRemote.fetchResourceIndex(any())).thenAnswer(
      (_) async => Right(
        resourceIndexBytes(
          formatVersion: 1,
          entries: [
            (
              resourceId: "resource://static/images/icons/1.png",
              contentHash: "aa" * 32,
              size: 10,
              policy: ResourceIndex_DownloadPolicy.NON_FORCE,
            ),
          ],
        ),
      ),
    );

    final data = await fetchSelectionData();

    expect(data.blobsForServer["serenity"], {"aa" * 32: 10});
    expect(data.lazyBlobsForServer["serenity"], isEmpty);
    expect(data.servers, hasLength(2));
  });

  test("servers whose resource index fetch fails are excluded", () async {
    when(
      () => mockRemote.fetchResourceIndex("snap-a"),
    ).thenAnswer((_) async => const Left(CatalogNetworkError(message: "boom")));
    when(
      () => mockRemote.fetchResourceIndex("snap-b"),
    ).thenAnswer((_) async => Right(resourceIndexBytes(formatVersion: 2, entries: [])));

    final data = await fetchSelectionData();

    expect(data.servers.map((s) => s.serverId).toList(), ["tranquility"]);
    expect(data.blobsForServer.containsKey("serenity"), isFalse);
    expect(data.snapshotHashForServer["serenity"], "snap-a");
  });
}
