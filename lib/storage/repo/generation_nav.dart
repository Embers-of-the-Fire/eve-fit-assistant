import "package:eve_fit_assistant/data/proto/server_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_registry.dart";
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
    // Get current generation hash
    final headResult = await remoteCatalogService.fetchHeadMeta(channelName);
    if (headResult.isLeft()) {
      return const Left(GenerationNavNetworkError(message: "Failed to fetch head metadata"));
    }
    final generationHash = headResult.getRight().toNullable()!.generationHash;

    // Fetch server index from generation
    final serverResult = await remoteCatalogService.fetchServerIndex(generationHash);
    if (serverResult.isLeft()) {
      return const Left(GenerationNavNetworkError(message: "Failed to fetch server index"));
    }
    final serverIndex = ServerIndex.fromBuffer(serverResult.getRight().toNullable()!);

    return Right(serverIndex.servers.map(ServerSummary.fromEntry).toIList());
  }
}
