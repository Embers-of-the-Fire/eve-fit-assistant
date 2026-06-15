import "dart:async";

import "package:eve_fit_assistant/storage/repo/models/diff.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/datetime.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";

class ReflogTimeline extends StatelessWidget {
  const ReflogTimeline({required this.reflog, required this.diffs, super.key});

  final IList<ReflogEntry> reflog;
  final IMap<String, Diff> diffs;

  @override
  Widget build(BuildContext context) {
    if (reflog.isEmpty) {
      return const SizedBox.shrink();
    }
    final entries = reflog.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < entries.length; i++)
          _ReflogTimelineRow(
            entry: entries[i],
            diff: diffs[entries[i].id],
            isFirst: i == 0,
            isLast: i == entries.length - 1,
          ),
      ],
    );
  }
}

class _ReflogTimelineRow extends StatelessWidget {
  const _ReflogTimelineRow({
    required this.entry,
    required this.diff,
    required this.isFirst,
    required this.isLast,
  });

  final ReflogEntry entry;
  final Diff? diff;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final dateStr = _formatIsoTimestamp(context, entry.timestamp);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                if (!isFirst) Expanded(child: _Connector(color: theme.colorScheme.outline)),
                CircleAvatar(
                  radius: 6,
                  backgroundColor: isFirst ? theme.colorScheme.primary : theme.colorScheme.outline,
                ),
                if (!isLast) Expanded(child: _Connector(color: theme.colorScheme.outline)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(dateStr, style: theme.textTheme.labelSmall),
                  const SizedBox(height: 4),
                  _HashRow(from: entry.from, to: entry.to, direction: _entryDirection(entry)),
                  if (diff != null) ...[const SizedBox(height: 8), _DiffStats(diff: diff!)],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _entryDirection(ReflogEntry entry) {
    if (entry.from.isEmpty || entry.to.isEmpty) return "\u2192";
    return "\u2192";
  }
}

class _Connector extends StatelessWidget {
  const _Connector({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: color.withValues(alpha: 0.35), child: const SizedBox(width: 2));
}

class _HashRow extends StatelessWidget {
  const _HashRow({required this.from, required this.to, required this.direction});

  final String from;
  final String to;
  final String direction;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    return Row(
      children: [
        _HashChip(label: _shortHash(from), copyValue: from),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(direction, style: theme.textTheme.bodySmall),
        ),
        _HashChip(label: _shortHash(to), copyValue: to),
      ],
    );
  }
}

class _HashChip extends StatelessWidget {
  const _HashChip({required this.label, this.copyValue});

  final String label;
  final String? copyValue;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      unawaited(Clipboard.setData(ClipboardData(text: copyValue ?? label)));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Copied"), duration: Duration(seconds: 1)));
    },
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: context.theme.textTheme.labelSmall?.copyWith(fontFamily: "monospace"),
        ),
      ),
    ),
  );
}

class _DiffStats extends StatelessWidget {
  const _DiffStats({required this.diff});

  final Diff diff;

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final parts = <Widget>[];
    if (diff.adds.isNotEmpty) {
      parts.add(
        Text(
          context.l10n.branchDiffAdds(count: diff.adds.length),
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    if (diff.deletes.isNotEmpty) {
      if (parts.isNotEmpty) parts.add(const SizedBox(width: 12));
      parts.add(
        Text(
          context.l10n.branchDiffDeletes(count: diff.deletes.length),
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    if (diff.modifies.isNotEmpty) {
      if (parts.isNotEmpty) parts.add(const SizedBox(width: 12));
      parts.add(
        Text(
          context.l10n.branchDiffModifies(count: diff.modifies.length),
          style: theme.textTheme.bodySmall,
        ),
      );
    }
    if (parts.isEmpty) {
      return const SizedBox.shrink();
    }
    return Row(children: parts);
  }
}

String _shortHash(String hash) {
  if (hash.isEmpty) return "(empty)";
  return hash.length <= 8 ? hash : hash.substring(0, 8);
}

String _formatIsoTimestamp(BuildContext context, String iso) {
  try {
    final dt = DateTime.parse(iso);
    return yMMMMdHmsLocalized(context).format(dt.toLocal());
  } on FormatException {
    return iso;
  }
}
