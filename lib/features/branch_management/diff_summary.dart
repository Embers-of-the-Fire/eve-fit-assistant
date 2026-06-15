import "package:eve_fit_assistant/storage/repo/models/diff.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";

class DiffSummary extends StatelessWidget {
  const DiffSummary({required this.diff, super.key});

  final Diff diff;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title(context),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _DiffStatRow(
              label: context.l10n.branchDiffAdds(count: diff.adds.length),
              count: diff.adds.length,
              color: theme.colorScheme.primary,
            ),
            _DiffStatRow(
              label: context.l10n.branchDiffDeletes(count: diff.deletes.length),
              count: diff.deletes.length,
              color: theme.colorScheme.error,
            ),
            _DiffStatRow(
              label: context.l10n.branchDiffModifies(count: diff.modifies.length),
              count: diff.modifies.length,
              color: theme.colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }

  String _title(BuildContext context) {
    final fromStr = _shortHash(diff.from);
    final toStr = _shortHash(diff.to);
    return "$fromStr \u2192 $toStr";
  }
}

class _DiffStatRow extends StatelessWidget {
  const _DiffStatRow({required this.label, required this.count, required this.color});

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label, style: context.theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

String _shortHash(String hash) {
  if (hash.isEmpty) return "(empty)";
  return hash.length <= 8 ? hash : hash.substring(0, 8);
}
