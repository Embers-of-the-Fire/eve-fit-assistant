import "dart:async";

import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/pages/setting/data/batch_data_update_dialog.dart";
import "package:eve_fit_assistant/storage/repo/batch_data_update_status.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class DataUpdateTile extends ConsumerStatefulWidget {
  const DataUpdateTile({super.key});

  @override
  ConsumerState<DataUpdateTile> createState() => _DataUpdateTileState();
}

class _DataUpdateTileState extends ConsumerState<DataUpdateTile> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(ref.read(batchDataUpdateControllerProvider.notifier).ensureCheck());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = ref.watch(batchDataUpdateControllerProvider);

    return ListTile(
      leading: const Icon(Icons.storage),
      title: Text(_title(l10n, status)),
      subtitle: Text(_subtitle(l10n, status)),
      trailing: _trailing(status),
      enabled:
          status is! BatchDataUpdateStatusChecking && status is! BatchDataUpdateStatusDownloading,
      onTap: () => _onTap(context, status),
    );
  }

  String _title(AppLocalizations l10n, BatchDataUpdateStatus status) => switch (status) {
    BatchDataUpdateStatusAvailable() => l10n.dataUpdateTileUpdateAllTitle,
    BatchDataUpdateStatusFailed() => l10n.dataUpdateTileFailedTitle,
    _ => l10n.dataUpdateTileTitle,
  };

  String _subtitle(AppLocalizations l10n, BatchDataUpdateStatus status) => switch (status) {
    BatchDataUpdateStatusUnknown() => l10n.dataUpdateTileUpdateAllSubtitle,
    BatchDataUpdateStatusChecking() => l10n.dataUpdateTileCheckingSubtitle,
    BatchDataUpdateStatusUpToDate() => l10n.dataUpdateTileUpToDateSubtitle,
    BatchDataUpdateStatusAvailable() => l10n.dataUpdateTileAvailableSubtitle,
    BatchDataUpdateStatusDownloading() => l10n.dataUpdateTileDownloadingSubtitle,
    BatchDataUpdateStatusApplied() => l10n.dataUpdateTileAppliedSubtitle,
    BatchDataUpdateStatusFailed(:final message) => message,
  };

  Widget? _trailing(BatchDataUpdateStatus status) {
    final theme = context.theme;
    return switch (status) {
      BatchDataUpdateStatusUnknown() ||
      BatchDataUpdateStatusUpToDate() ||
      BatchDataUpdateStatusApplied() => Text(
        context.l10n.dataUpdateActionCheck,
        style: TextStyle(color: theme.colorScheme.primary),
      ),
      BatchDataUpdateStatusChecking() || BatchDataUpdateStatusDownloading() => SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.primary),
      ),
      BatchDataUpdateStatusAvailable() => Text(
        context.l10n.dataUpdateActionUpdate,
        style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
      ),
      BatchDataUpdateStatusFailed(:final canRetry) =>
        canRetry
            ? Text(
                context.l10n.dataUpdateActionRetry,
                style: TextStyle(color: theme.colorScheme.error),
              )
            : const Icon(Icons.error_outline, color: Colors.red),
    };
  }

  void _onTap(BuildContext context, BatchDataUpdateStatus status) {
    final controller = ref.read(batchDataUpdateControllerProvider.notifier);
    switch (status) {
      case BatchDataUpdateStatusUnknown():
      case BatchDataUpdateStatusUpToDate():
      case BatchDataUpdateStatusApplied():
        unawaited(controller.check());
      case BatchDataUpdateStatusAvailable():
        unawaited(showBatchDataUpdateOperationDialog(context, ref));
      case BatchDataUpdateStatusFailed(:final canRetry):
        if (canRetry) {
          unawaited(controller.apply());
        }
      case BatchDataUpdateStatusChecking():
      case BatchDataUpdateStatusDownloading():
        break;
    }
  }
}
