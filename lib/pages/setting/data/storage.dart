import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/pages/setting/data/data_update_tile.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/verification.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fpdart/fpdart.dart";

class StorageOverview {
  const StorageOverview({required this.fileCount, required this.totalSize});

  final int fileCount;
  final int totalSize;
}

final storageOverviewProvider = FutureProvider<StorageOverview>((ref) async {
  final checkoutIds = ref.watch(installedCheckoutIdsProvider);
  final registryService = ref.watch(checkoutRegistryServiceProvider);
  final assetStore = ref.watch(assetStoreProvider);

  final seen = <String>{};
  var totalSize = 0;
  var totalFiles = 0;

  for (final id in checkoutIds) {
    final entry = registryService.readRegistry().flatMap(
      (r) => Option.fromNullable(r.checkouts[id]),
    );
    if (entry.isNone()) continue;
    final ri = assetStore.readResourceIndexSync(entry.toNullable()!.resourceSnapshotHash);
    if (ri.isNone()) continue;
    for (final file in ri.toNullable()!.entries) {
      if (seen.add(file.resourceId)) {
        totalFiles++;
        totalSize += file.size.toInt();
      }
    }
  }

  return StorageOverview(fileCount: totalFiles, totalSize: totalSize);
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
  bool _forceSyncLoading = false;
  String? _forceSyncResult;
  bool _clearLoading = false;
  bool _isOperationRunning = false;

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
              onTap: _verifyLoading ? null : _runVerify,
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
              onTap: _pruneLoading ? null : _runPrune,
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

    final genHash = ref.watch(channelServiceProvider).localGenerationHash(channelName);
    final headMeta = ref.watch(channelServiceProvider).readHeadMeta(channelName);
    final metadata = genHash == null
        ? l10n.storageNeverSynced
        : "$channelName · ${_truncateHash(genHash)}";
    final lastUpdated = headMeta.fold(() => l10n.storageNeverSynced, (m) => m.updatedAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _overviewRow(l10n.storageFileCount, "${overview.fileCount}"),
          _overviewRow(l10n.storageTotalSize, _formatSize(overview.totalSize)),
          _overviewRow(l10n.storageMetadata, metadata),
          _overviewRow(l10n.storageLastUpdated, lastUpdated),
          const SizedBox(height: 8),
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

  Widget _buildVerifyResults() {
    final issues = _verifyResult;
    if (issues == null || issues.isEmpty) return const SizedBox.shrink();

    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: issues.map((issue) {
          final hash = _truncateHash(issue.checkoutId);
          if (issue is VerificationMissingFiles) {
            final missingCount = issue.missingIdents.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text("$hash: ${l10n.storageMissingFiles(count: missingCount)}")),
                ],
              ),
            );
          }
          if (issue is VerificationNoMeta) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text("$hash: ${l10n.storageNoManifest}")),
                ],
              ),
            );
          }
          if (issue is VerificationPartialDownload) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.downloading_outlined, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text("$hash: ${issue.reason}")),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        }).toList(),
      ),
    );
  }

  Future<void> _runVerify() async {
    setState(() {
      _verifyLoading = true;
      _verifyResult = null;
    });
    try {
      final issues = ref.read(repoServiceProvider).verify();
      if (mounted) setState(() => _verifyResult = issues);
    } finally {
      if (mounted) setState(() => _verifyLoading = false);
    }
  }

  Future<void> _runPrune() async {
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.storagePruneButton,
      content: Text(context.l10n.storagePruneConfirm),
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _pruneLoading = true;
      _pruneCount = null;
    });

    try {
      final count = ref.read(repoServiceProvider).prune();
      if (mounted) setState(() => _pruneCount = count);
    } finally {
      if (mounted) setState(() => _pruneLoading = false);
    }
  }

  Future<void> _runForceSync(String channelName) async {
    if (_isOperationRunning) return;
    setState(() {
      _isOperationRunning = true;
      _forceSyncLoading = true;
      _forceSyncResult = null;
    });
    try {
      final result = await ref.read(repoServiceProvider).syncChannelGeneration(channelName);
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
