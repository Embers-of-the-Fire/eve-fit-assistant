import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/features/manual/manual.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class ManualBrowserPage extends ConsumerWidget {
  const ManualBrowserPage({super.key, this.folderId});

  /// Path-joined id of the folder to display, e.g. `fitting/advanced`.
  /// `null` shows the root of the manual tree.
  final String? folderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final treeAsync = ref.watch(manualTreeProvider);
    final localeCode = context.locale.toString();

    final folder = switch ((treeAsync, folderId)) {
      (AsyncData(value: final root), null) => root,
      (AsyncData(value: final root), final id?) => root.findFolder(id),
      _ => null,
    };
    final title = folderId == null
        ? context.l10n.manualPageTitle
        : (folder?.resolveName(localeCode) ?? context.l10n.manualPageTitle);

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: Text(title)),
      body: treeAsync.when(
        data: (_) {
          if (folder == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  context.l10n.manualFolderNotFound,
                  style: context.theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final folders = _sortedFolders(folder);
          final docs = _sortedDocs(folder);

          if (folders.isEmpty && docs.isEmpty) {
            return Center(
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
            );
          }

          return ListView(
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
              for (final subfolder in folders)
                _ManualFolderCard(folder: subfolder, localeCode: localeCode),
              for (final doc in docs) _ManualDocCard(doc: doc, localeCode: localeCode),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 56, color: context.theme.colorScheme.error),
                const SizedBox(height: 12),
                Text(
                  context.l10n.manualContentLoadError,
                  style: context.theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(manualTreeProvider),
                  child: Text(context.l10n.manualContentLoadRetry),
                ),
              ],
            ),
          ),
        ),
      ),
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
      margin: const EdgeInsets.only(bottom: 12),
      color: context.theme.colorScheme.surfaceContainer,
      child: InkWell(
        onTap: () => context.router.push(ManualBrowserRoute(folderId: folder.id)),
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
                    Text(name, style: context.theme.textTheme.titleMedium),
                    if (description != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        description,
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
      margin: const EdgeInsets.only(bottom: 12),
      color: context.theme.colorScheme.surfaceContainer,
      child: InkWell(
        onTap: () => context.router.push(ManualDocRoute(docId: doc.id)),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.theme.textTheme.titleMedium),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        summary,
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
