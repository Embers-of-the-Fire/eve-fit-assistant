import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/clickable/circle_avatar.dart";
import "package:eve_fit_assistant/components/color.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/bundle/impact.dart";
import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/service.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/datetime.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:file_picker/file_picker.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

part "bundle_detail.dart";
part "bundle_tile.dart";
part "impact_warning.dart";

@RoutePage()
class BundleManagerPage extends ConsumerWidget {
  const BundleManagerPage({super.key});

  Future<void> _importBundleArchive(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.pickFiles();
    if (!context.mounted || result == null) return;

    final selected = result.xFiles.first;
    info("Selected file: ${selected.name}");
    await ref
        .read(bundleManagerProvider.notifier)
        .addBundle(
          selected.path,
          confirmOverwrite: () async {
            if (!context.mounted) return false;
            return showConfirmDialog(context, title: context.l10n.bundleImportOverwriteTitle);
          },
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundleRegistry = ref.watch(bundleRegistryManagerProvider);
    final bundleState = ref.watch(bundleServiceProvider);
    final activeBundleId = ref.watch(currentBundleProvider)?.bundleId;
    final pendingBundleId = bundleState.isInitializing
        ? ref.read(bundleServiceProvider.notifier).pendingBundleId ?? bundleState.bundleId
        : null;
    final activeBundle = activeBundleId == null ? null : bundleRegistry.bundles[activeBundleId];

    return Layout(
      title: context.l10n.bundleManagerPageTitle,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _importBundleArchive(context, ref),
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      child: ListView(
        children: [
          const SizedBox(height: 10),
          _BundleStatusCard(
            bundleCount: bundleRegistry.bundles.length,
            activeBundleId: activeBundleId,
            pendingBundleId: pendingBundleId,
            state: bundleState,
            onImportPressed: () => _importBundleArchive(context, ref),
          ),
          if (activeBundle != null)
            _BundleTile(
              bundle: activeBundle,
              activated: true,
              pending: pendingBundleId == activeBundle.bundleId,
            ),
          for (final entry in bundleRegistry.bundles.entries.where(
            (entry) => entry.key != activeBundle?.bundleId,
          ))
            _BundleTile(bundle: entry.value, pending: pendingBundleId == entry.key),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _BundleStatusCard extends StatelessWidget {
  const _BundleStatusCard({
    required this.bundleCount,
    required this.activeBundleId,
    required this.pendingBundleId,
    required this.state,
    required this.onImportPressed,
  });

  final int bundleCount;
  final String? activeBundleId;
  final String? pendingBundleId;
  final CurrentBundleStatus state;
  final VoidCallback onImportPressed;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colorScheme = theme.colorScheme;
    final scopeDetails = <String>[
      context.l10n.bundleManagerAlphaScope,
      context.l10n.bundleManagerImportSelectionBehavior,
    ];
    final info = bundleCount == 0
        ? (
            icon: Icons.archive_outlined,
            color: colorScheme.primary,
            title: context.l10n.bundleManagerSetupTitle,
            description: context.l10n.bundleManagerSetupDescription,
            details: scopeDetails,
          )
        : state.when(
            notSelected: () => (
              icon: Icons.archive_outlined,
              color: colorScheme.secondary,
              title: context.l10n.bundleManagerSelectionTitle,
              description: context.l10n.bundleManagerSelectionDescription,
              details: scopeDetails,
            ),
            initializing: (bundleId) => (
              icon: Icons.sync,
              color: colorScheme.primary,
              title: context.l10n.bundleManagerLoadingTitle,
              description: context.l10n.bundleManagerLoadingDescription(bundleId: bundleId),
              details: [
                ...scopeDetails,
                if (activeBundleId != null)
                  context.l10n.bundleManagerReadyDescription(bundleId: activeBundleId!),
              ],
            ),
            error: (errors) => (
              icon: Icons.error_outline,
              color: colorScheme.error,
              title: context.l10n.bundleManagerInvalidTitle,
              description: context.l10n.bundleManagerInvalidDescription,
              details: [
                ...scopeDetails,
                ...errors.map((error) => _formatBundleError(context, error)),
              ],
            ),
            loaded: (data) => (
              icon: Icons.check_circle_outline,
              color: colorGreen,
              title: context.l10n.bundleManagerReadyTitle,
              description: context.l10n.bundleManagerReadyDescription(bundleId: data.bundleId),
              details: scopeDetails,
            ),
          );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(info.icon, color: info.color),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.title,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(info.description, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
            if (info.details.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final detail in info.details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(detail, style: theme.textTheme.bodySmall),
                ),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onImportPressed,
              icon: const Icon(Icons.upload_file),
              label: Text(context.l10n.bundleManagerImportAction),
            ),
          ],
        ),
      ),
    );
  }

  String _formatBundleError(BuildContext context, BundleValidationError error) => error.when(
    missingPath: (path) => context.l10n.bundleManagerErrorMissingPath(path: path),
    expectFile: (fileName) => context.l10n.bundleManagerErrorExpectFile(fileName: fileName),
    expectDirectory: (dirName) => context.l10n.bundleManagerErrorExpectDirectory(dirName: dirName),
    badDescriptor: (_) => context.l10n.bundleManagerErrorBadDescriptor,
    badPatch: (reason) => context.l10n.bundleManagerErrorBadPatch(reason: reason),
  );
}
