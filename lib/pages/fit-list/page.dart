import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/icon/eve_icon.dart";
import "package:eve_fit_assistant/components/list/eve_list_tile.dart";
import "package:eve_fit_assistant/features/fit_io/export_dialog.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/datetime.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_slidable/flutter_slidable.dart";

/// The fit list is embedded in the front page, so this widget only owns the
/// list content and leaves top-level navigation chrome to its parent.
class FitListPage extends ConsumerWidget {
  const FitListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fits = ref.watch(
      fitRegistryManagerProvider.select(
        (registry) =>
            registry.fits.values.toList()
              ..sort((left, right) => right.lastModified.compareTo(left.lastModified)),
      ),
    );

    return fits.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 56,
                    color: context.theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.workspaceTabActionCreateFitName,
                    style: context.theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.l10n.frontPageTitleFitList,
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: context.theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          )
        : RefreshIndicator(
            onRefresh: () async => ref.invalidate(fitRegistryManagerProvider),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              itemCount: fits.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) => _FitListTile(metadata: fits[index]),
            ),
          );
  }
}

class _FitListTile extends ConsumerWidget {
  const _FitListTile({required this.metadata});

  final FitMetadata metadata;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final typeInfo = ref.watch(bundleCollectionGetTypeProvider(metadata.shipTypeId));
    final metaGroupIcon = typeInfo == null
        ? null
        : ref.watch(
            bundleCollectionGetMetaGroupProvider(typeInfo.metaGroupId).select((t) => t?.icon),
          );
    final lastModified = yMMMMdHmsLocalized(
      context,
    ).format(DateTime.fromMillisecondsSinceEpoch(metadata.lastModified).toLocal());

    return Slidable(
      key: ValueKey(metadata.fitId),
      startActionPane: ActionPane(
        extentRatio: 0.18,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => showFitExportDialog(context, fitId: metadata.fitId),
            backgroundColor: context.theme.colorScheme.secondaryContainer,
            foregroundColor: context.theme.colorScheme.onSecondaryContainer,
            icon: Icons.ios_share_outlined,
            label: context.l10n.fitListActionExport,
          ),
        ],
      ),
      endActionPane: ActionPane(
        extentRatio: 0.18,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) async {
              // Deletion stays behind a confirmation step so swipe gestures do
              // not remove local fit files by accident.
              final result = await showConfirmDialog(
                context,
                title: context.l10n.fitCreationPageDialogDeleteFitTitle,
                content: Text(
                  context.l10n.fitCreationPageDialogDeleteFitContent(fitName: metadata.name),
                ),
              );
              if (!result) return;
              await ref.read(fitManagerProvider.notifier).deleteFit(metadata.fitId);
            },
            backgroundColor: context.theme.colorScheme.error,
            foregroundColor: context.theme.colorScheme.onError,
            icon: Icons.delete_forever,
            label: context.l10n.delete,
          ),
        ],
      ),
      child: ListTile(
        leading: typeInfo == null
            ? const Icon(Icons.help_outline)
            : EveIcon(icon: typeInfo.icon, overlayIcon: metaGroupIcon),
        title: Text(metadata.name),
        subtitle: Row(
          children: [
            Expanded(child: TypeNameText(typeId: metadata.shipTypeId)),
            const SizedBox(width: 12),
            Text(lastModified),
          ],
        ),
        onTap: () => context.router.push(FitRoute(fitId: metadata.fitId)),
      ),
    );
  }
}
