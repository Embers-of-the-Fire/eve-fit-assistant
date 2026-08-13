import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:eve_fit_assistant/utils/type_sort.dart";
import "package:flutter/material.dart";

class MetaFilterBar extends StatelessWidget {
  const MetaFilterBar({required this.filter, required this.onChanged, super.key});

  final MetaFilter filter;
  final void Function(MetaFilter) onChanged;

  String _bucketLabel(BuildContext context, MetaFilterBucket bucket) => switch (bucket) {
    MetaFilterBucket.techTree => context.l10n.itemMetaFilterTechTree,
    MetaFilterBucket.faction => context.l10n.itemMetaFilterFaction,
    MetaFilterBucket.deadspace => context.l10n.itemMetaFilterDeadspace,
    MetaFilterBucket.officer => context.l10n.itemMetaFilterOfficer,
  };

  String _summary(BuildContext context) {
    if (filter.isAll) return context.l10n.itemMetaFilterAll;
    return filter.buckets.map((b) => _bucketLabel(context, b)).join(", ");
  }

  Widget _buildChips(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    padding: const .symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Padding(
          padding: const .only(right: 8),
          child: FilterChip(
            label: Text(context.l10n.itemMetaFilterAll),
            selected: filter.isAll,
            onSelected: (_) => onChanged(filter.toggleAll()),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        for (final bucket in MetaFilterBucket.values)
          Padding(
            padding: const .only(right: 8),
            child: FilterChip(
              label: Text(_bucketLabel(context, bucket)),
              selected: filter.buckets.contains(bucket),
              onSelected: (_) => onChanged(filter.toggleBucket(bucket)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
      ],
    ),
  );

  Widget _buildDropdownEntry(
    BuildContext context, {
    required String label,
    required bool checked,
  }) => Row(
    children: [
      Icon(checked ? Icons.check_box : Icons.check_box_outline_blank, size: 20),
      const SizedBox(width: 8),
      Text(label),
    ],
  );

  Widget _buildDropdown(BuildContext context) => Container(
    width: double.infinity,
    padding: const .symmetric(horizontal: 16, vertical: 4),
    alignment: Alignment.centerLeft,
    child: PopupMenuButton<void>(
      itemBuilder: (context) => [
        PopupMenuItem<void>(
          onTap: () => onChanged(filter.toggleAll()),
          child: _buildDropdownEntry(
            context,
            label: context.l10n.itemMetaFilterAll,
            checked: filter.isAll,
          ),
        ),
        for (final bucket in MetaFilterBucket.values)
          PopupMenuItem<void>(
            onTap: () => onChanged(filter.toggleBucket(bucket)),
            child: _buildDropdownEntry(
              context,
              label: _bucketLabel(context, bucket),
              checked: filter.buckets.contains(bucket),
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.filter_list, size: 18),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              _summary(context),
              style: context.theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.arrow_drop_down, size: 18),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => screenColumnTarget(context) == ScreenColumnTarget.one
      ? _buildDropdown(context)
      : _buildChips(context);
}
