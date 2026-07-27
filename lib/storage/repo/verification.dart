import "dart:io";
import "dart:isolate";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/checkout_registry_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/utils.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";

/// Represents a single integrity issue found during verification.
sealed class VerificationIssue {
  const VerificationIssue({required this.checkoutId});

  final String checkoutId;
}

class VerificationMissingFiles extends VerificationIssue {
  const VerificationMissingFiles({
    required super.checkoutId,
    required this.snapshotHash,
    required this.missingIdents,
  });

  final String snapshotHash;
  final IList<String> missingIdents;
}

class VerificationNoMeta extends VerificationIssue {
  const VerificationNoMeta({required super.checkoutId});
}

class VerificationPartialDownload extends VerificationIssue {
  const VerificationPartialDownload({required super.checkoutId, required this.reason});

  final String reason;
}

/// Verifies local integrity, repairs interrupted operations, and prunes
/// unreferenced data.
///
/// Follows agent/schemav2/workflow.md §2.7 (Client GC) and §3.7 (Verification).
class VerificationService {
  VerificationService({
    required this.checkoutService,
    required this.assetStore,
    required this.checkoutRegistry,
    required this.remoteCatalogService,
  });

  final CheckoutService checkoutService;
  final AssetStore assetStore;
  final CheckoutRegistryService checkoutRegistry;
  final RemoteCatalogService remoteCatalogService;

  bool _running = false;

  bool get isRunning => _running;

  void _acquire() {
    if (_running) {
      throw StateError("A verification operation is already in progress");
    }
    _running = true;
  }

  void _release() {
    _running = false;
  }

  /// Verifies every checkout's resource snapshot integrity.
  ///
  /// Checks that ResourceIndex protobuf files exist and verifies blob integrity.
  /// Returns a list of issues found. An empty list means all checkouts are intact.
  ///
  /// Throws [StateError] if another verification operation is already running.
  IList<VerificationIssue> verify() {
    _acquire();
    try {
      return _verifyInternal();
    } finally {
      _release();
    }
  }

  /// Async variant of [verify] that runs the heavy I/O in a background isolate,
  /// keeping the UI thread responsive.
  ///
  /// [onProgress] receives (checked, total) blob counts as verification proceeds.
  ///
  /// Throws [StateError] if another verification operation is already running.
  Future<IList<VerificationIssue>> verifyAsync({
    void Function(int current, int total)? onProgress,
  }) async {
    _acquire();
    try {
      final paths = _capturePaths();
      if (onProgress == null) {
        return await _spawnVerify(paths, null);
      }
      final receivePort = ReceivePort()
        ..listen((message) {
          if (message is List && message.length == 2 && message[0] is int) {
            onProgress(message[0] as int, message[1] as int);
          }
        });
      final sendPort = receivePort.sendPort;
      try {
        return await _spawnVerify(paths, sendPort);
      } finally {
        receivePort.close();
      }
    } finally {
      _release();
    }
  }

  /// Async variant of [prune] that runs the heavy I/O in a background isolate,
  /// keeping the UI thread responsive.
  ///
  /// [onProgress] receives (deleted, total-scanned) item counts as pruning proceeds.
  ///
  /// Throws [StateError] if another verification operation is already running.
  Future<int> pruneAsync({void Function(int current, int total)? onProgress}) async {
    _acquire();
    try {
      final paths = _capturePaths();
      if (onProgress == null) {
        return await _spawnPrune(paths, null);
      }
      final receivePort = ReceivePort()
        ..listen((message) {
          if (message is List && message.length == 2 && message[0] is int) {
            onProgress(message[0] as int, message[1] as int);
          }
        });
      final sendPort = receivePort.sendPort;
      try {
        return await _spawnPrune(paths, sendPort);
      } finally {
        receivePort.close();
      }
    } finally {
      _release();
    }
  }

  IList<VerificationIssue> _verifyInternal() {
    final registry = checkoutRegistry.readRegistry();
    if (registry.isNone()) return const IList.empty();

    final issues = <VerificationIssue>[];

    for (final entry in registry.toNullable()!.checkouts.entries) {
      final checkoutId = entry.key;
      final checkoutEntry = entry.value;

      final meta = checkoutService.readCheckoutMeta(checkoutId);
      if (meta.isNone()) {
        issues.add(VerificationNoMeta(checkoutId: checkoutId));
        continue;
      }

      final snapshotHash = checkoutEntry.resourceSnapshotHash;
      final ri = assetStore.readResourceIndexSync(snapshotHash);
      if (ri.isNone()) {
        issues.add(
          VerificationMissingFiles(
            checkoutId: checkoutId,
            snapshotHash: snapshotHash,
            missingIdents: const IList.empty(),
          ),
        );
        continue;
      }

      final missing = assetStore.verifyResourceIndexSync(ri.toNullable()!);
      if (missing.isNotEmpty) {
        issues.add(
          VerificationMissingFiles(
            checkoutId: checkoutId,
            snapshotHash: snapshotHash,
            missingIdents: missing,
          ),
        );
      }
    }

    return issues.toIList();
  }

  /// Prunes unreferenced data.
  ///
  /// Follows spec §12.2 client deletion rules:
  /// 1. Collect reachable snapshot hashes from all checkouts and reflogs
  /// 2. Collect referenced blobs from reachable ResourceIndexes
  /// 3. Delete unreferenced snapshots, blobs, empty dirs, tmp dirs
  ///
  /// Returns the total number of items pruned.
  ///
  /// Throws [StateError] if another verification operation is already running.
  int prune() {
    _acquire();
    try {
      return _pruneInternal();
    } finally {
      _release();
    }
  }

  int _pruneInternal() {
    final registry = checkoutRegistry.readRegistry();
    if (registry.isNone()) return 0;

    final activeSnapshotHashes = <String>{};
    final activeResourceIndexes = <ResourceIndex>[];

    for (final entry in registry.toNullable()!.checkouts.entries) {
      final checkoutEntry = entry.value;

      // From checkout metadata
      activeSnapshotHashes.add(checkoutEntry.resourceSnapshotHash);

      // From reflog
      final reflogHashes = CheckoutService.collectReflogSnapshotHashes(entry.key);
      activeSnapshotHashes.addAll(reflogHashes);

      // Load ResourceIndex for current snapshot
      final ri = assetStore.readResourceIndexSync(checkoutEntry.resourceSnapshotHash);
      if (ri.isSome()) {
        activeResourceIndexes.add(ri.toNullable()!);
      }
      // Also load for historical snapshots from reflog
      for (final hash in reflogHashes) {
        if (hash == checkoutEntry.resourceSnapshotHash) continue;
        final histRi = assetStore.readResourceIndexSync(hash);
        if (histRi.isSome()) {
          activeResourceIndexes.add(histRi.toNullable()!);
        }
      }
    }

    return assetStore.pruneSync(
      activeSnapshotHashes: activeSnapshotHashes,
      activeResourceIndexes: activeResourceIndexes,
    );
  }

  /// Repairs missing files by re-downloading from remote.
  ///
  /// [onProgress] receives (downloaded, total) blob counts as downloads proceed.
  ///
  /// Returns unresolved issues (partial downloads or network failures).
  ///
  /// Throws [StateError] if another verification operation is already running.
  Future<IList<VerificationIssue>> repairAll({
    required Channel channel,
    void Function(int current, int total)? onProgress,
  }) async {
    _acquire();
    try {
      return await _repairAllInternal(channel: channel, onProgress: onProgress);
    } finally {
      _release();
    }
  }

  Future<IList<VerificationIssue>> _repairAllInternal({
    required Channel channel,
    void Function(int current, int total)? onProgress,
  }) async {
    final issues = _verifyInternal();
    final unresolved = <VerificationIssue>[];

    final toRepair =
        <
          ({
            String resourceId,
            String contentHash,
            String identHash,
            String blobPath,
            String snapshotHash,
            String checkoutId,
          })
        >[];

    for (final issue in issues) {
      if (issue is VerificationMissingFiles) {
        final ri = assetStore.readResourceIndexSync(issue.snapshotHash);
        if (ri.isNone()) {
          unresolved.add(issue);
          continue;
        }
        for (final resourceId in issue.missingIdents) {
          final entry = ri
              .toNullable()!
              .entries
              .where((e) => e.resourceId == resourceId)
              .firstOrNull;
          if (entry == null) {
            unresolved.add(issue);
            continue;
          }
          final ihash = RepoHash.hashIdent(resourceId);
          toRepair.add((
            resourceId: resourceId,
            contentHash: entry.contentHash,
            identHash: ihash,
            blobPath: RepoPaths.blobPath(ihash, entry.contentHash),
            snapshotHash: issue.snapshotHash,
            checkoutId: issue.checkoutId,
          ));
        }
      } else if (issue is VerificationNoMeta) {
        unresolved.add(issue);
      } else if (issue is VerificationPartialDownload) {
        unresolved.add(issue);
      }
    }

    const blobConcurrency = kBlobDownloadConcurrency;
    var nextIdx = 0;
    var completed = 0;
    final totalToRepair = toRepair.length;

    if (toRepair.isNotEmpty) {
      onProgress?.call(0, totalToRepair);
      assetStore.ensureBlobIdentDirs(toRepair.map((r) => r.identHash));

      Future<void> repairNext() async {
        int idx;
        while ((idx = nextIdx++) < toRepair.length) {
          final item = toRepair[idx];
          final blobResult = await remoteCatalogService.fetchBlob(item.identHash, item.contentHash);
          if (blobResult.isRight()) {
            try {
              await assetStore.writeBlobUncheckedAt(
                item.blobPath,
                blobResult.getRight().toNullable()!,
              );
            } on FileSystemException {
              unresolved.add(
                VerificationMissingFiles(
                  checkoutId: item.checkoutId,
                  snapshotHash: item.snapshotHash,
                  missingIdents: [item.resourceId].toIList(),
                ),
              );
            }
          } else {
            unresolved.add(
              VerificationMissingFiles(
                checkoutId: item.checkoutId,
                snapshotHash: item.snapshotHash,
                missingIdents: [item.resourceId].toIList(),
              ),
            );
          }
          completed++;
          onProgress?.call(completed, totalToRepair);
        }
      }

      final tasks = <Future<void>>[
        for (var i = 0; i < blobConcurrency.clamp(1, toRepair.length); i++) repairNext(),
      ];
      await Future.wait(tasks);
    }

    return unresolved.toIList();
  }
}

extension _WhereFirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    for (final item in this) {
      return item;
    }
    return null;
  }
}

// ── Isolate spawn helpers ──────────────────────────────────────────────────────
// Separate top-level functions so the Isolate.run() closure is created in a
// scope that does NOT share a Context with the onProgress listener (which
// captures the widget State). Without this separation, Dart's closure context
// sharing drags the entire widget tree into the isolate message.

typedef _IsolatePaths = ({
  String appSupport,
  String logs,
  String documents,
  String temp,
  String caches,
  String? downloads,
});

void _seedPaths(_IsolatePaths paths) {
  PathProvider.appSupportPath = paths.appSupport;
  PathProvider.documentsPath = paths.documents;
  PathProvider.tempPath = paths.temp;
  PathProvider.cachesPath = paths.caches;
  PathProvider.downloadsPath = paths.downloads;
}

_IsolatePaths _capturePaths() => (
  appSupport: PathProvider.appSupportPath,
  logs: PathProvider.logsPath,
  documents: PathProvider.documentsPath,
  temp: PathProvider.tempPath,
  caches: PathProvider.cachesPath,
  downloads: PathProvider.downloadsPath,
);

Future<IList<VerificationIssue>> _spawnVerify(_IsolatePaths paths, SendPort? sendPort) =>
    Isolate.run(() => _isolateVerify(paths, sendPort));

Future<int> _spawnPrune(_IsolatePaths paths, SendPort? sendPort) =>
    Isolate.run(() => _isolatePrune(paths, sendPort));

// ── Isolate entry points ───────────────────────────────────────────────────────
// Top-level functions so they can be sent to Isolate.run(). They reconstruct
// the minimal stateless services from the passed paths.

IList<VerificationIssue> _isolateVerify(_IsolatePaths paths, SendPort? progress) {
  _seedPaths(paths);
  GlobalLogger.init(paths.logs, enableDebugLog: false);

  const assetStore = AssetStore();
  final registryService = CheckoutRegistryService();

  final registry = registryService.readRegistry();
  if (registry.isNone()) return const IList.empty();

  final checkouts = registry.toNullable()!.checkouts.entries.toList();

  var totalBlobs = 0;
  final resourceIndexes = <String, ResourceIndex>{};
  for (final entry in checkouts) {
    final ri = assetStore.readResourceIndexSync(entry.value.resourceSnapshotHash);
    if (ri.isSome()) {
      resourceIndexes[entry.key] = ri.toNullable()!;
      totalBlobs += ri.toNullable()!.entries.length;
    }
  }

  final issues = <VerificationIssue>[];
  var checkedOffset = 0;

  for (final entry in checkouts) {
    final checkoutId = entry.key;
    final checkoutEntry = entry.value;

    final metaFile = File(RepoPaths.checkoutMetaPath(checkoutId));
    if (!metaFile.existsSync()) {
      issues.add(VerificationNoMeta(checkoutId: checkoutId));
      continue;
    }

    final snapshotHash = checkoutEntry.resourceSnapshotHash;
    final ri = resourceIndexes[checkoutId];
    if (ri == null) {
      issues.add(
        VerificationMissingFiles(
          checkoutId: checkoutId,
          snapshotHash: snapshotHash,
          missingIdents: const IList.empty(),
        ),
      );
      continue;
    }

    final offset = checkedOffset;
    final missing = assetStore.verifyResourceIndexSync(
      ri,
      onProgress: progress == null
          ? null
          : (checked, _) {
              final global = offset + checked;
              if (global % 16 == 0 || global == totalBlobs) {
                progress.send([global, totalBlobs]);
              }
            },
    );
    checkedOffset += ri.entries.length;

    if (missing.isNotEmpty) {
      issues.add(
        VerificationMissingFiles(
          checkoutId: checkoutId,
          snapshotHash: snapshotHash,
          missingIdents: missing,
        ),
      );
    }
  }

  return issues.toIList();
}

int _isolatePrune(_IsolatePaths paths, SendPort? progress) {
  _seedPaths(paths);
  GlobalLogger.init(paths.logs, enableDebugLog: false);

  const assetStore = AssetStore();
  final registryService = CheckoutRegistryService();

  final registry = registryService.readRegistry();
  if (registry.isNone()) return 0;

  final activeSnapshotHashes = <String>{};
  final activeResourceIndexes = <ResourceIndex>[];

  for (final entry in registry.toNullable()!.checkouts.entries) {
    final checkoutId = entry.key;
    final checkoutEntry = entry.value;

    activeSnapshotHashes.add(checkoutEntry.resourceSnapshotHash);

    final reflogHashes = CheckoutService.collectReflogSnapshotHashes(checkoutId);
    activeSnapshotHashes.addAll(reflogHashes);

    final ri = assetStore.readResourceIndexSync(checkoutEntry.resourceSnapshotHash);
    if (ri.isSome()) {
      activeResourceIndexes.add(ri.toNullable()!);
    }
    for (final hash in reflogHashes) {
      if (hash == checkoutEntry.resourceSnapshotHash) continue;
      final histRi = assetStore.readResourceIndexSync(hash);
      if (histRi.isSome()) {
        activeResourceIndexes.add(histRi.toNullable()!);
      }
    }
  }

  return assetStore.pruneSync(
    activeSnapshotHashes: activeSnapshotHashes,
    activeResourceIndexes: activeResourceIndexes,
    onProgress: progress == null ? null : (scanned, total) => progress.send([scanned, total]),
  );
}
