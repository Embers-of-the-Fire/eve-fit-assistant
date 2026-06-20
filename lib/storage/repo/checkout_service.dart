import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/data/proto/checkout_reflog.pb.dart";
import "package:eve_fit_assistant/data/proto/generation_resources.pb.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/data/proto/server_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/checkout_registry_service.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_meta.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/models/snapshot_meta.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/utils.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";
import "package:uuid/uuid.dart";

/// Manages the checkout lifecycle: creation, deletion, switching, reflog, and
/// resource fetch orchestration.
///
/// Follows agent/schemav2/workflow.md §2.3-§2.4.
class CheckoutService {
  const CheckoutService({
    required this.assetStore,
    required this.remoteCatalogService,
    required this.diffEngine,
    required this.checkoutRegistry,
  });

  final AssetStore assetStore;
  final RemoteCatalogService remoteCatalogService;
  final DiffEngine diffEngine;
  final CheckoutRegistryService checkoutRegistry;

  // ── Checkout CRUD ──────────────────────────────────────────────────────────

  /// Creates a new checkout for [channel], [serverId], and [name].
  ///
  /// Returns the new checkout UUID.
  Future<Option<String>> createCheckout({
    required Channel channel,
    required String serverId,
    required IMap<String, String> name,
    required String generationHash,
    required String resourceSnapshotHash,
  }) async {
    final checkoutId = const Uuid().v4();
    final now = formatTimestamp(DateTime.now().toUtc());

    // Look up server metadata from the local server index
    String gameBuild = "";
    String gameVersion = "";
    String region = "";
    String sync = "";
    String branch = "";
    try {
      final siPath = RepoPaths.channelServerIndexPath(channel.value);
      final siFile = File(siPath);
      if (siFile.existsSync()) {
        final si = ServerIndex.fromBuffer(siFile.readAsBytesSync());
        for (final entry in si.servers) {
          if (entry.serverId == serverId) {
            gameBuild = entry.gameBuild;
            gameVersion = entry.gameVersion;
            if (entry.hasRegion()) region = entry.region;
            if (entry.hasSync()) sync = entry.sync;
            if (entry.hasBranch()) branch = entry.branch;
            break;
          }
        }
      }
    } on Exception {
      // Best-effort: keep defaults if server index is unavailable
    }

    // Write checkout metadata
    final meta = CheckoutMeta(
      schemaVersion: 1,
      channel: channel.value,
      resourceSnapshotHash: resourceSnapshotHash,
      serverId: serverId,
      name: name,
      createdAt: now,
      gameBuild: gameBuild,
      gameVersion: gameVersion,
      region: region,
      sync: sync,
      branch: branch,
    );
    if (!_writeCheckoutMeta(checkoutId, meta)) {
      warning("Failed to write checkout metadata for $checkoutId");
      return const None();
    }

    // Write initial reflog entry
    _appendCheckoutReflog(checkoutId, "", resourceSnapshotHash, now);

    // Add to registry
    final entry = CheckoutRegistryEntry(
      channel: channel.value,
      serverId: serverId,
      resourceSnapshotHash: resourceSnapshotHash,
      name: name,
      createdAt: now,
    );
    await checkoutRegistry.addCheckout(checkoutId: checkoutId, entry: entry);

    return Some(checkoutId);
  }

  /// Deletes a checkout and its directory.
  Future<void> deleteCheckout(String checkoutId) async {
    await checkoutRegistry.removeCheckout(checkoutId);

    final dir = Directory("${RepoPaths.checkoutsPath}/$checkoutId");
    if (dir.existsSync()) {
      try {
        dir.deleteSync(recursive: true);
      } on FileSystemException catch (e, stackTrace) {
        warning("Failed to delete checkout directory $checkoutId", stackTrace: stackTrace);
      }
    }
  }

  /// Reads a checkout's metadata.
  Option<CheckoutMeta> readCheckoutMeta(String checkoutId) {
    final path = RepoPaths.checkoutMetaPath(checkoutId);
    final file = File(path);
    if (!file.existsSync()) return const None();
    try {
      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      return Some(CheckoutMeta.fromJson(json));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read checkout metadata $checkoutId", stackTrace: stackTrace);
      return const None();
    }
  }

  /// Reads a checkout's reflog.
  Option<CheckoutReflog> readCheckoutReflog(String checkoutId) {
    final path = RepoPaths.checkoutReflogPath(checkoutId);
    final file = File(path);
    if (!file.existsSync()) return const None();
    try {
      return Some(CheckoutReflog.fromBuffer(file.readAsBytesSync()));
    } on Exception catch (e, stackTrace) {
      warning("Failed to read checkout reflog $checkoutId", stackTrace: stackTrace);
      return const None();
    }
  }

  /// Returns all resource snapshot hashes referenced by this checkout's reflog
  /// (historical and current).
  Set<String> collectReflogSnapshotHashes(String checkoutId) {
    final hashes = <String>{};
    final meta = readCheckoutMeta(checkoutId);
    if (meta.isSome()) {
      hashes.add(meta.toNullable()!.resourceSnapshotHash);
    }
    final reflog = readCheckoutReflog(checkoutId);
    if (reflog.isSome()) {
      for (final entry in reflog.toNullable()!.entries) {
        if (entry.from.isNotEmpty) hashes.add(entry.from);
        if (entry.to.isNotEmpty) hashes.add(entry.to);
      }
    }
    return hashes;
  }

  // ── Resource Fetch Pipeline (spec §13.2) ───────────────────────────────────

  /// Fetches the resource snapshot for the active checkout.
  ///
  /// Steps:
  /// 1. Check for remote generation update
  /// 2. If updated, fetch new generation data
  /// 3. Download changed blobs
  /// 4. Write new resource snapshot locally
  /// 5. Update channel metadata and checkout metadata
  Future<Option<String>> fetchResourcesForCheckout({
    required String checkoutId,
    required Channel channel,
    required String channelName,
  }) async {
    final meta = readCheckoutMeta(checkoutId);
    if (meta.isNone()) return const None();

    final m = meta.toNullable()!;

    // Step 1: Check remote head for update
    final headResult = await remoteCatalogService.fetchHeadMeta(channelName);
    if (headResult.isLeft()) return const None();
    final remoteHead = headResult.getRight().toNullable()!;

    final remoteLabel = Map<String, String>.from(remoteHead.label.unlock);

    // Read local channel meta to compare
    final currentGenHash = _readLocalGenerationHash(channelName);
    if (currentGenHash == remoteHead.generationHash) {
      // No update
      return const None();
    }

    final newGenerationHash = remoteHead.generationHash;

    // Step 2: Fetch generation resources to get the snapshot hash for our server
    final genResourcesBytes = await remoteCatalogService.fetchGenerationResources(
      newGenerationHash,
    );
    if (genResourcesBytes.isLeft()) return const None();
    final genResources = GenerationResources.fromBuffer(genResourcesBytes.getRight().toNullable()!);

    // Find our server's snapshot hash
    String? newSnapshotHash;
    for (final entry in genResources.entries) {
      if (entry.serverId == m.serverId) {
        newSnapshotHash = entry.snapshotHash;
        break;
      }
    }
    if (newSnapshotHash == null) return const None();

    // If same resource snapshot, skip blob download but update metadata
    if (newSnapshotHash == m.resourceSnapshotHash) {
      await _updateAfterFetch(
        checkoutId,
        channelName,
        m,
        newGenerationHash,
        m.resourceSnapshotHash,
        label: remoteLabel,
      );
      return Some(m.resourceSnapshotHash);
    }

    // Step 3: Fetch the new ResourceIndex
    final indexBytes = await remoteCatalogService.fetchResourceIndex(newSnapshotHash);
    if (indexBytes.isLeft()) return const None();
    final newIndex = ResourceIndex.fromBuffer(indexBytes.getRight().toNullable()!);

    // Step 4: Load previous ResourceIndex if it exists, diff, download changed blobs
    final previousIndex = assetStore.readResourceIndexSync(m.resourceSnapshotHash);
    final entriesToDownload = <({String resourceId, String contentHash})>[];
    if (previousIndex.isNone()) {
      // Full download — all entries
      for (final entry in newIndex.entries) {
        entriesToDownload.add((resourceId: entry.resourceId, contentHash: entry.contentHash));
      }
    } else {
      // Incremental — only changed entries
      final prevMap = <String, String>{};
      for (final e in previousIndex.toNullable()!.entries) {
        prevMap[e.resourceId] = e.contentHash;
      }
      for (final e in newIndex.entries) {
        final prevHash = prevMap[e.resourceId];
        if (prevHash == null || prevHash != e.contentHash) {
          entriesToDownload.add((resourceId: e.resourceId, contentHash: e.contentHash));
        }
      }
    }

    // Download changed blobs
    for (final dl in entriesToDownload) {
      final ihash = RepoHash.hashIdent(dl.resourceId);
      if (assetStore.blobExistsSync(ihash, dl.contentHash)) continue;
      final blobResult = await remoteCatalogService.fetchBlob(ihash, dl.contentHash);
      if (blobResult.isRight()) {
        assetStore.writeBlobSync(ihash, blobResult.getRight().toNullable()!);
      } else {
        warning("Failed to fetch blob $ihash/${dl.contentHash}");
      }
    }

    // Step 5: Write new resource snapshot locally
    final metaResult = await remoteCatalogService.fetchResourceSnapshotMeta(newSnapshotHash);
    final snapshotMeta = metaResult.isRight()
        ? metaResult.getRight().toNullable()!
        : ResourceSnapshotMeta(
            schemaVersion: 1,
            serverId: m.serverId,
            gameBuild: m.gameBuild,
            gameVersion: m.gameVersion,
            gameRegion: m.region,
            gameSync: m.sync,
            gameBranch: m.branch,
            resourceCount: newIndex.entries.length,
            createdAt: formatTimestamp(DateTime.now().toUtc()),
          );
    final localSnapshotHash = assetStore.writeResourceSnapshotSync(
      meta: snapshotMeta,
      resourceIndex: newIndex,
    );

    // Step 6: Fetch and write server index
    final serverIndexBytes = await remoteCatalogService.fetchServerIndex(newGenerationHash);
    if (serverIndexBytes.isRight()) {
      _writeServerIndex(channelName, serverIndexBytes.getRight().toNullable()!);
    }

    // Step 7: Update metadata
    await _updateAfterFetch(
      checkoutId,
      channelName,
      m,
      newGenerationHash,
      localSnapshotHash,
      label: remoteLabel,
    );

    return Some(localSnapshotHash);
  }

  // ── Revert (spec §2.8) ─────────────────────────────────────────────────────

  /// Reverts a checkout to a previous resource snapshot.
  ///
  /// The target snapshot must have been previously fetched (present in reflog).
  /// Does NOT modify the reflog — it is an append-only history of fetch
  /// transitions, not user actions (spec §2.8).
  Future<Option<String>> revertCheckoutTo(String checkoutId, String targetSnapshotHash) async {
    final meta = readCheckoutMeta(checkoutId);
    if (meta.isNone()) return const None();

    final m = meta.toNullable()!;

    final updated = m.copyWith(resourceSnapshotHash: targetSnapshotHash);
    if (!_writeCheckoutMeta(checkoutId, updated)) {
      return const None();
    }

    // Update registry entry
    final registry = checkoutRegistry.readRegistry();
    if (registry.isSome()) {
      final r = registry.toNullable()!;
      final existing = r.checkouts[checkoutId];
      if (existing != null) {
        final updatedEntry = existing.copyWith(resourceSnapshotHash: targetSnapshotHash);
        await checkoutRegistry.writeRegistry(
          r.copyWith(checkouts: r.checkouts.add(checkoutId, updatedEntry)),
        );
      }
    }

    return Some(targetSnapshotHash);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  bool _writeCheckoutMeta(String checkoutId, CheckoutMeta meta) {
    final path = RepoPaths.checkoutMetaPath(checkoutId);
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsStringSync(jsonEncode(meta.toJson()), flush: true)
        ..renameSync(path);
      return true;
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write checkout meta $checkoutId", stackTrace: stackTrace);
      return false;
    }
  }

  void _appendCheckoutReflog(
    String checkoutId,
    String fromSnapshotHash,
    String toSnapshotHash,
    String timestamp,
  ) {
    final path = RepoPaths.checkoutReflogPath(checkoutId);
    final existing = readCheckoutReflog(
      checkoutId,
    ).getOrElse(() => CheckoutReflog(schemaVersion: 1));

    final entry = CheckoutReflog_Entry()
      ..from = fromSnapshotHash
      ..to = toSnapshotHash
      ..timestamp = timestamp;

    final updated = existing.deepCopy()..entries.add(entry);

    if (!File(path).parent.existsSync()) {
      File(path).parent.createSync(recursive: true);
    }
    writeProtobufSync(path, updated);
  }

  String? _readLocalGenerationHash(String channelName) {
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

  Future<void> _updateAfterFetch(
    String checkoutId,
    String channelName,
    CheckoutMeta oldMeta,
    String newGenerationHash,
    String newSnapshotHash, {
    Map<String, String>? label,
  }) async {
    final now = formatTimestamp(DateTime.now().toUtc());

    // Update channel head metadata
    _writeChannelHeadMeta(channelName, newGenerationHash, now, label: label);

    // Update checkout metadata
    final updatedMeta = oldMeta.copyWith(resourceSnapshotHash: newSnapshotHash);
    _writeCheckoutMeta(checkoutId, updatedMeta);

    // Append reflog entry
    _appendCheckoutReflog(checkoutId, oldMeta.resourceSnapshotHash, newSnapshotHash, now);

    // Update registry
    final registry = checkoutRegistry.readRegistry();
    if (registry.isSome()) {
      final r = registry.toNullable()!;
      final existing = r.checkouts[checkoutId];
      if (existing != null) {
        final updatedEntry = existing.copyWith(resourceSnapshotHash: newSnapshotHash);
        await checkoutRegistry.writeRegistry(
          r.copyWith(checkouts: r.checkouts.add(checkoutId, updatedEntry)),
        );
      }
    }
  }

  void _writeChannelHeadMeta(
    String channelName,
    String generationHash,
    String updatedAt, {
    Map<String, String>? label,
  }) {
    final path = RepoPaths.channelHeadMetaPath(channelName);
    final file = File(path);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final json = <String, dynamic>{
      "schemaVersion": 1,
      "generationHash": generationHash,
      "updatedAt": updatedAt,
    };
    if (label != null && label.isNotEmpty) {
      json["label"] = label;
    }
    final tmp = File("$path.tmp");
    try {
      tmp
        ..writeAsStringSync(jsonEncode(json), flush: true)
        ..renameSync(path);
    } on FileSystemException catch (e, stackTrace) {
      warning("Failed to write channel head meta for $channelName", stackTrace: stackTrace);
    }
  }
}
