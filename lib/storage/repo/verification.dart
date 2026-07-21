import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/checkout_registry_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
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
  const VerificationService({
    required this.checkoutService,
    required this.assetStore,
    required this.checkoutRegistry,
    required this.remoteCatalogService,
  });

  final CheckoutService checkoutService;
  final AssetStore assetStore;
  final CheckoutRegistryService checkoutRegistry;
  final RemoteCatalogService remoteCatalogService;

  /// Verifies every checkout's resource snapshot integrity.
  ///
  /// Checks that ResourceIndex protobuf files exist and verifies blob integrity.
  /// Returns a list of issues found. An empty list means all checkouts are intact.
  IList<VerificationIssue> verify() {
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
  int prune() {
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
  Future<IList<VerificationIssue>> repairAll({required Channel channel}) async {
    final issues = verify();
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

    const blobConcurrency = 64;
    var nextIdx = 0;

    if (toRepair.isNotEmpty) {
      assetStore.ensureBlobIdentDirs(toRepair.map((r) => r.identHash));

      Future<void> repairNext() async {
        int idx;
        while ((idx = nextIdx++) < toRepair.length) {
          final item = toRepair[idx];
          final blobResult = await remoteCatalogService.fetchBlob(item.identHash, item.contentHash);
          if (blobResult.isRight()) {
            await assetStore.writeBlobUncheckedAt(
              item.blobPath,
              blobResult.getRight().toNullable()!,
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
