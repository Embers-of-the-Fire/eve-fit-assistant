import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/verification.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

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

  @override
  Widget build(BuildContext context) {
    final checkoutIds = ref.watch(installedCheckoutIdsProvider);
    final l10n = context.l10n;

    return Layout(
      title: l10n.storagePageTitle,
      child: ConfigListView(
        children: [
          const ConfigListTile.space(20),
          ConfigListTile.title(l10n.storageStateInstalled),
          if (checkoutIds.isEmpty)
            ConfigListTile.custom(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(l10n.storageNoCheckouts, style: context.theme.textTheme.bodyMedium),
              ),
            )
          else
            ...checkoutIds.map(_checkoutTile),
          const ConfigListTile.space(16),
          ConfigListTile.title(l10n.storageVerifyButton),
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
          const ConfigListTile.space(16),
          ConfigListTile.title(l10n.storagePruneButton),
          ConfigListTile.item(
            icon: Icon(Icons.cleaning_services_outlined, color: context.theme.colorScheme.error),
            title: l10n.storagePruneButton,
            subtitle: _pruneLoading
                ? l10n.storagePruneRunning
                : _pruneCount != null
                ? l10n.storagePrunedCount(count: _pruneCount!)
                : l10n.storageCacheInfoHint,
            onTap: _pruneLoading ? null : _runPrune,
          ),
          const ConfigListTile.space(16),
          ConfigListTile.title(l10n.storageAssetStoreSize),
          ConfigListTile.custom(_buildAssetStoreInfo(checkoutIds)),
        ],
      ),
    );
  }

  ConfigListTile _checkoutTile(String checkoutId) {
    final manifest = ref.watch(checkoutServiceProvider).readManifest(checkoutId);
    final displayHash = checkoutId.length > 12 ? checkoutId.substring(0, 12) : checkoutId;
    final fileCount = manifest.fold(() => 0, (m) => m.files.length);
    final totalSize = manifest.fold(
      () => 0,
      (m) => m.files.values.fold(0, (sum, f) => sum + f.size),
    );
    final l10n = context.l10n;

    return ConfigListTile.item(
      icon: const Icon(Icons.inventory_2_outlined),
      title: displayHash,
      subtitle: manifest.isNone()
          ? l10n.storageNoManifest
          : "${l10n.storageFiles}: $fileCount, ${l10n.storageSize}: ${_formatSize(totalSize)}",
      onTap: () {
        unawaited(Clipboard.setData(ClipboardData(text: checkoutId)));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.storageCopyHash), duration: const Duration(seconds: 1)),
        );
      },
    );
  }

  Widget _buildVerifyResults() {
    final issues = _verifyResult;
    if (issues == null) return const SizedBox.shrink();

    final l10n = context.l10n;

    if (issues.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            Text(l10n.storageVerifiedOk),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: issues.map((issue) {
          final hash = _truncateHash(issue.checkoutId);
          if (issue is VerificationMissingFiles) {
            final missingCount = issue.missingFiles.missing.length;
            final mismatchCount = issue.missingFiles.hashMismatches.length;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "$hash: ${l10n.storageMissingFiles(count: missingCount)}, ${l10n.storageHashMismatches(count: mismatchCount)}",
                    ),
                  ),
                ],
              ),
            );
          }
          if (issue is VerificationNoManifest) {
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

  Widget _buildAssetStoreInfo(IList<String> checkoutIds) {
    final l10n = context.l10n;
    final seen = <String>{};
    var totalSize = 0;
    var totalFiles = 0;
    for (final id in checkoutIds) {
      final manifest = ref.watch(checkoutServiceProvider).readManifest(id);
      if (manifest.isSome()) {
        for (final file in manifest.toNullable()!.files.values) {
          if (seen.add(file.hash)) {
            totalFiles++;
            totalSize += file.size;
          }
        }
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("${l10n.storageFileCount}: $totalFiles"),
          Text("${l10n.storageTotalSize}: ${_formatSize(totalSize)}"),
          const SizedBox(height: 8),
          Text(
            l10n.storageCacheInfoHint,
            style: context.theme.textTheme.bodySmall?.copyWith(
              color: context.theme.colorScheme.outline,
            ),
          ),
        ],
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

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  String _truncateHash(String hash) => hash.length > 8 ? hash.substring(0, 8) : hash;
}
