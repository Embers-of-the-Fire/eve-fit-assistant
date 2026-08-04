@TestOn("browser")
library;

import "dart:typed_data";

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

Uint8List _indexBytes({required int formatVersion}) {
  final ri = ResourceIndex()
    ..schemaVersion = 1
    ..formatVersion = formatVersion;
  ri.entries.add(
    ResourceIndex_Entry()
      ..resourceId = "resource://static/collection.pb2"
      ..contentHash = "aa" * 32
      ..size = Int64(10)
      ..downloadPolicy = ResourceIndex_DownloadPolicy.FORCE,
  );
  return Uint8List.fromList(ri.writeToBuffer());
}

void main() {
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
        ..serverId = "legacy"
        ..gameBuild = "21.0"
        ..gameVersion = "1.0",
    );
    si.servers.add(
      ServerIndex_Entry()
        ..serverId = "modern"
        ..gameBuild = "21.0"
        ..gameVersion = "1.0",
    );
    when(
      () => mockRemote.fetchServerIndex(_genHash),
    ).thenAnswer((_) async => Right(Uint8List.fromList(si.writeToBuffer())));

    final gr = GenerationResources()..schemaVersion = 1;
    gr.entries.add(
      GenerationResources_Entry()
        ..serverId = "legacy"
        ..snapshotHash = "snap-v1",
    );
    gr.entries.add(
      GenerationResources_Entry()
        ..serverId = "modern"
        ..snapshotHash = "snap-v2",
    );
    when(
      () => mockRemote.fetchGenerationResources(_genHash),
    ).thenAnswer((_) async => Right(Uint8List.fromList(gr.writeToBuffer())));
  });

  test("web excludes servers whose index predates the policy-aware format", () async {
    when(
      () => mockRemote.fetchResourceIndex("snap-v1"),
    ).thenAnswer((_) async => Right(_indexBytes(formatVersion: 1)));
    when(
      () => mockRemote.fetchResourceIndex("snap-v2"),
    ).thenAnswer((_) async => Right(_indexBytes(formatVersion: 2)));

    final result = await service.fetchServerSelectionData(
      channel: Channel.testing,
      channelName: _channelName,
    );
    final data = result.match((e) => fail("fetchServerSelectionData failed: $e"), (d) => d);

    expect(data.servers.map((s) => s.serverId).toList(), ["modern"]);
    expect(data.blobsForServer.containsKey("legacy"), isFalse);
    expect(data.blobsForServer["modern"], {"aa" * 32: 10});
  });
}
