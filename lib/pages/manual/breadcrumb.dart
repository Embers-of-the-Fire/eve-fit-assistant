import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/features/manual/manual.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_breadcrumb/flutter_breadcrumb.dart";

/// Breadcrumb bar for manual pages, mirroring the select-list breadcrumb
/// style. The root item links back to the manual home (`/manual`), ancestor
/// folders link to their own pages, and the current node is the terminal
/// item.
class ManualBreadcrumb extends StatelessWidget {
  const ManualBreadcrumb({required this.ancestors, this.currentLabel, super.key});

  /// Folder chain above the current node, from the top level down.
  final List<ManualFolderEntry> ancestors;

  /// Label of the current (terminal) node. `null` when the current node is
  /// the manual root itself.
  final String? currentLabel;

  @override
  Widget build(BuildContext context) {
    final localeCode = context.locale.toString();
    final current = currentLabel;

    final items = <BreadCrumbItem>[
      if (current == null)
        BreadCrumbItem(content: Text(context.l10n.manualPageTitle))
      else ...[
        BreadCrumbItem(
          content: Text(context.l10n.manualPageTitle),
          onTap: () => unawaited(context.router.pushPath("/manual")),
        ),
        for (final ancestor in ancestors)
          BreadCrumbItem(
            content: Text(ancestor.resolveName(localeCode) ?? ancestor.id),
            onTap: () => unawaited(context.router.pushPath("/manual/${ancestor.id}")),
          ),
        BreadCrumbItem(content: Text(current)),
      ],
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.theme.dividerColor)),
      ),
      child: BreadCrumb(
        items: items,
        divider: const Icon(Icons.chevron_right, size: 18),
        overflow: ScrollableOverflow(keepLastDivider: true),
      ),
    );
  }
}
