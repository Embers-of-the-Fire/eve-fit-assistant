@TestOn("vm")
library;

import "dart:typed_data";

import "package:eve_fit_assistant/compat/io.dart" show Directory;
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/proto/generation_resources.pb.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/data/proto/server_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/generation_nav.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_head_meta.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

class MockRemoteCatalogService extends Mock implements RemoteCatalogService {}

const _genHash = "gen-0000000000000000000000000000000000000000000000000000000000000001";
const _channelName = "testing";

typedef _EntrySpec = ({
  String resourceId,
  String contentHash,
  int size,
  ResourceIndex_DownloadPolicy? policy,
});

Uint8List _indexBytes({required int formatVersion, required List<_EntrySpec> entries}) {
  final ri = ResourceIndex()
    ..schemaVersion = 1
    ..formatVersion = formatVersion;
  for (final e in entries) {
    final entry = ResourceIndex_Entry()
      ..resourceId = e.resourceId
      ..contentHash = e.contentHash
      ..size = Int64(e.size);
    final policy = e.policy;
    if (policy != null) entry.downloadPolicy = policy;
    ri.entries.add(entry);
  }
  return Uint8List.fromList(ri.writeToBuffer());
}

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

    when(() => mockRemote.fetchHeadMeta(_channelName)).thenAnswer(
      (_) async => const Right(
        ChannelHeadMeta(
          schemaVersion: 1,
          generationHash: _genHash,
          updatedAt: "2026-01-01T00:00:00Z",
        ),
      ),
    );

    final si = ServerIndex()..schemaVersion = 1;
    si.servers.add(
      ServerIndex_Entry()
        ..serverId = "serenity"
        ..gameBuild = "21.0"
        ..gameVersion = "1.0",
    );
    si.servers.add(
      ServerIndex_Entry()
        ..serverId = "tranquility"
        ..gameBuild = "21.0"
        ..gameVersion = "1.0",
    );
    when(
      () => mockRemote.fetchServerIndex(_genHash),
    ).thenAnswer((_) async => Right(Uint8List.fromList(si.writeToBuffer())));

    final gr = GenerationResources()..schemaVersion = 1;
    gr.entries.add(
      GenerationResources_Entry()
        ..serverId = "serenity"
        ..snapshotHash = "snap-a",
    );
    gr.entries.add(
      GenerationResources_Entry()
        ..serverId = "tranquility"
        ..snapshotHash = "snap-b",
    );
    when(
      () => mockRemote.fetchGenerationResources(_genHash),
    ).thenAnswer((_) async => Right(Uint8List.fromList(gr.writeToBuffer())));
  });

  Future<ServerSelectionData> fetchSelectionData() async {
    final result = await service.fetchServerSelectionData(
      channel: Channel.testing,
      channelName: _channelName,
    );
    return result.match((e) => fail("fetchServerSelectionData failed: $e"), (d) => d);
  }

  test("splits per-server blob maps by download policy", () async {
    when(() => mockRemote.fetchResourceIndex("snap-a")).thenAnswer(
      (_) async => Right(
        _indexBytes(
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
        _indexBytes(
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
        _indexBytes(
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
    ).thenAnswer((_) async => Right(_indexBytes(formatVersion: 2, entries: [])));

    final data = await fetchSelectionData();

    expect(data.servers.map((s) => s.serverId).toList(), ["tranquility"]);
    expect(data.blobsForServer.containsKey("serenity"), isFalse);
    expect(data.snapshotHashForServer["serenity"], "snap-a");
  });
}
