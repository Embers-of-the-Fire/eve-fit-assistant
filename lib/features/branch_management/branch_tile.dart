import "dart:async";

import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class BranchTile extends ConsumerWidget {
  const BranchTile({
    required this.branch,
    required this.active,
    required this.updateAvailable,
    required this.onTap,
    required this.onSetActive,
    required this.onTogglePin,
    required this.onDelete,
    super.key,
  });

  final Branch branch;
  final bool active;
  final bool updateAvailable;
  final VoidCallback onTap;
  final VoidCallback onSetActive;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final locale = context.locale.languageCode;
    final displayName = branch.name[locale] ?? branch.name["en"] ?? branch.id;
    final metadata = branch.metadata;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        onTap: onTap,
        onLongPress: () => _showContextMenu(context),
        leading: Icon(
          active ? Icons.check_circle : Icons.circle_outlined,
          color: active ? theme.colorScheme.primary : theme.colorScheme.outline,
        ),
        title: Text(
          displayName,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text("${context.l10n.branchServerLabel}: ${metadata.gameServer}"),
            Text("${context.l10n.branchBuildLabel}: ${metadata.gameBuild}"),
            Row(
              children: [
                if (active)
                  _StatusChip(
                    label: context.l10n.branchActiveBadge,
                    color: theme.colorScheme.primary,
                  ),
                if (branch.pinned)
                  _StatusChip(
                    label: context.l10n.branchPinnedBadge,
                    color: theme.colorScheme.secondary,
                  ),
                if (updateAvailable)
                  _StatusChip(
                    label: context.l10n.branchUpdateAvailable,
                    color: theme.colorScheme.tertiary,
                  ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: Text(context.l10n.branchActionSetActive),
                onTap: () {
                  Navigator.pop(ctx);
                  onSetActive();
                },
              ),
              ListTile(
                leading: Icon(branch.pinned ? Icons.push_pin : Icons.push_pin_outlined),
                title: Text(
                  branch.pinned ? context.l10n.branchActionUnpin : context.l10n.branchActionPin,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  onTogglePin();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(context.l10n.branchActionDelete),
                onTap: () {
                  Navigator.pop(ctx);
                  onDelete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6, top: 2),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(label, style: context.theme.textTheme.labelSmall?.copyWith(color: color)),
      ),
    ),
  );
}
