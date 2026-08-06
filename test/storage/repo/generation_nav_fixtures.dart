import "dart:typed_data";

import "package:eve_fit_assistant/data/proto/generation_resources.pb.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/data/proto/server_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_head_meta.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fixnum/fixnum.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

/// Shared scaffolding for the generation-navigation suites
/// (`generation_nav_test.dart` on the VM, `web_generation_nav_gate_test.dart`
/// on web) so the mock catalog and index-bytes builders cannot drift.
class MockRemoteCatalogService extends Mock implements RemoteCatalogService {}

const fixtureGenerationHash =
    "gen-0000000000000000000000000000000000000000000000000000000000000001";
const fixtureChannelName = "testing";

typedef ResourceIndexEntrySpec = ({
  String resourceId,
  String contentHash,
  int size,
  ResourceIndex_DownloadPolicy? policy,
});

/// Serializes a [ResourceIndex] with [formatVersion] and [entries].
Uint8List resourceIndexBytes({
  required int formatVersion,
  required List<ResourceIndexEntrySpec> entries,
}) {
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

/// Stubs the shared catalog fetches (head meta, server index, generation
/// resources) for [servers] as serverId → snapshotHash pairs.
void stubGenerationCatalog(
  MockRemoteCatalogService mock, {
  required Map<String, String> servers,
  String generationHash = fixtureGenerationHash,
  String channelName = fixtureChannelName,
}) {
  when(() => mock.fetchHeadMeta(channelName)).thenAnswer(
    (_) async => Right(
      ChannelHeadMeta(
        schemaVersion: 1,
        generationHash: generationHash,
        updatedAt: "2026-01-01T00:00:00Z",
      ),
    ),
  );

  final si = ServerIndex()..schemaVersion = 1;
  for (final serverId in servers.keys) {
    si.servers.add(
      ServerIndex_Entry()
        ..serverId = serverId
        ..gameBuild = "21.0"
        ..gameVersion = "1.0",
    );
  }
  when(
    () => mock.fetchServerIndex(generationHash),
  ).thenAnswer((_) async => Right(Uint8List.fromList(si.writeToBuffer())));

  final gr = GenerationResources()..schemaVersion = 1;
  for (final MapEntry(key: serverId, value: snapshotHash) in servers.entries) {
    gr.entries.add(
      GenerationResources_Entry()
        ..serverId = serverId
        ..snapshotHash = snapshotHash,
    );
  }
  when(
    () => mock.fetchGenerationResources(generationHash),
  ).thenAnswer((_) async => Right(Uint8List.fromList(gr.writeToBuffer())));
}
