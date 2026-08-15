import "dart:async";
import "dart:math" show min;

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/pages/setting/data/data_update_tile.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_head_meta.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/verification.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";

class StorageOverview {
  const StorageOverview({
    required this.fileCount,
    required this.totalSize,
    required this.downloadedCount,
    required this.downloadedSize,
    required this.onDemandCount,
    required this.onDemandSize,
  });

  /// Logical totals across all index entries (downloaded + on-demand).
  final int fileCount;
  final int totalSize;

  /// Entries whose blobs are present on disk.
  final int downloadedCount;
  final int downloadedSize;

  /// Entries whose blobs are not on disk yet (fetched lazily on first access).
  final int onDemandCount;
  final int onDemandSize;
}

final storageOverviewProvider = FutureProvider<StorageOverview>((ref) async {
  final checkoutIds = ref.watch(installedCheckoutIdsProvider);
  final registryService = ref.watch(checkoutRegistryServiceProvider);
  final assetStore = ref.watch(assetStoreProvider);

  final seen = <String>{};
  final entries = <({String identHash, String contentHash, int size})>[];

  for (final id in checkoutIds) {
    final entry = registryService.readRegistry().flatMap(
      (r) => Option.fromNullable(r.checkouts[id]),
    );
    if (entry.isNone()) continue;
    final ri = await assetStore.readResourceIndex(entry.toNullable()!.resourceSnapshotHash);
    if (ri.isNone()) continue;
    final index = ri.toNullable()!;
    for (final file in index.entries) {
      if (!seen.add(file.resourceId)) continue;
      entries.add((
        identHash: RepoHash.hashIdent(file.resourceId),
        contentHash: file.contentHash,
        size: file.size.toInt(),
      ));
    }
  }

  // Count blobs actually present on disk (batched), not the download policy:
  // FORCE entries whose downloads failed are not downloaded, and NON_FORCE
  // entries already lazily fetched do occupy disk.
  var downloadedCount = 0;
  var downloadedSize = 0;
  var onDemandCount = 0;
  var onDemandSize = 0;
  const batchSize = 64;
  for (var start = 0; start < entries.length; start += batchSize) {
    final batch = entries.sublist(start, min(start + batchSize, entries.length));
    final exists = await Future.wait(
      batch.map((e) => assetStore.blobExists(e.identHash, e.contentHash)),
    );
    for (var i = 0; i < batch.length; i++) {
      if (exists[i]) {
        downloadedCount++;
        downloadedSize += batch[i].size;
      } else {
        onDemandCount++;
        onDemandSize += batch[i].size;
      }
    }
  }

  return StorageOverview(
    fileCount: entries.length,
    totalSize: entries.fold(0, (sum, e) => sum + e.size),
    downloadedCount: downloadedCount,
    downloadedSize: downloadedSize,
    onDemandCount: onDemandCount,
    onDemandSize: onDemandSize,
  );
});

typedef _ChannelOverviewInfo = ({String? generationHash, ChannelHeadMeta? headMeta});

/// Local channel generation hash + head metadata for the storage overview card.
final storageChannelOverviewProvider = FutureProvider.family<_ChannelOverviewInfo, String>((
  ref,
  channelName,
) async {
  final channelService = ref.watch(channelServiceProvider);
  final genHash = await channelService.localGenerationHash(channelName);
  final headMeta = (await channelService.readHeadMeta(channelName)).toNullable();
  return (generationHash: genHash, headMeta: headMeta);
});

@RoutePage(name: "StorageManagement")
class StorageManagementPage extends ConsumerStatefulWidget {
  const StorageManagementPage({super.key});

  @override
  ConsumerState<StorageManagementPage> createState() => _StorageManagementPageState();
}

class _StorageManagementPageState extends ConsumerState<StorageManagementPage> {
  IList<VerificationIssue>? _verifyResult;
  bool _verifyLoading = false;
  bool _pruneLoading = false;
  int? _pruneCount;
  bool _repairLoading = false;
  bool _forceSyncLoading = false;
  String? _forceSyncResult;
  bool _clearLoading = false;
  bool _isOperationRunning = false;
  final _operationProgress = ValueNotifier<double?>(null);
  int _lastProgressPercent = -1;

  @override
  void dispose() {
    _operationProgress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = ref.watch(currentActiveProvider);
    final channelName =
        active?.channel ?? ref.read(appSettingServiceProvider).remoteContent.channel;

    return Layout(
      title: l10n.storagePageTitle,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(storageOverviewProvider);
          await ref.read(batchDataUpdateControllerProvider.notifier).check();
        },
        child: ConfigListView(
          children: [
            // ── Overview ──────────────────────────────────────────────────────
            ConfigListTile.title(l10n.storageOverviewTitle),
            ConfigListTile.custom(
              ref
                  .watch(storageOverviewProvider)
                  .when(
                    data: (overview) => _buildOverviewCard(overview, channelName),
                    loading: _buildOverviewLoading,
                    error: (err, _) => _buildOverviewError(err.toString()),
                  ),
            ),

            // ── Data Management ───────────────────────────────────────────────
            ConfigListTile.title(l10n.storageDataManagementTitle),
            const ConfigListTile.custom(DataUpdateTile()),
            ConfigListTile.item(
              icon: const Icon(Icons.inventory_2_outlined),
              title: l10n.storageDatasourceManagement,
              subtitle: l10n.storageDatasourceManagementDesc,
              onTap: () => unawaited(context.router.push(const CheckoutManagementRoute())),
            ),

            // ── Storage Operations ────────────────────────────────────────────
            ConfigListTile.title(l10n.storageOperationsTitle),
            ConfigListTile.custom(_buildOperationProgress()),
            ConfigListTile.item(
              icon: Icon(Icons.verified_outlined, color: context.theme.colorScheme.primary),
              title: l10n.storageVerifyButton,
              subtitle: _verifyLoading
                  ? l10n.storageVerifyRunning
                  : _verifyResult != null
                  ? _verifyResult!.isEmpty
                        ? l10n.storageVerifiedOk
                        : l10n.storageMissingFiles(count: _verifyResult!.length)
                  : null,
              onTap: _isOperationRunning ? null : _runVerify,
            ),
            ConfigListTile.custom(_buildVerifyResults()),
            ConfigListTile.item(
              icon: Icon(
                Icons.cleaning_services_outlined,
                color: context.theme.colorScheme.primary,
              ),
              title: l10n.storagePruneButton,
              subtitle: _pruneLoading
                  ? l10n.storagePruneRunning
                  : _pruneCount != null
                  ? l10n.storagePrunedCount(count: _pruneCount!)
                  : l10n.storageCacheInfoHint,
              onTap: _isOperationRunning ? null : _runPrune,
            ),
            ConfigListTile.item(
              icon: Icon(Icons.cloud_sync_outlined, color: context.theme.colorScheme.primary),
              title: l10n.storageForceSyncButton,
              subtitle: _forceSyncLoading ? l10n.storageForceSyncRunning : _forceSyncResult,
              onTap: _isOperationRunning ? null : () => unawaited(_runForceSync(channelName)),
            ),
            ConfigListTile.item(
              icon: Icon(Icons.delete_forever_outlined, color: context.theme.colorScheme.error),
              title: l10n.storageClearAllButton,
              subtitle: _clearLoading ? l10n.storageClearAllRunning : null,
              onTap: _isOperationRunning ? null : () => unawaited(_runClearAll()),
            ),
            const ConfigListTile.space(24),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewCard(StorageOverview overview, String channelName) {
    final l10n = context.l10n;
    final theme = context.theme;

    final info = ref.watch(storageChannelOverviewProvider(channelName)).value;
    final genHash = info?.generationHash;
    final headMeta = info?.headMeta;
    final metadata = genHash == null
        ? l10n.storageNeverSynced
        : "$channelName · ${_truncateHash(genHash)}";
    final lastUpdated = headMeta == null ? l10n.storageNeverSynced : headMeta.updatedAt;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _overviewRow(l10n.storageFileCount, "${overview.fileCount}"),
          _overviewRow(l10n.storageTotalSize, _formatSize(overview.totalSize)),
          _overviewRow(
            l10n.storageDownloadedLabel,
            l10n.storageDownloadedValue(
              count: overview.downloadedCount,
              size: _formatSize(overview.downloadedSize),
            ),
          ),
          _overviewRow(
            l10n.storageOnDemandLabel,
            l10n.storageOnDemandValue(
              count: overview.onDemandCount,
              size: _formatSize(overview.onDemandSize),
            ),
          ),
          _overviewRow(l10n.storageMetadata, metadata),
          _overviewRow(l10n.storageLastUpdated, lastUpdated),
          const SizedBox(height: 8),
          if (overview.onDemandCount > 0) ...[
            Text(
              l10n.storageOnDemandHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            l10n.storageCacheInfoHint,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewLoading() {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
        ),
      ),
    );
  }

  Widget _buildOverviewError(String error) {
    final theme = context.theme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        error,
        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      ),
    );
  }

  Widget _overviewRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: context.theme.textTheme.bodyMedium?.copyWith(
              color: context.theme.colorScheme.outline,
            ),
          ),
        ),
        Expanded(child: Text(value, style: context.theme.textTheme.bodyMedium)),
      ],
    ),
  );

  Widget _buildOperationProgress() {
    if (!_isOperationRunning) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ValueListenableBuilder<double?>(
        valueListenable: _operationProgress,
        builder: (context, value, _) => LinearProgressIndicator(value: value),
      ),
    );
  }

  void _updateProgress(int current, int total) {
    if (total <= 0) return;
    final percent = (current * 100) ~/ total;
    if (percent == _lastProgressPercent) return;
    _lastProgressPercent = percent;
    _operationProgress.value = current / total;
  }

  Widget _buildVerifyResults() {
    final issues = _verifyResult;
    if (issues == null || issues.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...issues.map((issue) {
            final hash = _truncateHash(issue.checkoutId);
            return switch (issue) {
              VerificationMissingFiles(:final missingIdents) => _issueRow(
                Icons.warning_amber,
                Colors.orange,
                "$hash: ${l10n.storageMissingFiles(count: missingIdents.length)}",
              ),
              VerificationNoMeta() => _issueRow(
                Icons.error_outline,
                Colors.red,
                "$hash: ${l10n.storageNoManifest}",
              ),
              VerificationPartialDownload(:final reason) => _issueRow(
                Icons.downloading_outlined,
                Colors.orange,
                "$hash: $reason",
              ),
            };
          }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _isOperationRunning ? null : _runRepair,
              icon: _repairLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.build_outlined, size: 18),
              label: Text(_repairLoading ? l10n.storageRepairRunning : l10n.storageRepairButton),
            ),
          ),
        ],
      ),
    );
  }

  void _showOperationError(Object error) {
    if (!mounted) return;
    final msg = context.l10n.storageOperationError(message: error.toString());
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 3)));
  }

  Widget _issueRow(IconData icon, Color color, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    ),
  );

  Future<void> _runVerify() async {
    if (_isOperationRunning || ref.read(verificationServiceProvider).isRunning) return;
    setState(() {
      _isOperationRunning = true;
      _verifyLoading = true;
      _verifyResult = null;
    });
    _lastProgressPercent = -1;
    _operationProgress.value = 0.0;
    try {
      final issues = await ref.read(repoServiceProvider).verifyAsync(onProgress: _updateProgress);
      if (mounted) setState(() => _verifyResult = issues);
    } catch (e) {
      _showOperationError(e);
    } finally {
      _operationProgress.value = null;
      if (mounted) {
        setState(() {
          _verifyLoading = false;
          _isOperationRunning = false;
        });
      }
    }
  }

  Future<void> _runRepair() async {
    if (_isOperationRunning || ref.read(verificationServiceProvider).isRunning) return;
    setState(() {
      _isOperationRunning = true;
      _repairLoading = true;
    });
    _lastProgressPercent = -1;
    _operationProgress.value = 0.0;
    try {
      final active = ref.read(currentActiveProvider);
      final channelName =
          active?.channel ?? ref.read(appSettingServiceProvider).remoteContent.channel;
      final channel = Channel.tryParse(channelName) ?? Channel.defaultChannel;
      final unresolved = await ref
          .read(repoServiceProvider)
          .verifyAndRepair(channel: channel, onProgress: _updateProgress);
      if (mounted) {
        setState(() => _verifyResult = unresolved);
        final l10n = context.l10n;
        final msg = unresolved.isEmpty
            ? l10n.storageRepairDone
            : l10n.storageRepairFailed(count: unresolved.length);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
      }
    } catch (e) {
      _showOperationError(e);
    } finally {
      _operationProgress.value = null;
      if (mounted) {
        setState(() {
          _repairLoading = false;
          _isOperationRunning = false;
        });
      }
    }
  }

  Future<void> _runPrune() async {
    if (_isOperationRunning || ref.read(verificationServiceProvider).isRunning) return;
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.storagePruneButton,
      content: Text(context.l10n.storagePruneConfirm),
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _isOperationRunning = true;
      _pruneLoading = true;
      _pruneCount = null;
    });
    _lastProgressPercent = -1;
    _operationProgress.value = 0.0;

    try {
      final count = await ref.read(repoServiceProvider).pruneAsync(onProgress: _updateProgress);
      if (mounted) setState(() => _pruneCount = count);
    } catch (e) {
      _showOperationError(e);
    } finally {
      _operationProgress.value = null;
      if (mounted) {
        setState(() {
          _pruneLoading = false;
          _isOperationRunning = false;
        });
      }
    }
  }

  Future<void> _runForceSync(String channelName) async {
    if (_isOperationRunning) return;
    setState(() {
      _isOperationRunning = true;
      _forceSyncLoading = true;
      _forceSyncResult = null;
    });
    _lastProgressPercent = -1;
    _operationProgress.value = 0.0;
    try {
      final result = await ref
          .read(repoServiceProvider)
          .syncChannelGeneration(channelName, onProgress: _updateProgress);
      if (!mounted) return;
      final l10n = context.l10n;
      final msg = result.match(
        (err) => "${l10n.storageForceSyncFailed}: $err",
        (_) => l10n.storageForceSyncDone,
      );
      setState(() => _forceSyncResult = msg);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
    } finally {
      _operationProgress.value = null;
      if (mounted) {
        setState(() {
          _forceSyncLoading = false;
          _isOperationRunning = false;
        });
      }
    }
  }

  Future<void> _runClearAll() async {
    if (_isOperationRunning) return;
    final l10n = context.l10n;
    final confirmed = await showConfirmDialog(
      context,
      title: l10n.storageClearAllButton,
      content: Text(l10n.storageClearAllConfirm),
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _isOperationRunning = true;
      _clearLoading = true;
    });
    try {
      final result = await ref.read(repoServiceProvider).clearAllStorage();
      if (!mounted) return;
      final msg = result.match(
        (err) => "${l10n.storageClearAllFailed}: $err",
        (_) => l10n.storageClearAllDone,
      );
      if (result.isLeft()) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        return;
      }
      await ref.read(repoStateProvider.notifier).initialize();
      if (!mounted) return;
      setState(() {
        _verifyResult = null;
        _pruneCount = null;
        _forceSyncResult = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
    } finally {
      if (mounted) {
        setState(() {
          _clearLoading = false;
          _isOperationRunning = false;
        });
      }
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  String _truncateHash(String hash) => hash.length > 8 ? hash.substring(0, 8) : hash;
}
