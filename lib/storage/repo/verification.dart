import "dart:convert";
import "dart:io";
import "dart:isolate";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/proto/checkout_reflog.pb.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/checkout_registry_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_meta.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/utils.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:path/path.dart" as p;

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
      final appSupport = PathProvider.appSupportPath;
      final logs = PathProvider.logsPath;
      if (onProgress == null) {
        return await _spawnVerify(appSupport, logs, null);
      }
      final receivePort = ReceivePort()
        ..listen((message) {
          if (message is List && message.length == 2 && message[0] is int) {
            onProgress(message[0] as int, message[1] as int);
          }
        });
      final sendPort = receivePort.sendPort;
      try {
        return await _spawnVerify(appSupport, logs, sendPort);
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
      final appSupport = PathProvider.appSupportPath;
      final logs = PathProvider.logsPath;
      if (onProgress == null) {
        return await _spawnPrune(appSupport, logs, null);
      }
      final receivePort = ReceivePort()
        ..listen((message) {
          if (message is List && message.length == 2 && message[0] is int) {
            onProgress(message[0] as int, message[1] as int);
          }
        });
      final sendPort = receivePort.sendPort;
      try {
        return await _spawnPrune(appSupport, logs, sendPort);
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
      final reflogHashes = checkoutService.collectReflogSnapshotHashes(entry.key);
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
  /// Returns unresolved issues (partial downloads or network failures).
  ///
  /// Throws [StateError] if another verification operation is already running.
  Future<IList<VerificationIssue>> repairAll({required Channel channel}) async {
    _acquire();
    try {
      return await _repairAllInternal(channel: channel);
    } finally {
      _release();
    }
  }

  Future<IList<VerificationIssue>> _repairAllInternal({required Channel channel}) async {
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

    if (toRepair.isNotEmpty) {
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

Future<IList<VerificationIssue>> _spawnVerify(String appSupport, String logs, SendPort? sendPort) =>
    Isolate.run(() => _isolateVerify(appSupport, logs, sendPort));

Future<int> _spawnPrune(String appSupport, String logs, SendPort? sendPort) =>
    Isolate.run(() => _isolatePrune(appSupport, logs, sendPort));

// ── Isolate entry points ───────────────────────────────────────────────────────
// Top-level functions so they can be sent to Isolate.run(). They reconstruct
// the minimal stateless services from the passed paths.

IList<VerificationIssue> _isolateVerify(
  String appSupportPath,
  String logsPath,
  SendPort? progress,
) {
  PathProvider.appSupportPath = appSupportPath;
  GlobalLogger.init(logsPath, enableDebugLog: false);

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
  var checkedBlobs = 0;

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

    final failures = <String>[];
    for (final re in ri.entries) {
      final ihash = RepoHash.hashIdent(re.resourceId);
      final assetPath = RepoPaths.blobPath(ihash, re.contentHash);
      final file = File(assetPath);
      if (!file.existsSync()) {
        failures.add(re.resourceId);
      } else {
        try {
          final diskHash = RepoHash.hashContent(file.readAsBytesSync());
          if (diskHash != re.contentHash) failures.add(re.resourceId);
        } on FileSystemException {
          failures.add(re.resourceId);
        }
      }
      checkedBlobs++;
      progress?.send([checkedBlobs, totalBlobs]);
    }

    if (failures.isNotEmpty) {
      issues.add(
        VerificationMissingFiles(
          checkoutId: checkoutId,
          snapshotHash: snapshotHash,
          missingIdents: failures.toIList(),
        ),
      );
    }
  }

  return issues.toIList();
}

int _isolatePrune(String appSupportPath, String logsPath, SendPort? progress) {
  PathProvider.appSupportPath = appSupportPath;
  GlobalLogger.init(logsPath, enableDebugLog: false);

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

    final reflogHashes = _collectReflogHashes(checkoutId);
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

  final referencedBlobs = <String>{};
  for (final ri in activeResourceIndexes) {
    for (final entry in ri.entries) {
      final ihash = RepoHash.hashIdent(entry.resourceId);
      referencedBlobs.add(RepoPaths.blobPath(ihash, entry.contentHash));
    }
  }

  final assetsDir = Directory(RepoPaths.assetsPath);
  if (!assetsDir.existsSync()) return 0;

  final snapshotDirs = <Directory>[];
  final resourcesDir = Directory("${RepoPaths.assetsPath}/resources");
  if (resourcesDir.existsSync()) {
    snapshotDirs.addAll(resourcesDir.listSync().whereType<Directory>());
  }

  final blobFiles = <File>[];
  final blobsDir = Directory("${RepoPaths.assetsPath}/blobs");
  if (blobsDir.existsSync()) {
    for (final prefixDir in blobsDir.listSync().whereType<Directory>()) {
      for (final entity in prefixDir.listSync().whereType<Directory>()) {
        blobFiles.addAll(entity.listSync().whereType<File>());
      }
    }
  }

  final totalItems = snapshotDirs.length + blobFiles.length;
  var scanned = 0;
  var deleted = 0;

  for (final dir in snapshotDirs) {
    final name = p.basename(dir.path);
    if (!activeSnapshotHashes.contains(name)) {
      try {
        dir.deleteSync(recursive: true);
        deleted++;
      } on FileSystemException {
        // best-effort
      }
    }
    scanned++;
    progress?.send([scanned, totalItems]);
  }

  for (final blob in blobFiles) {
    if (!referencedBlobs.contains(blob.path)) {
      try {
        blob.deleteSync();
        deleted++;
      } on FileSystemException {
        // best-effort
      }
    }
    scanned++;
    progress?.send([scanned, totalItems]);
  }

  // Clean empty ident dirs and prefix dirs
  if (blobsDir.existsSync()) {
    for (final prefixDir in blobsDir.listSync().whereType<Directory>()) {
      for (final entity in prefixDir.listSync().whereType<Directory>()) {
        if (entity.listSync().isEmpty) {
          try {
            entity.deleteSync();
          } on FileSystemException {
            // best-effort
          }
        }
      }
      if (prefixDir.listSync().isEmpty) {
        try {
          prefixDir.deleteSync();
        } on FileSystemException {
          // best-effort
        }
      }
    }
  }

  // Prune temporary directories
  for (final dir in assetsDir.listSync().whereType<Directory>()) {
    final name = p.basename(dir.path);
    if (name.startsWith("tmp_") || name.endsWith("_temp")) {
      try {
        dir.deleteSync(recursive: true);
        deleted++;
      } on FileSystemException {
        // best-effort
      }
    }
  }

  return deleted;
}

Set<String> _collectReflogHashes(String checkoutId) {
  final hashes = <String>{};

  final metaFile = File(RepoPaths.checkoutMetaPath(checkoutId));
  if (metaFile.existsSync()) {
    try {
      final json = jsonDecode(metaFile.readAsStringSync()) as Map<String, dynamic>;
      final meta = CheckoutMeta.fromJson(json);
      hashes.add(meta.resourceSnapshotHash);
    } on Exception {
      // best-effort
    }
  }

  final reflogFile = File(RepoPaths.checkoutReflogPath(checkoutId));
  if (reflogFile.existsSync()) {
    try {
      final reflog = CheckoutReflog.fromBuffer(reflogFile.readAsBytesSync());
      for (final entry in reflog.entries) {
        if (entry.from.isNotEmpty) hashes.add(entry.from);
        if (entry.to.isNotEmpty) hashes.add(entry.to);
      }
    } on Exception {
      // best-effort
    }
  }

  return hashes;
}
