import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_catalog.dart";
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

class GenerationTree {
  const GenerationTree({
    required this.activatedGeneration,
    required this.generations,
    required this.servers,
  });

  final String activatedGeneration;
  final IList<GenerationEntry> generations;
  final IList<ServerSummary> servers;
}

class ServerSummary {
  const ServerSummary({required this.serverId, required this.lastUpdatedAt, required this.name});

  final String serverId;
  final String lastUpdatedAt;
  final IMap<String, String> name;
}

class GenerationServerDetail {
  const GenerationServerDetail({required this.server, required this.checkouts});

  final GenerationServer server;
  final IList<GenerationCheckoutEntry> checkouts;
}

/// Data source for the branch management page's server/checkout browser.
///
/// Drills down from generations → resources (servers) → individual server
/// checkouts, using cached remote catalog fetches via [RemoteCatalogService].
class GenerationNavigationService {
  const GenerationNavigationService({required this.remoteCatalogService});

  final RemoteCatalogService remoteCatalogService;

  /// Fetches the full generation tree for [channel]:
  ///
  /// 1. Activated generation ID from manifest index
  /// 2. All generations from generations index
  /// 3. Server list from the activated generation's resources catalog
  ///
  /// Returns [GenerationTree] on success.
  Future<Either<GenerationNavError, GenerationTree>> fetchTree(Channel channel) async {
    final manifestResult = await remoteCatalogService.fetchManifestIndex(channel);
    if (manifestResult.isLeft()) {
      return const Left(GenerationNavNetworkError(message: "Failed to fetch manifest index"));
    }
    final manifest = manifestResult.getRight().toNullable()!;
    final activatedGeneration = manifest.activatedGeneration;

    final genIndexResult = await remoteCatalogService.fetchGenerations(channel);
    if (genIndexResult.isLeft()) {
      return const Left(GenerationNavNetworkError(message: "Failed to fetch generations index"));
    }
    final genIndex = genIndexResult.getRight().toNullable()!;

    final resourcesResult = await remoteCatalogService.fetchResourcesCatalog(
      channel,
      activatedGeneration,
    );
    if (resourcesResult.isLeft()) {
      return Left(
        GenerationNavNetworkError(
          message: "Failed to fetch resources catalog for generation $activatedGeneration",
        ),
      );
    }
    final resources = resourcesResult.getRight().toNullable()!;

    final servers = resources.servers.entries.map(
      (e) =>
          ServerSummary(serverId: e.key, lastUpdatedAt: e.value.lastUpdatedAt, name: e.value.name),
    );

    return Right(
      GenerationTree(
        activatedGeneration: activatedGeneration,
        generations: genIndex.generations.values.toIList(),
        servers: servers.toIList(),
      ),
    );
  }

  /// Fetches the server detail (with its checkout list) for [serverId] in
  /// [genId] on [channel].
  Future<Either<GenerationNavError, GenerationServerDetail>> fetchServerDetail(
    Channel channel,
    String genId,
    String serverId,
  ) async {
    final serverResult = await remoteCatalogService.fetchServerCatalog(channel, genId, serverId);
    if (serverResult.isLeft()) {
      return Left(
        GenerationNavNetworkError(message: "Failed to fetch server catalog for $serverId"),
      );
    }
    final server = serverResult.getRight().toNullable()!;

    return Right(GenerationServerDetail(server: server, checkouts: server.checkouts));
  }
}
