import "dart:async";

import "package:eve_fit_assistant/storage/repo/data_update_status.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

Future<void> showCheckoutDataUpdateOperationDialog(
  BuildContext context,
  WidgetRef ref,
  String checkoutId,
) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => CheckoutDataUpdateOperationDialog(checkoutId: checkoutId),
);

class CheckoutDataUpdateOperationDialog extends ConsumerWidget {
  const CheckoutDataUpdateOperationDialog({required this.checkoutId, super.key});

  final String checkoutId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(checkoutUpdateControllerProvider(checkoutId));
    final controller = ref.read(checkoutUpdateControllerProvider(checkoutId).notifier);

    return PopScope(
      canPop: status is! DataUpdateStatusDownloading,
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

  String _title(BuildContext context, DataUpdateStatus status) {
    final l10n = context.l10n;
    return switch (status) {
      DataUpdateStatusUnknown() ||
      DataUpdateStatusChecking() => l10n.dataUpdateTileCheckingSubtitle,
      DataUpdateStatusUpToDate() => l10n.dataUpdateTileUpToDateSubtitle,
      DataUpdateStatusAvailable() => l10n.checkoutUpdateDialogTitle,
      DataUpdateStatusDownloading() => l10n.dataUpdateDialogProgressTitle,
      DataUpdateStatusApplied() => l10n.dataUpdateDialogSuccessTitle,
      DataUpdateStatusFailed() => l10n.dataUpdateDialogFailureTitle,
    };
  }

  Widget _content(BuildContext context, DataUpdateStatus status) {
    final l10n = context.l10n;
    final theme = context.theme;

    switch (status) {
      case DataUpdateStatusUnknown() || DataUpdateStatusChecking():
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LinearProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.dataUpdateTileCheckingSubtitle),
          ],
        );
      case DataUpdateStatusUpToDate():
        return Text(l10n.dataUpdateTileUpToDateSubtitle);
      case DataUpdateStatusAvailable():
        return Text(l10n.checkoutUpdateDialogConfirmBody);
      case DataUpdateStatusDownloading(:final downloadedCount, :final totalCount):
        final fraction = totalCount > 0 ? downloadedCount / totalCount : 0.0;
        final percent = (fraction * 100).round();
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(value: totalCount > 0 ? fraction : null),
            const SizedBox(height: 16),
            Text(l10n.dataUpdateDialogProgressCount(count: downloadedCount, total: totalCount)),
            const SizedBox(height: 4),
            Text(
              "$percent%",
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline),
            ),
          ],
        );
      case DataUpdateStatusApplied():
        return Text(l10n.dataUpdateDialogSuccessBody);
      case DataUpdateStatusFailed(:final message):
        return Text("${l10n.dataUpdateDialogFailureBody}\n\n$message");
    }
  }

  List<Widget>? _actions(
    BuildContext context,
    DataUpdateStatus status,
    CheckoutUpdateController controller,
  ) {
    final l10n = context.l10n;
    switch (status) {
      case DataUpdateStatusUnknown() || DataUpdateStatusChecking():
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.dataUpdateDialogCancel),
          ),
        ];
      case DataUpdateStatusUpToDate():
        return [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.dataUpdateDialogDone),
          ),
        ];
      case DataUpdateStatusAvailable():
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
      case DataUpdateStatusDownloading():
        return null;
      case DataUpdateStatusApplied():
        return [
          ElevatedButton(
            onPressed: () {
              unawaited(controller.acknowledgeApplied());
              Navigator.of(context).pop();
            },
            child: Text(l10n.dataUpdateDialogDone),
          ),
        ];
      case DataUpdateStatusFailed(:final canRetry):
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
