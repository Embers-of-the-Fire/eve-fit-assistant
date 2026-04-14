import "package:auto_route/annotations.dart";
import "package:eve_fit_assistant/features/documents/models.dart";
import "package:eve_fit_assistant/features/documents/repository.dart";
import "package:eve_fit_assistant/features/documents/storage.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";
import "package:markdown_widget/markdown_widget.dart";

@RoutePage()
class AnnouncementPage extends StatelessWidget {
  const AnnouncementPage({super.key});

  @override
  Widget build(BuildContext context) => const _DocumentHubPage(feedKind: DocumentFeedKind.mixed);
}

@RoutePage()
class VersionPage extends StatelessWidget {
  const VersionPage({super.key});

  @override
  Widget build(BuildContext context) => const _DocumentHubPage(feedKind: DocumentFeedKind.version);
}

class _DocumentHubPage extends ConsumerStatefulWidget {
  const _DocumentHubPage({required this.feedKind});

  final DocumentFeedKind feedKind;

  @override
  ConsumerState<_DocumentHubPage> createState() => _DocumentHubPageState();
}

class _DocumentHubPageState extends ConsumerState<_DocumentHubPage> {
  String? _selectedDocumentId;

  bool _useSplitLayout(BuildContext context) => supportsThreePaneLayout(context);

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(documentFeedProvider(widget.feedKind));
    final splitLayout = _useSplitLayout(context);

    return Scaffold(
      appBar: AppBar(
        leading: !splitLayout && _selectedDocumentId != null
            ? IconButton(
                onPressed: () => setState(() => _selectedDocumentId = null),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(_appBarTitle(context, entriesAsync.asData?.value, splitLayout)),
      ),
      body: entriesAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return _DocumentEmptyState(feedKind: widget.feedKind);
          }

          final selectedEntry = _resolveSelectedEntry(entries: entries, splitLayout: splitLayout);

          if (splitLayout) {
            return Row(
              children: [
                Flexible(
                  child: _DocumentListPane(
                    feedKind: widget.feedKind,
                    entries: entries,
                    selectedDocumentId: selectedEntry?.id,
                    onSelect: _selectDocument,
                  ),
                ),
                const VerticalDivider(width: 1),
                Flexible(flex: 2, child: _DocumentDetailPane(entry: selectedEntry)),
              ],
            );
          }

          if (selectedEntry == null) {
            return _DocumentListPane(
              feedKind: widget.feedKind,
              entries: entries,
              selectedDocumentId: null,
              onSelect: _selectDocument,
            );
          }

          return _DocumentDetailPane(entry: selectedEntry);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _DocumentLoadError(error: error),
      ),
    );
  }

  String _appBarTitle(BuildContext context, List<DocumentRecord>? entries, bool splitLayout) {
    if (splitLayout || _selectedDocumentId == null || entries == null) {
      return switch (widget.feedKind) {
        DocumentFeedKind.mixed => context.l10n.documentAnnouncementPageTitle,
        DocumentFeedKind.version => context.l10n.documentVersionPageTitle,
      };
    }
    final selectedEntry = entries.firstWhereOrNull((entry) => entry.id == _selectedDocumentId);
    return selectedEntry?.title ??
        switch (widget.feedKind) {
          DocumentFeedKind.mixed => context.l10n.documentAnnouncementPageTitle,
          DocumentFeedKind.version => context.l10n.documentVersionPageTitle,
        };
  }

  DocumentRecord? _resolveSelectedEntry({
    required List<DocumentRecord> entries,
    required bool splitLayout,
  }) {
    if (!splitLayout) {
      if (_selectedDocumentId == null) {
        return null;
      }
      return entries.firstWhereOrNull((entry) => entry.id == _selectedDocumentId);
    }

    final preferredId = _selectedDocumentId ?? DocumentStorage.selectedDocumentId(widget.feedKind);
    if (preferredId != null) {
      final matchedEntry = entries.firstWhereOrNull((entry) => entry.id == preferredId);
      if (matchedEntry != null) {
        return matchedEntry;
      }
    }
    return entries.first;
  }

  void _selectDocument(DocumentRecord entry) {
    DocumentStorage.saveSelectedDocumentId(widget.feedKind, entry.id);
    setState(() => _selectedDocumentId = entry.id);
  }
}

class _DocumentListPane extends StatelessWidget {
  const _DocumentListPane({
    required this.feedKind,
    required this.entries,
    required this.selectedDocumentId,
    required this.onSelect,
  });

  final DocumentFeedKind feedKind;
  final List<DocumentRecord> entries;
  final String? selectedDocumentId;
  final ValueChanged<DocumentRecord> onSelect;

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: entries.length,
    itemBuilder: (context, index) {
      final entry = entries[index];
      return _DocumentListCard(
        feedKind: feedKind,
        entry: entry,
        selected: entry.id == selectedDocumentId,
        onTap: () => onSelect(entry),
      );
    },
  );
}

class _DocumentListCard extends StatelessWidget {
  const _DocumentListCard({
    required this.feedKind,
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final DocumentFeedKind feedKind;
  final DocumentRecord entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    final dateText = DateFormat.yMMMMd(
      context.locale.toString(),
    ).format(entry.publishedAt.toLocal());
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: selected ? colorScheme.secondaryContainer : colorScheme.surfaceContainer,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DocumentBadge(
                    label: _kindLabel(context, entry.kind),
                    icon: _kindIcon(entry.kind),
                  ),
                  if (entry.appVersion != null)
                    _DocumentBadge(
                      label: context.l10n.documentVersionBadge(version: entry.appVersion!),
                      icon: Icons.sell_outlined,
                    ),
                  _DocumentBadge(label: dateText, icon: Icons.event_outlined),
                ],
              ),
              const SizedBox(height: 12),
              Text(entry.title, style: context.theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                entry.summary,
                style: context.theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (feedKind == DocumentFeedKind.mixed) ...[
                const SizedBox(height: 12),
                Text(
                  context.l10n.documentOpenHint,
                  style: context.theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _kindLabel(BuildContext context, DocumentEntryKind kind) => switch (kind) {
    DocumentEntryKind.announcement => context.l10n.documentKindAnnouncement,
    DocumentEntryKind.version => context.l10n.documentKindVersion,
  };

  IconData _kindIcon(DocumentEntryKind kind) => switch (kind) {
    DocumentEntryKind.announcement => Icons.campaign_outlined,
    DocumentEntryKind.version => Icons.new_releases_outlined,
  };
}

class _DocumentBadge extends StatelessWidget {
  const _DocumentBadge({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 6),
            Text(label, style: context.theme.textTheme.labelMedium),
          ],
        ),
      ),
    );
  }
}

class _DocumentDetailPane extends StatelessWidget {
  const _DocumentDetailPane({required this.entry});

  final DocumentRecord? entry;

  @override
  Widget build(BuildContext context) {
    if (entry == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.l10n.documentSelectPrompt,
            textAlign: TextAlign.center,
            style: context.theme.textTheme.titleMedium,
          ),
        ),
      );
    }

    final dateText = DateFormat.yMMMMd(
      context.locale.toString(),
    ).format(entry!.publishedAt.toLocal());

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry!.title, style: context.theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DocumentBadge(label: dateText, icon: Icons.event_available_outlined),
                  if (entry!.appVersion != null)
                    _DocumentBadge(
                      label: context.l10n.documentVersionBadge(version: entry!.appVersion!),
                      icon: Icons.sell_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: MarkdownWidget(data: entry!.markdown, padding: EdgeInsets.zero),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentEmptyState extends StatelessWidget {
  const _DocumentEmptyState({required this.feedKind});

  final DocumentFeedKind feedKind;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 56, color: context.theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            switch (feedKind) {
              DocumentFeedKind.mixed => context.l10n.documentAnnouncementEmptyTitle,
              DocumentFeedKind.version => context.l10n.documentVersionEmptyTitle,
            },
            style: context.theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.documentEmptyDescription,
            style: context.theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _DocumentLoadError extends StatelessWidget {
  const _DocumentLoadError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 56, color: context.theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            context.l10n.documentLoadErrorTitle,
            style: context.theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "$error",
            style: context.theme.textTheme.bodySmall?.copyWith(
              color: context.theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
