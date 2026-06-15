import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/features/branch_management/branch_tile.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage(name: "BranchSettings")
class BranchSettingsPage extends ConsumerStatefulWidget {
  const BranchSettingsPage({super.key});

  @override
  ConsumerState<BranchSettingsPage> createState() => _BranchSettingsPageState();
}

class _BranchSettingsPageState extends ConsumerState<BranchSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final branches = ref.watch(branchesProvider);
    final active = ref.watch(currentActiveProvider);
    final l10n = context.l10n;

    return Layout(
      title: l10n.branchSettingsTitle,
      child: ConfigListView(
        children: [
          const ConfigListTile.space(20),
          if (branches.isEmpty)
            ConfigListTile.custom(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(l10n.branchEmptyHint, style: context.theme.textTheme.bodyMedium),
              ),
            )
          else
            ...branches.map(
              (branch) => ConfigListTile.custom(
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: BranchTile(
                    branch: branch,
                    active: active?.branchId == branch.id,
                    updateAvailable: false,
                    onTap: () =>
                        unawaited(context.router.push(BranchDetailRoute(branchId: branch.id))),
                    onSetActive: () => _setActive(branch),
                    onTogglePin: () => _togglePin(branch),
                    onDelete: () => _delete(branch),
                  ),
                ),
              ),
            ),
          ConfigListTile.custom(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: OutlinedButton.icon(
                onPressed: () => unawaited(_showRenameDialog()),
                icon: const Icon(Icons.edit_outlined),
                label: Text(l10n.branchRenameTitle),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setActive(Branch branch) async {
    final repo = ref.read(repoServiceProvider);
    final active = repo.activeBranch();
    if (active.isNone() || !mounted) return;
    final a = active.toNullable()!;
    await ref
        .read(activeServiceProvider)
        .writeActive(a.copyWith(branchId: branch.id, checkoutId: branch.checkout));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.branchActiveSetSuccess)));
  }

  Future<void> _togglePin(Branch branch) async {
    final branchService = ref.read(branchServiceProvider);
    if (branch.pinned) {
      branchService.unpinBranch(branch.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.branchUnpinSuccess)));
    } else {
      branchService.pinBranch(branch.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.branchPinSuccess)));
    }
  }

  Future<void> _delete(Branch branch) async {
    final locale = context.locale.languageCode;
    final displayName = branch.name[locale] ?? branch.name["en"] ?? branch.id;
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.branchDeleteConfirmTitle,
      content: Text(context.l10n.branchDeleteConfirmContent(name: displayName)),
    );
    if (!confirmed || !mounted) return;

    await ref.read(repoServiceProvider).deleteBranchWithDetach(branch.id);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.branchDeleteSuccess)));
  }

  Future<void> _showRenameDialog() async {
    final branches = ref.read(branchesProvider);
    if (branches.isEmpty || !mounted) return;

    final branch = await showDialog<Branch>(
      context: context,
      builder: (ctx) => _BranchPickerDialog(branches: branches),
    );
    if (branch == null || !mounted) return;

    final locale = context.locale.languageCode;
    final currentName = branch.name[locale] ?? branch.name["en"] ?? branch.id;
    final nameController = TextEditingController(text: currentName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.branchRenameTitle),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(hintText: context.l10n.branchRenameHint),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.cancel)),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, nameController.text.trim());
              }
            },
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
    nameController.dispose();

    if (newName == null || !mounted) return;

    final updatedName = branch.name.add(locale, newName);
    ref.read(branchServiceProvider).renameBranch(branch.id, updatedName);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.branchRenameSuccess)));
  }
}

class _BranchPickerDialog extends ConsumerWidget {
  const _BranchPickerDialog({required this.branches});

  final IList<Branch> branches;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AlertDialog(
    title: Text(context.l10n.branchRenameTitle),
    content: ConstrainedBox(
      constraints: BoxConstraints(maxHeight: context.mediaQuery.size.height * 0.5),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: branches.length,
        itemBuilder: (context, index) {
          final branch = branches[index];
          final locale = context.locale.languageCode;
          final displayName = branch.name[locale] ?? branch.name["en"] ?? branch.id;
          return ListTile(
            title: Text(displayName),
            subtitle: Text(branch.id),
            onTap: () => Navigator.pop(context, branch),
          );
        },
      ),
    ),
  );
}
