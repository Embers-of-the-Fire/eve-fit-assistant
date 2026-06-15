import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/branch.dart";
import "package:eve_fit_assistant/storage/repo/checkout.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_index.dart";
import "package:eve_fit_assistant/storage/repo/models/missing_files.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:fpdart/fpdart.dart";

/// Represents a single integrity issue found during verification.
sealed class VerificationIssue {
  const VerificationIssue({required this.checkoutId});

  final String checkoutId;
}

class VerificationMissingFiles extends VerificationIssue {
  const VerificationMissingFiles({required super.checkoutId, required this.missingFiles});

  final MissingFiles missingFiles;
}

class VerificationNoManifest extends VerificationIssue {
  const VerificationNoManifest({required super.checkoutId});
}

class VerificationPartialDownload extends VerificationIssue {
  const VerificationPartialDownload({required super.checkoutId, required this.reason});

  final String reason;
}

/// Failure cases for repair operations.
sealed class VerificationFailure {
  const VerificationFailure();
}

class VerificationRepairFailed extends VerificationFailure {
  const VerificationRepairFailed({required this.reason});

  final String reason;
}

/// Verifies local integrity, repairs interrupted operations, and prunes
/// unreferenced data.
class VerificationService {
  const VerificationService({
    required this.checkoutService,
    required this.assetStore,
    required this.branchService,
    required this.remoteCatalogService,
  });

  final CheckoutService checkoutService;
  final AssetStore assetStore;
  final BranchService branchService;
  final RemoteCatalogService remoteCatalogService;

  /// Verifies every installed checkout by checking its manifest against the
  /// asset store. Missing files are reported; re-download from the remote
  /// asset store is triggered automatically via
  /// [repairInterruptedDownload].
  ///
  /// Returns a list of issues found. An empty list means all checkouts are
  /// intact.
  IList<VerificationIssue> verify() {
    final index = checkoutService.readIndex();
    if (index.isNone()) return const IList.empty();

    final issues = <VerificationIssue>[];

    for (final entry in index.toNullable()!.entries.entries) {
      if (entry.value.state != CheckoutState.installed) continue;
      final checkoutId = entry.key;

      final manifest = checkoutService.readManifest(checkoutId);
      if (manifest.isNone()) {
        issues.add(VerificationNoManifest(checkoutId: checkoutId));
        continue;
      }

      assetStore.verifyManifestSync(manifest.toNullable()!).match((missing) {
        if (missing.missing.isNotEmpty || missing.hashMismatches.isNotEmpty) {
          issues.add(VerificationMissingFiles(checkoutId: checkoutId, missingFiles: missing));
        }
      }, (_) {});
    }

    return issues.toIList();
  }

  /// Prunes unreferenced assets and orphaned historical checkouts.
  ///
  /// Delegates to [AssetStore.pruneSync] for asset-level cleanup and removes
  /// [CheckoutState.historical] entries from the index that are not referenced
  /// by any branch reflog.
  ///
  /// Returns the total number of items pruned (files + historical index entries).
  int prune() {
    final activeManifests = <AssetManifest>[];

    final index = checkoutService.readIndex();
    if (index.isSome()) {
      for (final entry in index.toNullable()!.entries.entries) {
        if (entry.value.state != CheckoutState.installed) continue;
        final manifest = checkoutService.readManifest(entry.key);
        if (manifest.isSome()) {
          activeManifests.add(manifest.toNullable()!);
        }
      }
    }

    final assetCount = assetStore.pruneSync(activeManifests.toIList());
    final historicalCount = _cleanupOrphanedHistorical();

    return assetCount + historicalCount;
  }

  /// Extends [verify] to also re-download missing files from the remote asset
  /// store for each [VerificationMissingFiles] issue, and resets no-manifest
  /// checkouts to [CheckoutState.known] so they can be re-downloaded.
  ///
  /// [VerificationPartialDownload] issues are returned unresolved for the
  /// caller to trigger a retry of the full/incremental download pipeline.
  Future<IList<VerificationIssue>> repairAll({required Channel channel}) async {
    final issues = verify();
    final unresolved = <VerificationIssue>[];

    for (final issue in issues) {
      if (issue is VerificationMissingFiles) {
        final repaired = await _redownloadMissingFiles(
          checkoutId: issue.checkoutId,
          missingFiles: issue.missingFiles,
          channel: channel,
        );
        if (!repaired) {
          unresolved.add(issue);
        }
      } else if (issue is VerificationNoManifest) {
        checkoutService.setState(issue.checkoutId, CheckoutState.known);
      } else if (issue is VerificationPartialDownload) {
        unresolved.add(issue);
      }
    }

    return unresolved.toIList();
  }

  /// Detects and repairs partial download states for [checkoutId].
  ///
  /// | Index state | Manifest | Asset files | Action |
  /// |:------------|:---------|:------------|:-------|
  /// | installed   | missing  | —           | Roll back to [CheckoutState.known] |
  /// | installed   | present  | missing     | Roll back to [CheckoutState.known] for re-download |
  /// | installed   | present  | intact      | No action |
  /// | known       | —        | —           | No action |
  /// | not found   | —        | —           | No action |
  Either<VerificationFailure, Unit> repairInterruptedDownload(String checkoutId) {
    final state = checkoutService.lookup(checkoutId);

    if (state.isNone()) return const Right(unit);

    if (state.toNullable()! != CheckoutState.installed) {
      return const Right(unit);
    }

    final manifest = checkoutService.readManifest(checkoutId);
    if (manifest.isNone()) {
      checkoutService.setState(checkoutId, CheckoutState.known);
      return const Right(unit);
    }

    final verifyResult = assetStore.verifyManifestSync(manifest.toNullable()!);
    return verifyResult.match((missing) {
      if (missing.missing.isNotEmpty || missing.hashMismatches.isNotEmpty) {
        checkoutService.setState(checkoutId, CheckoutState.known);
      }
      return const Right(unit);
    }, (_) => const Right(unit));
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  Future<bool> _redownloadMissingFiles({
    required String checkoutId,
    required MissingFiles missingFiles,
    required Channel channel,
  }) async {
    final manifest = checkoutService.readManifest(checkoutId);
    if (manifest.isNone()) return false;

    var allSucceeded = true;
    final manifestData = manifest.toNullable()!;
    final affectedSet = {...missingFiles.missing, ...missingFiles.hashMismatches};

    for (final entry in manifestData.files.entries) {
      final pathHash = entry.key;
      final assetFile = entry.value;

      if (!affectedSet.contains(pathHash)) continue;

      final result = await remoteCatalogService.fetchAsset(channel, pathHash, assetFile.hash);
      result.fold((_) => allSucceeded = false, (bytes) {
        assetStore
          ..deleteFileSync(pathHash, assetFile.hash)
          ..writeFileByHashesSync(pathHash, assetFile.hash, bytes);
      });
    }

    final recheck = assetStore.verifyManifestSync(manifestData);
    return allSucceeded && recheck.isRight();
  }

  int _cleanupOrphanedHistorical() {
    final index = checkoutService.readIndex();
    if (index.isNone()) return 0;

    final referencedCheckouts = <String>{};
    final branches = branchService.discoverBranches();
    for (final branch in branches) {
      referencedCheckouts.add(branch.checkout);
      for (final entry in branch.reflog) {
        referencedCheckouts
          ..add(entry.from)
          ..add(entry.to);
      }
    }

    var modified = false;
    var removed = 0;
    var updated = index.toNullable()!;
    for (final entry in index.toNullable()!.entries.entries) {
      if (entry.value.state != CheckoutState.historical) continue;
      if (!referencedCheckouts.contains(entry.key)) {
        updated = updated.copyWith(entries: updated.entries.remove(entry.key));
        modified = true;
        removed++;
      }
    }

    if (modified) {
      if (!checkoutService.writeIndex(updated)) {
        // Best-effort cleanup — log but don't propagate.
      }
    }
    return removed;
  }
}
