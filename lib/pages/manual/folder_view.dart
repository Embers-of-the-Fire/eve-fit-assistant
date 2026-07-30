import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/features/manual/manual.dart";
import "package:eve_fit_assistant/pages/manual/breadcrumb.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:flutter/material.dart";

/// Renders a manual folder: breadcrumb bar, optional localized description,
/// and its direct children (subfolders first, then docs).
class ManualFolderView extends StatelessWidget {
  const ManualFolderView({required this.folder, required this.ancestors, super.key});

  /// The folder to display.
  final ManualFolderEntry folder;

  /// Folder chain above [folder], from the top level down.
  final List<ManualFolderEntry> ancestors;

  @override
  Widget build(BuildContext context) {
    final localeCode = context.locale.toString();
    final isRoot = folder.id.isEmpty;
    final folders = _sortedFolders(folder);
    final docs = _sortedDocs(folder);

    return Column(
      children: [
        ManualBreadcrumb(
          ancestors: ancestors,
          currentLabel: isRoot ? null : (folder.resolveName(localeCode) ?? folder.id),
        ),
        Expanded(
          child: folders.isEmpty && docs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.menu_book_outlined,
                          size: 56,
                          color: context.theme.colorScheme.outline,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          context.l10n.manualEmpty,
                          style: context.theme.textTheme.titleMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  children: [
                    if (folder.resolveDescription(localeCode) case final description?)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 14),
                        child: Text(
                          description,
                          style: context.theme.textTheme.bodyMedium?.copyWith(
                            color: context.theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    GridView.count(
                      crossAxisCount: columnCount(context),
                      mainAxisExtent: 112,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final subfolder in folders)
                          _ManualFolderCard(folder: subfolder, localeCode: localeCode),
                        for (final doc in docs) _ManualDocCard(doc: doc, localeCode: localeCode),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

List<ManualFolderEntry> _sortedFolders(ManualFolderEntry folder) =>
    List<ManualFolderEntry>.of(folder.folders)..sort((a, b) => a.order.compareTo(b.order));

List<ManualDocEntry> _sortedDocs(ManualFolderEntry folder) =>
    List<ManualDocEntry>.of(folder.docs)..sort((a, b) => a.order.compareTo(b.order));

class _ManualFolderCard extends StatelessWidget {
  const _ManualFolderCard({required this.folder, required this.localeCode});

  final ManualFolderEntry folder;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final name = folder.resolveName(localeCode) ?? folder.id;
    final description = folder.resolveDescription(localeCode);

    return Card(
      margin: EdgeInsets.zero,
      color: context.theme.colorScheme.surfaceContainer,
      child: InkWell(
        onTap: () => unawaited(context.router.pushPath("/manual/${folder.id}")),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.folder_outlined, color: context.theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.titleMedium,
                    ),
                    if (description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.bodyMedium?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: context.theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualDocCard extends StatelessWidget {
  const _ManualDocCard({required this.doc, required this.localeCode});

  final ManualDocEntry doc;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final localization = doc.resolveLocalization(localeCode)?.data;
    final title = localization?.title ?? doc.id;
    final summary = localization?.summary ?? "";

    return Card(
      margin: EdgeInsets.zero,
      color: context.theme.colorScheme.surfaceContainer,
      child: InkWell(
        onTap: () => unawaited(context.router.pushPath("/manual/${doc.id}")),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.theme.textTheme.titleMedium,
                    ),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        summary,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.theme.textTheme.bodyMedium?.copyWith(
                          color: context.theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: context.theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
