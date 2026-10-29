import "package:efa_proto/generation_resources.pb.dart";
import "package:efa_proto/server_history.pb.dart";
import "package:eve_fit_assistant/features/remote_content/cadence.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/channel_service.dart";
import "package:eve_fit_assistant/storage/repo/checkout_service.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/models/models.dart" show CheckoutRegistryEntry;
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
    required this.remoteCatalogService,
    this.cadence = DataCadence.immediate,
  });

  final RepoService repoService;
  final ChannelService channelService;
  final CheckoutService checkoutService;
  final AssetStore assetStore;
  final RemoteCatalogService remoteCatalogService;

  /// The user's data cadence preference. The effective tier is derived per
  /// checkout channel via [effectiveTier] (testing always tracks immediately).
  final DataCadence cadence;

  Future<DataUpdateCheckResult> checkForCheckout(String checkoutId) async {
    final checkout = _readCheckout(checkoutId);
    if (checkout.isNone()) {
      return const DataUpdateCheckResult.failed(message: "Checkout not found", canRetry: false);
    }

    final entry = checkout.toNullable()!;
    final channelResult = await _checkChannel(entry.channel);
    if (channelResult.isLeft()) {
      return channelResult.getLeft().toNullable()!;
    }
    final info = channelResult.getRight().toNullable()!;
    return _evaluateCheckout(entry, info);
  }

  Option<CheckoutRegistryEntry> _readCheckout(String checkoutId) => repoService.checkoutRegistry
      .readRegistry()
      .flatMap((r) => Option.fromNullable(r.checkouts[checkoutId]));

  Future<Either<DataUpdateCheckResultFailed, _ChannelUpdateInfo>> _checkChannel(
    String channelName,
  ) async {
    final localHash = await channelService.localGenerationHash(channelName);
    if (localHash == null || localHash.isEmpty) {
      return const Right(_ChannelUpdateInfo(remoteGenerationHash: "", generationResources: null));
    }

    final headResult = await remoteCatalogService.fetchHeadMeta(channelName);
    if (headResult.isLeft()) {
      final err = headResult.getLeft().toNullable()!;
      return Left(
        DataUpdateCheckResultFailed(
          message: err is CatalogNetworkError ? err.message : "Failed to check for updates",
          canRetry: true,
        ),
      );
    }

    final remoteHead = headResult.getRight().toNullable()!;
    final remoteGenerationHash = remoteHead.generationHash;

    final generationResources = await _resolveGenerationResources(
      channelName: channelName,
      remoteGenerationHash: remoteGenerationHash,
      localGenerationHash: localHash,
    );
    if (generationResources == null) {
      return const Left(
        DataUpdateCheckResultFailed(
          message: "Server not found in latest generation",
          canRetry: true,
        ),
      );
    }

    final history = await _resolveServerHistory(
      channelName: channelName,
      remoteGenerationHash: remoteGenerationHash,
      localGenerationHash: localHash,
    );

    return Right(
      _ChannelUpdateInfo(
        remoteGenerationHash: remoteGenerationHash,
        generationResources: generationResources,
        history: history,
      ),
    );
  }

  /// Resolves the generation resources for [channelName]. Prefers locally-cached
  /// resources when the remote generation matches the local one; otherwise
  /// fetches from remote. Returns `null` when the fetch fails.
  Future<GenerationResources?> _resolveGenerationResources({
    required String channelName,
    required String remoteGenerationHash,
    required String localGenerationHash,
  }) async {
    Option<GenerationResources> genResourcesOpt;
    if (remoteGenerationHash == localGenerationHash) {
      genResourcesOpt = await channelService.readGenerationResources(channelName);
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

    return genResourcesOpt.toNullable();
  }

  /// Resolves the promoted history for [channelName]. Prefers the locally
  /// cached history when the remote generation matches the local one;
  /// otherwise fetches from remote. Returns `null` when unavailable —
  /// non-fatal: immediate-tier checks fall back to the head snapshot.
  Future<ServerHistory?> _resolveServerHistory({
    required String channelName,
    required String remoteGenerationHash,
    required String localGenerationHash,
  }) async {
    if (remoteGenerationHash == localGenerationHash) {
      final local = await channelService.readServerHistory(channelName);
      if (local.isSome()) return local.toNullable();
    }
    final result = await remoteCatalogService.fetchServerHistory(remoteGenerationHash);
    if (result.isLeft()) return null;
    try {
      return ServerHistory.fromBuffer(result.getRight().toNullable()!);
    } on Exception {
      return null;
    }
  }

  /// The history entry list (newest first) for [serverId], or null when the
  /// history or the server is absent from it.
  static List<ServerHistory_Snapshot>? _serverHistoryEntries(
    ServerHistory? history,
    String serverId,
  ) {
    if (history == null) return null;
    for (final entry in history.servers) {
      if (entry.serverId == serverId) return entry.snapshots;
    }
    return null;
  }

  /// Resolves the snapshot a checkout on its channel should track under the
  /// effective cadence tier, plus the admission timestamp of that
  /// snapshot. Returns null when the server is absent from the generation.
  _ResolvedTarget? _resolveTarget(CheckoutRegistryEntry checkout, _ChannelUpdateInfo info) {
    final channel = Channel.tryParse(checkout.channel) ?? Channel.defaultChannel;
    final tier = effectiveTier(channel, cadence);
    final historyEntries = _serverHistoryEntries(info.history, checkout.serverId);

    if (tier != DataCadence.immediate) {
      // Cadence tiers resolve over the promoted history; without it there is
      // nothing to resolve against (non-fatal: retried at the next check).
      if (historyEntries == null || historyEntries.isEmpty) return null;
      final resolved = resolveCheckout(tier, historyEntries, DateTime.now().toUtc());
      if (resolved == null) return null;
      return _ResolvedTarget(snapshotHash: resolved.snapshotHash, promotedAt: resolved.timestamp);
    }

    String? headSnapshotHash;
    for (final entry in info.generationResources!.entries) {
      if (entry.serverId == checkout.serverId) {
        headSnapshotHash = entry.snapshotHash;
        break;
      }
    }
    if (headSnapshotHash == null) return null;
    final headPromotedAt =
        (historyEntries != null && historyEntries.isNotEmpty) &&
            historyEntries.first.snapshotHash == headSnapshotHash
        ? historyEntries.first.timestamp
        : null;
    return _ResolvedTarget(snapshotHash: headSnapshotHash, promotedAt: headPromotedAt);
  }

  /// Whether [target] should be offered over the checkout's active snapshot:
  /// an update is offered iff the resolved checkout differs from the active
  /// checkout and is newer by admission time. A slower tier mid-cycle is a
  /// lag, not a rewind — never offer a silent downgrade. An active hash that
  /// is absent from the history, or whose age is unknown, re-binds to the
  /// resolved target.
  ///
  /// When the active hash is listed in the history, that entry's timestamp is
  /// the admission time for this channel; [CheckoutRegistryEntry.promotedAt]
  /// is only a fallback for when the history is unavailable (it is null on
  /// pre-cadence installs and may hold another channel's timestamp after a
  /// re-bind).
  static bool _shouldOfferUpdate(
    CheckoutRegistryEntry checkout,
    _ResolvedTarget target,
    List<ServerHistory_Snapshot>? historyEntries,
  ) {
    if (target.snapshotHash == checkout.resourceSnapshotHash) return false;

    String? activeTimestamp = checkout.promotedAt;
    if (historyEntries != null && historyEntries.isNotEmpty) {
      ServerHistory_Snapshot? activeEntry;
      for (final s in historyEntries) {
        if (s.snapshotHash == checkout.resourceSnapshotHash) {
          activeEntry = s;
          break;
        }
      }
      if (activeEntry == null) return true;
      activeTimestamp = activeEntry.timestamp;
    }

    final activeAt = DateTime.tryParse(activeTimestamp ?? "")?.toUtc();
    final targetAt = DateTime.tryParse(target.promotedAt ?? "")?.toUtc();
    if (activeAt == null || targetAt == null) return true;
    return targetAt.isAfter(activeAt);
  }

  Future<DataUpdateCheckResult> _evaluateCheckout(
    CheckoutRegistryEntry checkout,
    _ChannelUpdateInfo info,
  ) async {
    final localHash = await channelService.localGenerationHash(checkout.channel);
    if (localHash == null || localHash.isEmpty) {
      return const DataUpdateCheckResult.upToDate(currentGenerationHash: "");
    }

    if (info.generationResources == null) {
      return const DataUpdateCheckResult.failed(
        message: "Server not found in latest generation",
        canRetry: true,
      );
    }

    final target = _resolveTarget(checkout, info);
    if (target == null) {
      // Either the server is absent from the generation, or a cadence tier
      // could not resolve without the promoted history (retried later).
      final inResources = info.generationResources!.entries.any(
        (e) => e.serverId == checkout.serverId,
      );
      return DataUpdateCheckResult.failed(
        message: inResources
            ? "Promoted history unavailable"
            : "Server not found in latest generation",
        canRetry: true,
      );
    }

    final historyEntries = _serverHistoryEntries(info.history, checkout.serverId);
    if (!_shouldOfferUpdate(checkout, target, historyEntries)) {
      return DataUpdateCheckResult.upToDate(currentGenerationHash: localHash);
    }

    return DataUpdateCheckResult.available(
      currentGenerationHash: localHash,
      newGenerationHash: info.remoteGenerationHash,
    );
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

    final checkout = entry.toNullable()!;
    final channelName = checkout.channel;
    final channel = Channel.tryParse(channelName) ?? Channel.defaultChannel;

    // Resolve the cadence target so a lagging tier applies the resolved
    // snapshot, not the channel head. A failed channel check or an
    // unresolvable cadence target (missing history on a cadence tier) rejects
    // the apply rather than silently falling back to the head snapshot.
    String? targetSnapshotHash;
    final channelResult = await _checkChannel(channelName);
    if (channelResult.isLeft()) {
      return Left(channelResult.getLeft().toNullable()!.message);
    }
    final info = channelResult.getRight().toNullable()!;
    if (info.generationResources != null) {
      final target = _resolveTarget(checkout, info);
      if (target == null) {
        final inResources = info.generationResources!.entries.any(
          (e) => e.serverId == checkout.serverId,
        );
        return Left(
          inResources ? "Promoted history unavailable" : "Server not found in latest generation",
        );
      }
      targetSnapshotHash = target.snapshotHash;
    }

    final applyResult = await checkoutService.applyDataUpdate(
      checkoutId: checkoutId,
      channel: channel,
      channelName: channelName,
      targetSnapshotHash: targetSnapshotHash,
      onProgress: onProgress,
    );

    if (applyResult.isLeft()) {
      return Left(applyResult.getLeft().toNullable()!);
    }

    final newSnapshotHash = applyResult.getRight().toNullable()!;

    final resourceIndex = await assetStore.readResourceIndex(newSnapshotHash);
    if (resourceIndex.isNone()) {
      return const Left("Updated snapshot is missing its resource index");
    }

    return Right(newSnapshotHash);
  }

  /// Re-binds every checkout to [channelName] after a channel switch.
  ///
  /// Checkout data is kept in place; re-resolution against the target
  /// channel's history happens at the next update check (newer resolutions
  /// surface as available updates, older/equal ones report up to date).
  Future<void> rebindCheckoutsToChannel(String channelName) async {
    final registry = repoService.checkoutRegistry.readRegistry();
    if (registry.isNone()) return;
    final r = registry.toNullable()!;
    var checkouts = r.checkouts;
    for (final entry in r.checkouts.entries) {
      if (entry.value.channel != channelName) {
        checkouts = checkouts.add(entry.key, entry.value.copyWith(channel: channelName));
      }
    }
    await repoService.checkoutRegistry.writeRegistry(r.copyWith(checkouts: checkouts));
  }

  Future<Map<String, DataUpdateCheckResult>> checkAllCheckouts() async {
    final registry = repoService.checkoutRegistry.readRegistry();
    final checkouts = registry.match(
      () => const <String, CheckoutRegistryEntry>{},
      (r) => r.checkouts.unlock,
    );

    final byChannel = <String, List<String>>{};
    for (final entry in checkouts.entries) {
      byChannel.putIfAbsent(entry.value.channel, () => []).add(entry.key);
    }

    final channelResults = <String, Either<DataUpdateCheckResultFailed, _ChannelUpdateInfo>>{};
    for (final channelName in byChannel.keys) {
      channelResults[channelName] = await _checkChannel(channelName);
    }

    final results = <String, DataUpdateCheckResult>{};
    for (final checkoutId in checkouts.keys) {
      final checkout = checkouts[checkoutId]!;
      final channelResult = channelResults[checkout.channel]!;
      if (channelResult.isLeft()) {
        results[checkoutId] = channelResult.getLeft().toNullable()!;
      } else {
        final info = channelResult.getRight().toNullable()!;
        results[checkoutId] = await _evaluateCheckout(checkout, info);
      }
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

    await repoService.pruneAsync();

    return BatchUpdateResult(successes: successes, failures: failures, skipped: skipped);
  }
}

/// Lightweight value type for the result of checking a single channel.
class _ChannelUpdateInfo {
  const _ChannelUpdateInfo({
    required this.remoteGenerationHash,
    required this.generationResources,
    this.history,
  });

  final String remoteGenerationHash;
  final GenerationResources? generationResources;
  final ServerHistory? history;
}

/// The snapshot a checkout should track under the effective cadence tier,
/// plus the admission timestamp (`promoted_at`) of that snapshot, when known.
class _ResolvedTarget {
  const _ResolvedTarget({required this.snapshotHash, this.promotedAt});

  final String snapshotHash;
  final String? promotedAt;
}
