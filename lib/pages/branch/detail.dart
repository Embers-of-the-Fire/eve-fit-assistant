import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/branch_management/diff_summary.dart";
import "package:eve_fit_assistant/features/branch_management/reflog_timeline.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/storage/repo/models/diff.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class BranchDetailPage extends ConsumerWidget {
  const BranchDetailPage({required this.branchId, super.key});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(branchesProvider);
    final branch = branches.where((b) => b.id == branchId).firstOrNull;
    final active = ref.watch(currentActiveProvider);
    final isActive = active?.branchId == branchId;

    if (branch == null) {
      return Layout(
        title: context.l10n.branchDetailTitle,
        child: const Center(child: Text("Branch not found")),
      );
    }

    final locale = context.locale.languageCode;
    final displayName = branch.name[locale] ?? branch.name["en"] ?? branch.id;
    final reflog = branch.reflog;
    final diffs = branch.diffs;

    return Layout(
      title: displayName,
      child: ListView(
        children: [
          const SizedBox(height: 8),
          _HeaderSection(branch: branch, isActive: isActive),
          const SizedBox(height: 8),
          if (reflog.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                context.l10n.branchReflogTitle,
                style: context.theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ReflogTimeline(reflog: reflog, diffs: diffs),
            ),
            const SizedBox(height: 8),
            _ReflogEntryDiffs(reflog: reflog, diffs: diffs),
          ],
          const SizedBox(height: 16),
          _ActionButtons(branch: branch, isActive: isActive, branchId: branchId),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _HeaderSection extends ConsumerWidget {
  const _HeaderSection({required this.branch, required this.isActive});

  final Branch branch;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = context.theme;
    final metadata = branch.metadata;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _branchDisplayName(context, branch),
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    final service = ref.read(branchServiceProvider);
                    if (branch.pinned) {
                      service.unpinBranch(branch.id);
                    } else {
                      service.pinBranch(branch.id);
                    }
                  },
                  icon: Icon(
                    branch.pinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: branch.pinned ? theme.colorScheme.primary : null,
                  ),
                  tooltip: branch.pinned
                      ? context.l10n.branchActionUnpin
                      : context.l10n.branchActionPin,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _MetadataRow(label: context.l10n.branchServerLabel, value: metadata.gameServer),
            _MetadataRow(label: context.l10n.branchBuildLabel, value: metadata.gameBuild),
            _MetadataRow(label: "${context.l10n.branchServerLabel} ID", value: branch.serverId),
            _MetadataRow(
              label: context.l10n.branchSourceLabel,
              value:
                  "channel: ${branch.source.channel}${branch.source.remoteCheckoutId != null ? ", checkout: ${branch.source.remoteCheckoutId}" : ""}",
            ),
            if (isActive)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Chip(
                  avatar: Icon(Icons.check, size: 16, color: theme.colorScheme.primary),
                  label: Text(context.l10n.branchActiveBadge),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _branchDisplayName(BuildContext context, Branch branch) {
    final locale = context.locale.languageCode;
    return branch.name[locale] ?? branch.name["en"] ?? branch.id;
  }
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: "$label: ",
            style: context.theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          TextSpan(text: value),
        ],
      ),
      style: context.theme.textTheme.bodyMedium,
    ),
  );
}

class _ReflogEntryDiffs extends StatelessWidget {
  const _ReflogEntryDiffs({required this.reflog, required this.diffs});

  final IList<ReflogEntry> reflog;
  final IMap<String, Diff> diffs;

  @override
  Widget build(BuildContext context) {
    if (reflog.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in reflog.toList().reversed)
            if (diffs[entry.id] != null) DiffSummary(diff: diffs[entry.id]!),
        ],
      ),
    );
  }
}

class _ActionButtons extends ConsumerWidget {
  const _ActionButtons({required this.branch, required this.isActive, required this.branchId});

  final Branch branch;
  final bool isActive;
  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!isActive)
          FilledButton.icon(
            onPressed: () => _setActive(context, ref),
            icon: const Icon(Icons.check_circle_outline),
            label: Text(context.l10n.branchActionSetActive),
          ),
        if (!isActive) const SizedBox(height: 8),
        if (isActive && branch.reflog.length > 1)
          OutlinedButton.icon(
            onPressed: () => _showRevertOptions(context, ref),
            icon: const Icon(Icons.history),
            label: Text(context.l10n.branchRevertTitle),
          ),
      ],
    ),
  );

  Future<void> _setActive(BuildContext context, WidgetRef ref) async {
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

  void _showRevertOptions(BuildContext context, WidgetRef ref) {
    final reflog = branch.reflog.toList();
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  context.l10n.branchRevertTitle,
                  style: context.theme.textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              for (var i = reflog.length - 1; i >= 0; i--)
                ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(_shortHash(reflog[i].to)),
                  subtitle: Text(reflog[i].timestamp),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final targetId = reflog[i].to;
                    if (targetId.isEmpty) return;
                    final confirmed = await showConfirmDialog(
                      context,
                      title: context.l10n.branchRevertTitle,
                      content: Text(
                        context.l10n.branchRevertConfirm(checkoutId: _shortHash(targetId)),
                      ),
                    );
                    if (confirmed && context.mounted) {
                      final result = await ref
                          .read(repoServiceProvider)
                          .revertActiveBranchTo(
                            targetCheckoutId: targetId,
                            channel: Channel.defaultChannel,
                          );
                      if (result.isSome() && context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(result.toNullable()!)));
                      }
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _shortHash(String hash) {
  if (hash.isEmpty) return "(empty)";
  return hash.length <= 8 ? hash : hash.substring(0, 8);
}
