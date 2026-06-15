import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/branch_management/branch_tile.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class BranchListPage extends ConsumerWidget {
  const BranchListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider);
    final active = ref.watch(currentActiveProvider);
    final activeBranchId = active?.branchId;
    final updatesAsync = ref.watch(branchesWithUpdatesProvider(Channel.defaultChannel));

    final updates = switch (updatesAsync) {
      AsyncData(value: final v) => v,
      _ => const IMap<String, String?>.empty(),
    };

    return Layout(
      title: context.l10n.branchListTitle,
      floatingActionButton: FloatingActionButton(
        onPressed: () => unawaited(context.router.push(const BranchSetupRoute())),
        child: const Icon(Icons.add),
      ),
      child: branches.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.folder_open_outlined,
                    size: 64,
                    color: context.theme.colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(context.l10n.branchEmptyHint, style: context.theme.textTheme.bodyLarge),
                ],
              ),
            )
          : ListView(
              children: [
                const SizedBox(height: 8),
                for (final branch in branches)
                  BranchTile(
                    branch: branch,
                    active: branch.id == activeBranchId,
                    updateAvailable: updates[branch.id] != null,
                    onTap: () =>
                        unawaited(context.router.push(BranchDetailRoute(branchId: branch.id))),
                    onSetActive: () => _setActive(context, ref, branch),
                    onTogglePin: () => _togglePin(ref, branch),
                    onDelete: () => _confirmDelete(context, ref, branch),
                  ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  Future<void> _setActive(BuildContext context, WidgetRef ref, Branch branch) async {
    try {
      final active = Active(
        schemaVersion: 2,
        checkoutId: branch.checkout,
        activatedAt: DateTime.now().toUtc().toIso8601String(),
        serverId: branch.serverId,
        metadata: branch.metadata,
        branchId: branch.id,
      );
      await ref.read(activeServiceProvider).writeActive(active);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.branchSetActiveSuccess)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.branchSetActiveError(message: e.toString()))),
        );
      }
    }
  }

  void _togglePin(WidgetRef ref, Branch branch) {
    final service = ref.read(branchServiceProvider);
    if (branch.pinned) {
      service.unpinBranch(branch.id);
    } else {
      service.pinBranch(branch.id);
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Branch branch) async {
    final locale = context.locale.languageCode;
    final displayName = branch.name[locale] ?? branch.name["en"] ?? branch.id;
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.branchDeleteConfirmTitle,
      content: Text(context.l10n.branchDeleteConfirmContent(name: displayName)),
    );
    if (confirmed && context.mounted) {
      await ref.read(repoServiceProvider).deleteBranchWithDetach(branch.id);
    }
  }
}
