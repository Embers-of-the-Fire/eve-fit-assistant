import "dart:async";

import "package:eve_fit_assistant/pages/setting/data/batch_data_update_dialog.dart";
import "package:eve_fit_assistant/storage/repo/batch_data_update_status.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class DataUpdateBanner extends ConsumerStatefulWidget {
  const DataUpdateBanner({super.key});

  @override
  ConsumerState<DataUpdateBanner> createState() => _DataUpdateBannerState();
}

class _DataUpdateBannerState extends ConsumerState<DataUpdateBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(batchDataUpdateControllerProvider);

    if (status is! BatchDataUpdateStatusAvailable) {
      if (_dismissed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _dismissed = false);
        });
      }
      return const SizedBox.shrink();
    }

    if (_dismissed) return const SizedBox.shrink();

    final theme = context.theme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Card(
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          color: theme.colorScheme.primaryContainer,
          child: InkWell(
            onTap: () {},
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                children: [
                  Icon(Icons.update, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.dataUpdateBannerText,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      unawaited(showBatchDataUpdateOperationDialog(context, ref));
                    },
                    child: Text(context.l10n.dataUpdateActionUpdate),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.close,
                    onPressed: () => setState(() => _dismissed = true),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
