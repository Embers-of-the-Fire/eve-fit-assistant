import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
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
    final result = await remoteCatalogService.fetchChannelRegistry();
    if (result.isLeft()) {
      final err = result.getLeft().toNullable()!;
      return Left(err is CatalogNetworkError ? err.message : "Failed to fetch channels");
    }
    final remoteRegistry = result.getRight().toNullable()!;

    // Write locally
    _writeChannelRegistry(remoteRegistry);

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
      return Left(err is CatalogNetworkError ? err.message : "Failed to fetch channel info");
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
