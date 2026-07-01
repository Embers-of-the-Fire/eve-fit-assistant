import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/proto/generation_pointer.pb.dart";
import "package:eve_fit_assistant/data/proto/generation_resources.pb.dart";
import "package:eve_fit_assistant/data/proto/server_index.pb.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_head_meta.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_registry.dart";
import "package:eve_fit_assistant/storage/repo/models/server_meta.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/utils.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";

/// Manages channel discovery, head metadata, and server index.
///
/// Follows agent/schemav2/workflow.md §2.2 (Channel Discovery).
class ChannelService {
  const ChannelService({required this.remoteCatalogService, required this.assetStore});

  final RemoteCatalogService remoteCatalogService;
  final AssetStore assetStore;

  /// Fetches and persists the channel registry from remote.
  ///
  /// On first launch, uses defaultChannel from the remote.
  Future<Either<String, ChannelRegistry>> discoverChannels() async {
    final localReg = readLocalChannelRegistry();
    final result = await remoteCatalogService.fetchChannelRegistry(
      cachedPayload: localReg.isSome() ? localReg.toNullable()!.toJson() : null,
    );
    if (result.isLeft()) {
      final err = result.getLeft().toNullable()!;
      return Left(switch (err) {
        CatalogNetworkError() => "Network error fetching channels: ${err.message}",
        CatalogNotFoundError() => "Channel registry not found: ${err.message}",
        CatalogParseError() => "Failed to parse channel registry: ${err.message}",
        CatalogNotModified() => "Channel registry returned 304 with no cached payload",
      });
    }
    final remoteRegistry = result.getRight().toNullable()!;

    // Write locally
    _writeChannelRegistry(remoteRegistry);

    return Right(remoteRegistry);
  }

  /// Fetches and persists channel head metadata and server index for [channelName].
  Future<Either<String, Unit>> fetchChannelInfo(String channelName) async {
    // Fetch head metadata
    final localHead = readHeadMeta(channelName);
    final headResult = await remoteCatalogService.fetchHeadMeta(
      channelName,
      cachedPayload: localHead.isSome() ? localHead.toNullable()!.toJson() : null,
    );
    if (headResult.isLeft()) {
      final err = headResult.getLeft().toNullable()!;
      if (err is CatalogNotFoundError) {
        return const Right(unit); // Channel not yet initialized on remote
      }
      return Left(switch (err) {
        CatalogNetworkError() => "Network error fetching channel info: ${err.message}",
        CatalogParseError() => "Failed to parse channel info: ${err.message}",
        CatalogNotModified() => "Channel info returned 304 with no cached payload",
        CatalogNotFoundError() => "Channel info not found: ${err.message}",
      });
    }
    final head = headResult.getRight().toNullable()!;

    // Write local channel head metadata
    _writeLocalHeadMeta(channelName, head);

    // Fetch and write server index
    final serverResult = await remoteCatalogService.fetchServerIndex(head.generationHash);
    if (serverResult.isRight()) {
      _writeServerIndex(channelName, serverResult.getRight().toNullable()!);
    }

    return const Right(unit);
  }

  /// Fetches and persists all generation-level files for [channelName].
  ///
  /// Best-effort: individual file fetch failures are logged but do not abort
  /// the overall sync. The only hard failure is an inability to fetch the
  /// channel head metadata (which provides the generation hash).
  ///
  /// Persisted files:
  /// - channels/{channel}/metadata.json   — channel head metadata
  /// - channels/{channel}/server.pb2      — ServerIndex
  /// - channels/{channel}/resources.pb2   — GenerationResources
  /// - channels/{channel}/releases.pb2    — GenerationPointer (releases)
  Future<Either<String, Unit>> syncChannelGeneration(String channelName) async {
    // Fetch head metadata to get the generation hash
    final localHead = readHeadMeta(channelName);
    final headResult = await remoteCatalogService.fetchHeadMeta(
      channelName,
      cachedPayload: localHead.isSome() ? localHead.toNullable()!.toJson() : null,
    );
    if (headResult.isLeft()) {
      final err = headResult.getLeft().toNullable()!;
      if (err is CatalogNotFoundError) {
        return const Right(unit); // Channel not yet initialized on remote
      }
      return Left(switch (err) {
        CatalogNetworkError() => "Network error fetching channel head meta: ${err.message}",
        CatalogParseError() => "Failed to parse channel head meta: ${err.message}",
        CatalogNotModified() => "Channel head meta returned 304 with no cached payload",
        CatalogNotFoundError() => "Channel head meta not found: ${err.message}",
      });
    }
    final head = headResult.getRight().toNullable()!;
    final generationHash = head.generationHash;

    // Write local channel head metadata
    _writeLocalHeadMeta(channelName, head);

    // Fetch and persist all generation-level files independently.
    // Failure of one does not abort the others.
    await _fetchAndPersistBytes(
      fetcher: () => remoteCatalogService.fetchServerIndex(generationHash),
      channelName: channelName,
      path: RepoPaths.channelServerIndexPath(channelName),
    );

    await _fetchAndPersistBytes(
      fetcher: () => remoteCatalogService.fetchGenerationResources(generationHash),
      channelName: channelName,
      path: RepoPaths.channelResourcesPath(channelName),
    );

    await _fetchAndPersistBytes(
      fetcher: () => remoteCatalogService.fetchGenerationPointer(generationHash),
      channelName: channelName,
      path: RepoPaths.channelReleasesPath(channelName),
    );

    return const Right(unit);
  }

  /// Returns the local generation hash for [channelName], or null.
  String? localGenerationHash(String channelName) {
    final path = RepoPaths.channelHeadMetaPath(channelName);
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return json["generationHash"] as String?;
    } on Exception {
      return null;
    }
  }

  /// Reads the local channel registry.
  Option<ChannelRegistry> readLocalChannelRegistry() {
    final file = File(RepoPaths.channelRegistryPath);
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Some(ChannelRegistry.fromJson(json));
    } on Exception {
      return const None();
    }
  }

  /// Reads the ServerIndex protobuf for [channelName].
  ///
  /// Returns [None] if not present locally.
  Option<ServerIndex> readServerIndex(String channelName) {
    final path = RepoPaths.channelServerIndexPath(channelName);
    final file = File(path);
    if (!file.existsSync()) return const None();
    try {
      return Some(ServerIndex.fromBuffer(file.readAsBytesSync()));
    } on Exception {
      return const None();
    }
  }

  /// Reads the channel head metadata for [channelName].
  ///
  /// Returns [None] if not present locally.
  Option<ChannelHeadMeta> readHeadMeta(String channelName) {
    final file = File(RepoPaths.channelHeadMetaPath(channelName));
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Some(ChannelHeadMeta.fromJson(json));
    } on Exception {
      return const None();
    }
  }

  /// Reads the GenerationResources protobuf for [channelName].
  ///
  /// Returns [None] if not present locally.
  Option<GenerationResources> readGenerationResources(String channelName) {
    final path = RepoPaths.channelResourcesPath(channelName);
    final file = File(path);
    if (!file.existsSync()) return const None();
    try {
      return Some(GenerationResources.fromBuffer(file.readAsBytesSync()));
    } on Exception {
      return const None();
    }
  }

  /// Reads the release GenerationPointer protobuf for [channelName].
  ///
  /// Returns [None] if not present locally.
  Option<GenerationPointer> readReleasePointer(String channelName) {
    final path = RepoPaths.channelReleasesPath(channelName);
    final file = File(path);
    if (!file.existsSync()) return const None();
    try {
      return Some(GenerationPointer.fromBuffer(file.readAsBytesSync()));
    } on Exception {
      return const None();
    }
  }

  /// Returns a list of [ServerMeta] entries for [channelName].
  IList<ServerMeta> listServers(String channelName) {
    final si = readServerIndex(channelName);
    if (si.isNone()) return const IList.empty();
    return si
        .toNullable()!
        .servers
        .map(
          (e) => ServerMeta(
            serverId: e.serverId,
            gameBuild: e.gameBuild,
            gameVersion: e.gameVersion,
            name: e.name,
            region: e.hasRegion() ? e.region : null,
            sync: e.hasSync() ? e.sync : null,
            branch: e.hasBranch() ? e.branch : null,
          ),
        )
        .toIList();
  }

  /// Returns `true` if a newer generation is available on remote.
  Future<bool> hasUpdates(String channelName) async {
    final localHash = localGenerationHash(channelName);
    if (localHash == null) return true; // No local state → needs fetch

    final localHead = readHeadMeta(channelName);
    final headResult = await remoteCatalogService.fetchHeadMeta(
      channelName,
      cachedPayload: localHead.isSome() ? localHead.toNullable()!.toJson() : null,
    );
    if (headResult.isLeft()) return false;

    return headResult.getRight().toNullable()!.generationHash != localHash;
  }

  // ── Fetch snapshot hash for a server from a generation ─────────────────────

  /// Fetches the resource snapshot hash for [serverId] in [generationHash].
  Future<Option<String>> resolveSnapshotHash(String generationHash, String serverId) async {
    final result = await remoteCatalogService.fetchGenerationResources(generationHash);
    if (result.isLeft()) return const None();
    final genResources = GenerationResources.fromBuffer(result.getRight().toNullable()!);
    for (final entry in genResources.entries) {
      if (entry.serverId == serverId) return Some(entry.snapshotHash);
    }
    return const None();
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  /// Fetches bytes using [fetcher] and atomically writes them to [path].
  ///
  /// Failures are logged at warning level and do not propagate — the caller
  /// determines whether a particular file is critical.
  Future<void> _fetchAndPersistBytes({
    required Future<Either<CatalogError, Uint8List>> Function() fetcher,
    required String channelName,
    required String path,
  }) async {
    final result = await fetcher();
    if (result.isLeft()) {
      final err = result.getLeft().toNullable()!;
      if (err is CatalogNotFoundError) {
        debug("Generation file not found for $channelName: $path");
      } else if (err is CatalogNotModified) {
        return; // data already cached locally
      } else {
        warning(
          "Failed to fetch generation file for $channelName: ${err is CatalogNetworkError ? err.message : err.toString()}",
        );
      }
      return;
    }
    final bytes = result.getRight().toNullable()!;
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsBytesSync(bytes, flush: true)
        ..renameSync(path);
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write generation file for $channelName: $path", stackTrace: stackTrace);
    }
  }

  void _writeChannelRegistry(ChannelRegistry registry) {
    final path = RepoPaths.channelRegistryPath;
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsStringSync(jsonEncode(registry.toJson()), flush: true)
        ..renameSync(path);
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write channel registry", stackTrace: stackTrace);
    }
  }

  void _writeLocalHeadMeta(String channelName, ChannelHeadMeta head) {
    final path = RepoPaths.channelHeadMetaPath(channelName);
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final json = {
      "schemaVersion": 1,
      "generationHash": head.generationHash,
      "updatedAt": formatTimestamp(DateTime.now().toUtc()),
      "label": head.label.unlock,
    };
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsStringSync(jsonEncode(json), flush: true)
        ..renameSync(path);
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write local head meta for $channelName", stackTrace: stackTrace);
    }
  }

  void _writeServerIndex(String channelName, Uint8List bytes) {
    final path = RepoPaths.channelServerIndexPath(channelName);
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsBytesSync(bytes, flush: true)
        ..renameSync(path);
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write server index for $channelName", stackTrace: stackTrace);
    }
  }
}
