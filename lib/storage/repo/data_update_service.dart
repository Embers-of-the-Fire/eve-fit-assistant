import "package:eve_fit_assistant/data/proto/generation_resources.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/channel_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/native_dir.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/service.dart";
import "package:fpdart/fpdart.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "data_update_service.freezed.dart";

@freezed
sealed class DataUpdateCheckResult with _$DataUpdateCheckResult {
  const factory DataUpdateCheckResult.upToDate({required String currentGenerationHash}) =
      DataUpdateCheckResultUpToDate;

  const factory DataUpdateCheckResult.available({
    required String currentGenerationHash,
    required String newGenerationHash,
  }) = DataUpdateCheckResultAvailable;

  const factory DataUpdateCheckResult.failed({required String message, required bool canRetry}) =
      DataUpdateCheckResultFailed;
}

@freezed
sealed class BatchUpdateProgress with _$BatchUpdateProgress {
  const factory BatchUpdateProgress({
    required String currentCheckoutId,
    required int completedCount,
    required int totalCount,
    required int downloadedCount,
    required int totalDownloadCount,
  }) = _BatchUpdateProgress;
}

@freezed
sealed class BatchUpdateResult with _$BatchUpdateResult {
  const factory BatchUpdateResult({
    required List<String> successes,
    required Map<String, String> failures,
    required List<String> skipped,
  }) = _BatchUpdateResult;
}

class DataUpdateService {
  const DataUpdateService({
    required this.repoService,
    required this.channelService,
    required this.checkoutService,
    required this.assetStore,
    required this.nativeDirResolver,
    required this.remoteCatalogService,
  });

  final RepoService repoService;
  final ChannelService channelService;
  final CheckoutService checkoutService;
  final AssetStore assetStore;
  final NativeDirResolver nativeDirResolver;
  final RemoteCatalogService remoteCatalogService;

  Future<DataUpdateCheckResult> checkForCheckout(String checkoutId) async {
    final registry = repoService.checkoutRegistry.readRegistry();
    final entry = registry.flatMap((r) => Option.fromNullable(r.checkouts[checkoutId]));
    if (entry.isNone()) {
      return Future.value(
        const DataUpdateCheckResult.failed(message: "Checkout not found", canRetry: false),
      );
    }

    final checkout = entry.toNullable()!;
    final channelName = checkout.channel;
    final localHash = channelService.localGenerationHash(channelName);
    if (localHash == null || localHash.isEmpty) {
      return Future.value(const DataUpdateCheckResult.upToDate(currentGenerationHash: ""));
    }

    final localHead = channelService.readHeadMeta(channelName);
    final headResult = await remoteCatalogService.fetchHeadMeta(
      channelName,
      cachedPayload: localHead.toNullable()?.toJson(),
    );
    if (headResult.isLeft()) {
      final err = headResult.getLeft().toNullable()!;
      return DataUpdateCheckResult.failed(
        message: err is CatalogNetworkError ? err.message : "Failed to check for updates",
        canRetry: true,
      );
    }

    final remoteHead = headResult.getRight().toNullable()!;
    final remoteGenerationHash = remoteHead.generationHash;

    final targetSnapshotHash = await _resolveTargetSnapshotHash(
      channelName: channelName,
      serverId: checkout.serverId,
      remoteGenerationHash: remoteGenerationHash,
      localGenerationHash: localHash,
    );

    if (targetSnapshotHash == null) {
      return const DataUpdateCheckResult.failed(
        message: "Server not found in latest generation",
        canRetry: true,
      );
    }

    if (targetSnapshotHash == checkout.resourceSnapshotHash) {
      return DataUpdateCheckResult.upToDate(currentGenerationHash: localHash);
    }

    return DataUpdateCheckResult.available(
      currentGenerationHash: localHash,
      newGenerationHash: remoteGenerationHash,
    );
  }

  /// Resolves the resource snapshot hash for [serverId] in the latest
  /// generation. Prefers locally-cached generation resources when the remote
  /// generation matches the local one; otherwise fetches from remote.
  Future<String?> _resolveTargetSnapshotHash({
    required String channelName,
    required String serverId,
    required String remoteGenerationHash,
    required String localGenerationHash,
  }) async {
    Option<GenerationResources> genResourcesOpt;
    if (remoteGenerationHash == localGenerationHash) {
      genResourcesOpt = channelService.readGenerationResources(channelName);
    } else {
      genResourcesOpt = const None();
    }

    if (genResourcesOpt.isNone()) {
      final result = await remoteCatalogService.fetchGenerationResources(remoteGenerationHash);
      if (result.isLeft()) {
        return null;
      }
      genResourcesOpt = Some(GenerationResources.fromBuffer(result.getRight().toNullable()!));
    }

    final genResources = genResourcesOpt.toNullable()!;
    for (final entry in genResources.entries) {
      if (entry.serverId == serverId) {
        return entry.snapshotHash;
      }
    }
    return null;
  }

  Future<Either<String, String>> applyCheckoutUpdate(
    String checkoutId, {
    required void Function(int downloaded, int total) onProgress,
  }) async {
    final registry = repoService.checkoutRegistry.readRegistry();
    final entry = registry.flatMap((r) => Option.fromNullable(r.checkouts[checkoutId]));
    if (entry.isNone()) {
      return const Left("Checkout not found");
    }

    final channelName = entry.toNullable()!.channel;
    final channel = Channel.tryParse(channelName) ?? Channel.defaultChannel;

    final applyResult = await checkoutService.applyDataUpdate(
      checkoutId: checkoutId,
      channel: channel,
      channelName: channelName,
      onProgress: onProgress,
    );

    if (applyResult.isLeft()) {
      return Left(applyResult.getLeft().toNullable()!);
    }

    final newSnapshotHash = applyResult.getRight().toNullable()!;

    final resourceIndex = assetStore.readResourceIndexSync(newSnapshotHash);
    if (resourceIndex.isNone()) {
      return const Left("Updated snapshot is missing its resource index");
    }

    await nativeDirResolver.prepareNativeDir(newSnapshotHash, resourceIndex.toNullable()!);

    return Right(newSnapshotHash);
  }

  Future<Map<String, DataUpdateCheckResult>> checkAllCheckouts() async {
    final registry = repoService.checkoutRegistry.readRegistry();
    final checkouts = registry.match(
      () => const <String, CheckoutRegistryEntry>{},
      (r) => r.checkouts.unlock,
    );

    final results = <String, DataUpdateCheckResult>{};
    for (final checkoutId in checkouts.keys) {
      results[checkoutId] = await checkForCheckout(checkoutId);
    }
    return results;
  }

  Future<BatchUpdateResult> applyAllCheckouts({
    required void Function(BatchUpdateProgress progress) onProgress,
  }) async {
    final checkResults = await checkAllCheckouts();

    final successes = <String>[];
    final failures = <String, String>{};
    final skipped = <String>[];

    final availableIds = checkResults.entries
        .where((e) => e.value is DataUpdateCheckResultAvailable)
        .map((e) => e.key)
        .toList();

    final totalCount = availableIds.length;
    var completedCount = 0;

    for (var i = 0; i < availableIds.length; i++) {
      final checkoutId = availableIds[i];
      onProgress(
        BatchUpdateProgress(
          currentCheckoutId: checkoutId,
          completedCount: completedCount,
          totalCount: totalCount,
          downloadedCount: 0,
          totalDownloadCount: 0,
        ),
      );

      final result = await applyCheckoutUpdate(
        checkoutId,
        onProgress: (downloaded, total) {
          onProgress(
            BatchUpdateProgress(
              currentCheckoutId: checkoutId,
              completedCount: completedCount,
              totalCount: totalCount,
              downloadedCount: downloaded,
              totalDownloadCount: total,
            ),
          );
        },
      );

      result.match((err) => failures[checkoutId] = err, (_) => successes.add(checkoutId));

      completedCount++;
    }

    for (final entry in checkResults.entries) {
      final result = entry.value;
      if (result is DataUpdateCheckResultUpToDate) {
        skipped.add(entry.key);
      } else if (result is DataUpdateCheckResultFailed) {
        if (!failures.containsKey(entry.key)) {
          failures[entry.key] = result.message;
        }
      }
    }

    final activeSnapshotHashes = _allSnapshotHashes();
    nativeDirResolver.cleanup(activeSnapshotHashes);
    repoService.prune();

    return BatchUpdateResult(successes: successes, failures: failures, skipped: skipped);
  }

  Set<String> _allSnapshotHashes() {
    final hashes = <String>{};
    repoService.checkoutRegistry.readRegistry().fold(() {}, (r) {
      for (final entry in r.checkouts.values) {
        if (entry.resourceSnapshotHash.isNotEmpty) {
          hashes.add(entry.resourceSnapshotHash);
        }
      }
    });
    return hashes;
  }
}
