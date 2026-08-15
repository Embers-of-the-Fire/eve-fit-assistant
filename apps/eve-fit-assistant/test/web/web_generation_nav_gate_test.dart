@TestOn("browser")
library;

import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/generation_nav.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

import "../storage/repo/generation_nav_fixtures.dart";

void main() {
  late MockRemoteCatalogService mockRemote;
  late GenerationNavigationService service;

  setUp(() {
    mockRemote = MockRemoteCatalogService();
    service = GenerationNavigationService(remoteCatalogService: mockRemote);
    stubGenerationCatalog(mockRemote, servers: {"legacy": "snap-v1", "modern": "snap-v2"});
  });

  test("web excludes servers whose index predates the policy-aware format", () async {
    when(() => mockRemote.fetchResourceIndex("snap-v1")).thenAnswer(
      (_) async => Right(
        resourceIndexBytes(
          formatVersion: 1,
          entries: [
            (
              resourceId: "resource://static/collection.pb2",
              contentHash: "aa" * 32,
              size: 10,
              policy: ResourceIndex_DownloadPolicy.FORCE,
            ),
          ],
        ),
      ),
    );
    when(() => mockRemote.fetchResourceIndex("snap-v2")).thenAnswer(
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
          ],
        ),
      ),
    );

    final result = await service.fetchServerSelectionData(
      channel: Channel.testing,
      channelName: fixtureChannelName,
    );
    final data = result.match((e) => fail("fetchServerSelectionData failed: $e"), (d) => d);

    expect(data.servers.map((s) => s.serverId).toList(), ["modern"]);
    expect(data.blobsForServer.containsKey("legacy"), isFalse);
    expect(data.blobsForServer["modern"], {"aa" * 32: 10});
  });
}
