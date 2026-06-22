import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/proto/generation_resources.pb.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/data/proto/server_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_registry.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";

sealed class GenerationNavError implements Exception {
  const GenerationNavError();
}

class GenerationNavNetworkError extends GenerationNavError {
  const GenerationNavNetworkError({required this.message});

  final String message;

  @override
  String toString() => message;
}

class ChannelOverview {
  const ChannelOverview({required this.channels, required this.defaultChannel});

  final IMap<String, ChannelEntry> channels;
  final String defaultChannel;
}

class ServerSummary {
  const ServerSummary({
    required this.serverId,
    required this.gameBuild,
    required this.gameVersion,
    this.name,
    this.region,
    this.sync,
    this.branch,
  });

  factory ServerSummary.fromEntry(ServerIndex_Entry entry) => ServerSummary(
    serverId: entry.serverId,
    gameBuild: entry.gameBuild,
    gameVersion: entry.gameVersion,
    name: Map<String, String>.from(entry.name),
    region: entry.hasRegion() ? entry.region : null,
    sync: entry.hasSync() ? entry.sync : null,
    branch: entry.hasBranch() ? entry.branch : null,
  );

  final String serverId;
  final String gameBuild;
  final String gameVersion;
  final Map<String, String>? name;
  final String? region;
  final String? sync;
  final String? branch;

  /// Returns the display name for [locale], falling back to serverId.
  String displayName(String locale) => name?[locale] ?? serverId;
}

/// Aggregated data for the server selection step: server list plus per-server
/// blob content-hash→size maps so the UI can compute the deduplicated download
/// footprint across selected servers.
class ServerSelectionData {
  ServerSelectionData({
    required this.servers,
    required this.blobsForServer,
    required this.snapshotHashForServer,
    required this.generationHash,
  });

  final IList<ServerSummary> servers;
  final Map<String, Map<String, int>> blobsForServer;

  /// Maps serverId → resource snapshot hash for the active generation.
  final Map<String, String> snapshotHashForServer;

  /// The channel-level generation hash for the active head.
  final String generationHash;
}

/// Data source for the setup page's channel/server browser.
///
/// Uses the channel registry and server index from the generation chain.
class GenerationNavigationService {
  const GenerationNavigationService({required this.remoteCatalogService});

  final RemoteCatalogService remoteCatalogService;

  /// Fetches the available channels from remote.
  Future<Either<GenerationNavError, ChannelOverview>> fetchChannels() async {
    final result = await remoteCatalogService.fetchChannelRegistry();
    if (result.isLeft()) {
      return const Left(GenerationNavNetworkError(message: "Failed to fetch channels"));
    }
    final registry = result.getRight().toNullable()!;
    return Right(
      ChannelOverview(
        channels: registry.channels,
        defaultChannel: registry.active.isEmpty ? "testing" : registry.active,
      ),
    );
  }

  /// Fetches the server list for [channelName] from the current generation.
  Future<Either<GenerationNavError, IList<ServerSummary>>> fetchServers({
    required Channel channel,
    required String channelName,
  }) async {
    // Get current generation hash. Pass the locally cached head metadata so a
    // 304 short-circuits to it instead of forcing a full re-fetch.
    final headResult = await remoteCatalogService.fetchHeadMeta(
      channelName,
      cachedPayload: _readLocalHeadMetaJson(channelName),
    );
    if (headResult.isLeft()) {
      return const Left(GenerationNavNetworkError(message: "Failed to fetch head metadata"));
    }
    final generationHash = headResult.getRight().toNullable()!.generationHash;

    // Fetch server index from generation. A persisted but stale ETag can yield
    // a "not modified" result with no locally available payload (e.g. on a cold
    // start during welcome, before any checkout has persisted the index); in
    // that case retry with a fresh fetch that bypasses the ETag cache.
    var serverResult = await remoteCatalogService.fetchServerIndex(generationHash);
    if (serverResult.getLeft().toNullable() is CatalogNotModified) {
      serverResult = await remoteCatalogService.fetchServerIndexFresh(generationHash);
    }
    if (serverResult.isLeft()) {
      return const Left(GenerationNavNetworkError(message: "Failed to fetch server index"));
    }
    final serverIndex = ServerIndex.fromBuffer(serverResult.getRight().toNullable()!);

    return Right(serverIndex.servers.map(ServerSummary.fromEntry).toIList());
  }

  /// Reads the raw local channel head metadata JSON for [channelName], or null.
  ///
  /// Used as the conditional-request fallback payload for `fetchHeadMeta`.
  Map<String, dynamic>? _readLocalHeadMetaJson(String channelName) {
    final file = File(RepoPaths.channelHeadMetaPath(channelName));
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync());
      return json is Map<String, dynamic> ? json : null;
    } on Exception {
      return null;
    }
  }

  /// Fetches the server list and per-server blob maps for [channelName].
  ///
  /// Fetches head metadata, server index, generation resources, and resource
  /// index protobufs for every unique snapshot hash in parallel.  Each resource
  /// index is parsed into a `{contentHash → size}` map so the UI can union
  /// selected servers' blob sets and display the deduplicated download total.
  Future<Either<GenerationNavError, ServerSelectionData>> fetchServerSelectionData({
    required Channel channel,
    required String channelName,
  }) async {
    final headResult = await remoteCatalogService.fetchHeadMeta(channelName);
    if (headResult.isLeft()) {
      return const Left(GenerationNavNetworkError(message: "Failed to fetch head metadata"));
    }
    final generationHash = headResult.getRight().toNullable()!.generationHash;

    var serverResult = await remoteCatalogService.fetchServerIndex(generationHash);
    if (serverResult.getLeft().toNullable() is CatalogNotModified) {
      serverResult = await remoteCatalogService.fetchServerIndexFresh(generationHash);
    }
    if (serverResult.isLeft()) {
      return const Left(GenerationNavNetworkError(message: "Failed to fetch server index"));
    }
    final serverIndex = ServerIndex.fromBuffer(serverResult.getRight().toNullable()!);

    var genResourcesResult = await remoteCatalogService.fetchGenerationResources(generationHash);
    if (genResourcesResult.getLeft().toNullable() is CatalogNotModified) {
      genResourcesResult = await remoteCatalogService.fetchGenerationResourcesFresh(generationHash);
    }
    if (genResourcesResult.isLeft()) {
      return const Left(GenerationNavNetworkError(message: "Failed to fetch generation resources"));
    }
    final genResources = GenerationResources.fromBuffer(
      genResourcesResult.getRight().toNullable()!,
    );

    final serverToSnapshot = <String, String>{};
    for (final entry in genResources.entries) {
      serverToSnapshot[entry.serverId] = entry.snapshotHash;
    }

    final uniqueHashes = serverToSnapshot.values.toSet();
    final snapshotBlobs = <String, Map<String, int>>{};

    final futures = <Future<void>>[];
    for (final hash in uniqueHashes) {
      futures.add(() async {
        final result = await remoteCatalogService.fetchResourceIndex(hash);
        result.match((err) => warning("Failed to fetch resource index for snapshot $hash: $err"), (
          bytes,
        ) {
          final index = ResourceIndex.fromBuffer(bytes);
          final blobs = <String, int>{};
          for (final entry in index.entries) {
            blobs[entry.contentHash] = entry.size.toInt();
          }
          snapshotBlobs[hash] = blobs;
        });
      }());
    }
    await Future.wait(futures);

    final blobsForServer = <String, Map<String, int>>{};
    final skippedServers = <String>{};
    for (final entry in genResources.entries) {
      final blobs = snapshotBlobs[entry.snapshotHash];
      if (blobs != null) {
        blobsForServer[entry.serverId] = blobs;
      } else {
        skippedServers.add(entry.serverId);
      }
    }

    if (skippedServers.isNotEmpty) {
      warning(
        "Servers with failed resource index fetch, excluded from selection: "
        "${skippedServers.join(", ")}",
      );
    }

    return Right(
      ServerSelectionData(
        servers: serverIndex.servers
            .map(ServerSummary.fromEntry)
            .where((s) => !skippedServers.contains(s.serverId))
            .toIList(),
        blobsForServer: blobsForServer,
        snapshotHashForServer: serverToSnapshot,
        generationHash: generationHash,
      ),
    );
  }
}
