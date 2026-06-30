import "dart:async";

import "package:eve_fit_assistant/storage/repo/batch_data_update_status.dart";
import "package:eve_fit_assistant/storage/repo/data_update_service.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

Future<void> showBatchDataUpdateOperationDialog(BuildContext context, WidgetRef ref) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const BatchDataUpdateOperationDialog(),
    );

class BatchDataUpdateOperationDialog extends ConsumerWidget {
  const BatchDataUpdateOperationDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(batchDataUpdateControllerProvider);
    final controller = ref.read(batchDataUpdateControllerProvider.notifier);

    return PopScope(
      canPop: status is! BatchDataUpdateStatusDownloading,
      child: AlertDialog(
        title: Text(_title(context, status)),
        insetPadding: const EdgeInsets.symmetric(vertical: 120, horizontal: 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: _content(context, status),
        ),
        actions: _actions(context, status, controller),
      ),
    );
  }

  String _title(BuildContext context, BatchDataUpdateStatus status) {
    final l10n = context.l10n;
    return switch (status) {
      BatchDataUpdateStatusUnknown() ||
      BatchDataUpdateStatusChecking() => l10n.dataUpdateTileCheckingSubtitle,
      BatchDataUpdateStatusUpToDate() => l10n.dataUpdateTileUpToDateSubtitle,
      BatchDataUpdateStatusAvailable() => l10n.dataUpdateDialogConfirmAllTitle,
      BatchDataUpdateStatusDownloading() => l10n.dataUpdateDialogProgressTitle,
      BatchDataUpdateStatusApplied() => l10n.dataUpdateDialogSuccessAllTitle,
      BatchDataUpdateStatusFailed() => l10n.dataUpdateDialogFailureAllTitle,
    };
  }

  Widget _content(BuildContext context, BatchDataUpdateStatus status) {
    final l10n = context.l10n;

    switch (status) {
      case BatchDataUpdateStatusUnknown() || BatchDataUpdateStatusChecking():
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.dataUpdateTileCheckingSubtitle),
          ],
        );
      case BatchDataUpdateStatusUpToDate():
        return Text(l10n.dataUpdateTileUpToDateSubtitle);
      case BatchDataUpdateStatusAvailable(:final newGenerationHashes):
        return Text(l10n.dataUpdateDialogConfirmAllBody(count: newGenerationHashes.length));
      case BatchDataUpdateStatusDownloading(:final progress):
        return _buildProgress(context, progress);
      case BatchDataUpdateStatusApplied(:final result):
        return _buildResult(context, result);
      case BatchDataUpdateStatusFailed(:final message):
        return Text("${l10n.dataUpdateDialogFailureAllBody}\n\n$message");
    }
  }

  Widget _buildProgress(BuildContext context, BatchUpdateProgress progress) {
    final l10n = context.l10n;
    final theme = context.theme;
    final overallFraction = progress.totalCount > 0
        ? progress.completedCount / progress.totalCount
        : 0.0;
    final downloadFraction = progress.totalDownloadCount > 0
        ? progress.downloadedCount / progress.totalDownloadCount
        : 0.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dataUpdateDialogOverallProgress(
            current: progress.completedCount,
            total: progress.totalCount,
          ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress.totalCount > 0 ? overallFraction : null),
        const SizedBox(height: 16),
        Text(
          progress.currentCheckoutId.isEmpty
              ? l10n.dataUpdateDialogProgressTitle
              : l10n.dataUpdateDialogCheckoutProgress(
                  checkoutId: progress.currentCheckoutId,
                  count: progress.downloadedCount,
                  total: progress.totalDownloadCount,
                ),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: progress.totalDownloadCount > 0 ? downloadFraction : null),
        const SizedBox(height: 8),
        Text(
          "${(downloadFraction * 100).round()}%",
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }

  Widget _buildResult(BuildContext context, BatchUpdateResult result) {
    final l10n = context.l10n;
    final theme = context.theme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dataUpdateDialogSuccessAllBody(
            success: result.successes.length,
            skipped: result.skipped.length,
            failed: result.failures.length,
          ),
        ),
        if (result.failures.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            l10n.dataUpdateDialogFailureAllBody,
            style: TextStyle(color: theme.colorScheme.error),
          ),
          const SizedBox(height: 8),
          ...result.failures.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text("${e.key}: ${e.value}", style: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget>? _actions(
    BuildContext context,
    BatchDataUpdateStatus status,
    BatchDataUpdateController controller,
  ) {
    final l10n = context.l10n;
    switch (status) {
      case BatchDataUpdateStatusUnknown() || BatchDataUpdateStatusChecking():
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.dataUpdateDialogCancel),
          ),
        ];
      case BatchDataUpdateStatusUpToDate():
        return [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.dataUpdateDialogDone),
          ),
        ];
      case BatchDataUpdateStatusAvailable():
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.dataUpdateDialogCancel),
          ),
          ElevatedButton(
            onPressed: () => unawaited(controller.apply()),
            child: Text(l10n.dataUpdateActionUpdate),
          ),
        ];
      case BatchDataUpdateStatusDownloading():
        return null;
      case BatchDataUpdateStatusApplied():
        return [
          ElevatedButton(
            onPressed: () {
              controller.acknowledgeApplied();
              Navigator.of(context).pop();
            },
            child: Text(l10n.dataUpdateDialogDone),
          ),
        ];
      case BatchDataUpdateStatusFailed(:final canRetry):
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.dataUpdateDialogClose),
          ),
          if (canRetry)
            ElevatedButton(
              onPressed: () => unawaited(controller.apply()),
              child: Text(l10n.dataUpdateActionRetry),
            ),
        ];
    }
  }
}
