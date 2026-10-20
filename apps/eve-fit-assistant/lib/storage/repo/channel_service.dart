import "dart:convert";
import "dart:typed_data";

import "package:efa_proto/generation_pointer.pb.dart";
import "package:efa_proto/generation_resources.pb.dart";
import "package:efa_proto/server_history.pb.dart";
import "package:efa_proto/server_index.pb.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/storage/fs/blob_store.dart";
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
///
/// All local persistence goes through a [BlobStore], so every read/write is
/// asynchronous (OPFS on web is async-only).
class ChannelService {
  const ChannelService({required this.remoteCatalogService, required BlobStore store})
    // ignore: prefer_initializing_formals
    : _store = store;

  final RemoteCatalogService remoteCatalogService;
  final BlobStore _store;

  /// Fetches and persists the channel registry from remote.
  ///
  /// On first launch, uses defaultChannel from the remote.
  Future<Either<String, ChannelRegistry>> discoverChannels() async {
    final result = await remoteCatalogService.fetchChannelRegistry();
    if (result.isLeft()) {
      final err = result.getLeft().toNullable()!;
      return Left(switch (err) {
        CatalogNetworkError() => "Network error fetching channels: ${err.message}",
        CatalogNotFoundError() => "Channel registry not found: ${err.message}",
        CatalogParseError() => "Failed to parse channel registry: ${err.message}",
      });
    }
    final remoteRegistry = result.getRight().toNullable()!;

    // Write locally
    await _writeChannelRegistry(remoteRegistry);

    return Right(remoteRegistry);
  }

  /// Fetches and persists channel head metadata and server index for [channelName].
  Future<Either<String, Unit>> fetchChannelInfo(String channelName) async {
    // Fetch head metadata
    final headResult = await remoteCatalogService.fetchHeadMeta(channelName);
    if (headResult.isLeft()) {
      final err = headResult.getLeft().toNullable()!;
      if (err is CatalogNotFoundError) {
        return const Right(unit); // Channel not yet initialized on remote
      }
      return Left(switch (err) {
        CatalogNetworkError() => "Network error fetching channel info: ${err.message}",
        CatalogParseError() => "Failed to parse channel info: ${err.message}",
        CatalogNotFoundError() => "Channel info not found: ${err.message}",
      });
    }
    final head = headResult.getRight().toNullable()!;

    // Write local channel head metadata
    await _writeLocalHeadMeta(channelName, head);

    // Fetch and write server index
    final serverResult = await remoteCatalogService.fetchServerIndex(head.generationHash);
    if (serverResult.isRight()) {
      await _writeServerIndex(channelName, serverResult.getRight().toNullable()!);
    }

    return const Right(unit);
  }

  /// Fetches and persists all generation-level files for [channelName].
  ///
  /// Every generation file is required: the new channel head metadata is
  /// published only after all of them persist. If any fetch or write fails,
  /// the previous head stays in place and the sync returns a [Left], so
  /// later reads never pair the new generation hash with stale resources or
  /// history. The only tolerated absence is a missing channel head (channel
  /// not yet initialized on remote).
  ///
  /// Persisted files:
  /// - channels/{channel}/metadata.json   — channel head metadata (written last)
  /// - channels/{channel}/server.pb2      — ServerIndex
  /// - channels/{channel}/resources.pb2   — GenerationResources
  /// - channels/{channel}/releases.pb2    — GenerationPointer (releases)
  /// - channels/{channel}/history.pb2     — ServerHistory (promoted history)
  Future<Either<String, Unit>> syncChannelGeneration(
    String channelName, {
    void Function(int current, int total)? onProgress,
  }) async {
    const totalSteps = 5;
    onProgress?.call(0, totalSteps);

    // Fetch head metadata to get the generation hash
    final headResult = await remoteCatalogService.fetchHeadMeta(channelName);
    if (headResult.isLeft()) {
      final err = headResult.getLeft().toNullable()!;
      if (err is CatalogNotFoundError) {
        onProgress?.call(totalSteps, totalSteps);
        return const Right(unit); // Channel not yet initialized on remote
      }
      return Left(switch (err) {
        CatalogNetworkError() => "Network error fetching channel head meta: ${err.message}",
        CatalogParseError() => "Failed to parse channel head meta: ${err.message}",
        CatalogNotFoundError() => "Channel head meta not found: ${err.message}",
      });
    }
    final head = headResult.getRight().toNullable()!;
    final generationHash = head.generationHash;
    onProgress?.call(1, totalSteps);

    // Fetch and persist every required generation file before publishing the
    // new head. A partial sync must keep the previous head in place so no
    // reader can observe the new generation hash alongside stale files.
    final requiredFiles = [
      (
        label: "server index",
        fetcher: () => remoteCatalogService.fetchServerIndex(generationHash),
        path: RepoPaths.channelServerIndexPath(channelName),
      ),
      (
        label: "generation resources",
        fetcher: () => remoteCatalogService.fetchGenerationResources(generationHash),
        path: RepoPaths.channelResourcesPath(channelName),
      ),
      (
        label: "release pointer",
        fetcher: () => remoteCatalogService.fetchGenerationPointer(generationHash),
        path: RepoPaths.channelReleasesPath(channelName),
      ),
      (
        label: "server history",
        fetcher: () => remoteCatalogService.fetchServerHistory(generationHash),
        path: RepoPaths.channelHistoryPath(channelName),
      ),
    ];

    var step = 1;
    for (final file in requiredFiles) {
      final error = await _fetchAndPersistBytes(
        fetcher: file.fetcher,
        channelName: channelName,
        path: file.path,
        label: file.label,
      );
      step += 1;
      onProgress?.call(step, totalSteps);
      if (error != null) return Left(error);
    }

    // Publish the new head only after every generation file persisted.
    await _writeLocalHeadMeta(channelName, head);

    return const Right(unit);
  }

  /// Returns the local generation hash for [channelName], or null.
  Future<String?> localGenerationHash(String channelName) async {
    final bytes = await _store.read(RepoPaths.channelHeadMetaPath(channelName));
    if (bytes == null) return null;
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return json["generationHash"] as String?;
    } on Exception {
      return null;
    }
  }

  /// Reads the local channel registry.
  Future<Option<ChannelRegistry>> readLocalChannelRegistry() async {
    final bytes = await _store.read(RepoPaths.channelRegistryPath);
    if (bytes == null) return const None();
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return Some(ChannelRegistry.fromJson(json));
    } on Exception {
      return const None();
    }
  }

  /// Reads the ServerIndex protobuf for [channelName].
  ///
  /// Returns [None] if not present locally.
  Future<Option<ServerIndex>> readServerIndex(String channelName) async {
    final bytes = await _store.read(RepoPaths.channelServerIndexPath(channelName));
    if (bytes == null) return const None();
    try {
      return Some(ServerIndex.fromBuffer(bytes));
    } on Exception {
      return const None();
    }
  }

  /// Reads the channel head metadata for [channelName].
  ///
  /// Returns [None] if not present locally.
  Future<Option<ChannelHeadMeta>> readHeadMeta(String channelName) async {
    final bytes = await _store.read(RepoPaths.channelHeadMetaPath(channelName));
    if (bytes == null) return const None();
    try {
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      return Some(ChannelHeadMeta.fromJson(json));
    } on Exception {
      return const None();
    }
  }

  /// Reads the GenerationResources protobuf for [channelName].
  ///
  /// Returns [None] if not present locally.
  Future<Option<GenerationResources>> readGenerationResources(String channelName) async {
    final bytes = await _store.read(RepoPaths.channelResourcesPath(channelName));
    if (bytes == null) return const None();
    try {
      return Some(GenerationResources.fromBuffer(bytes));
    } on Exception {
      return const None();
    }
  }

  /// Reads the release GenerationPointer protobuf for [channelName].
  ///
  /// Returns [None] if not present locally.
  Future<Option<GenerationPointer>> readReleasePointer(String channelName) async {
    final bytes = await _store.read(RepoPaths.channelReleasesPath(channelName));
    if (bytes == null) return const None();
    try {
      return Some(GenerationPointer.fromBuffer(bytes));
    } on Exception {
      return const None();
    }
  }

  /// Reads the ServerHistory protobuf for [channelName].
  ///
  /// Returns [None] if not present locally.
  Future<Option<ServerHistory>> readServerHistory(String channelName) async {
    final bytes = await _store.read(RepoPaths.channelHistoryPath(channelName));
    if (bytes == null) return const None();
    try {
      return Some(ServerHistory.fromBuffer(bytes));
    } on Exception {
      return const None();
    }
  }

  /// Returns a list of [ServerMeta] entries for [channelName].
  Future<IList<ServerMeta>> listServers(String channelName) async {
    final si = await readServerIndex(channelName);
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
    final localHash = await localGenerationHash(channelName);
    if (localHash == null) return true; // No local state → needs fetch

    final headResult = await remoteCatalogService.fetchHeadMeta(channelName);
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
  /// Returns an error message when the fetch or the write fails, and null on
  /// success. The caller decides whether the failure aborts the operation.
  Future<String?> _fetchAndPersistBytes({
    required Future<Either<CatalogError, Uint8List>> Function() fetcher,
    required String channelName,
    required String path,
    required String label,
  }) async {
    final result = await fetcher();
    if (result.isLeft()) {
      final err = result.getLeft().toNullable()!;
      return switch (err) {
        CatalogNetworkError() => "Network error fetching $label for $channelName: ${err.message}",
        CatalogParseError() => "Failed to parse $label for $channelName: ${err.message}",
        CatalogNotFoundError() => "$label not found for $channelName: ${err.message}",
      };
    }
    final bytes = result.getRight().toNullable()!;
    try {
      await _store.write(path, bytes);
    } catch (e, stackTrace) {
      warning("Failed to write $label for $channelName: $path", stackTrace: stackTrace);
      return "Failed to write $label for $channelName";
    }
    return null;
  }

  Future<void> _writeChannelRegistry(ChannelRegistry registry) async {
    try {
      await _store.write(
        RepoPaths.channelRegistryPath,
        Uint8List.fromList(utf8.encode(jsonEncode(registry.toJson()))),
      );
    } catch (e, stackTrace) {
      warning("Failed to write channel registry", stackTrace: stackTrace);
    }
  }

  Future<void> _writeLocalHeadMeta(String channelName, ChannelHeadMeta head) async {
    final json = {
      "schemaVersion": 1,
      "generationHash": head.generationHash,
      "updatedAt": formatTimestamp(DateTime.now().toUtc()),
      "label": head.label.unlock,
    };
    try {
      await _store.write(
        RepoPaths.channelHeadMetaPath(channelName),
        Uint8List.fromList(utf8.encode(jsonEncode(json))),
      );
    } catch (e, stackTrace) {
      warning("Failed to write local head meta for $channelName", stackTrace: stackTrace);
    }
  }

  Future<void> _writeServerIndex(String channelName, Uint8List bytes) async {
    try {
      await _store.write(RepoPaths.channelServerIndexPath(channelName), bytes);
    } catch (e, stackTrace) {
      warning("Failed to write server index for $channelName", stackTrace: stackTrace);
    }
  }
}
