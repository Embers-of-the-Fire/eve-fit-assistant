import "package:auto_route/annotations.dart";
import "package:eve_fit_assistant/features/announcements/models/models.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/features/announcements/state/state.dart";
import "package:eve_fit_assistant/pages/announcements/detail_page.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/fp.dart";
import "package:eve_fit_assistant/utils/screen.dart";
import "package:eve_fit_assistant/utils/version.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

@RoutePage()
class AnnouncementFeedPage extends StatelessWidget {
  const AnnouncementFeedPage({super.key});

  @override
  Widget build(BuildContext context) => const _AnnouncementHubPage();
}

class _AnnouncementHubPage extends ConsumerStatefulWidget {
  const _AnnouncementHubPage();

  @override
  ConsumerState<_AnnouncementHubPage> createState() => _AnnouncementHubPageState();
}

class _AnnouncementHubPageState extends ConsumerState<_AnnouncementHubPage> {
  String? _selectedRecordId;

  bool _useSplitLayout(BuildContext context) => supportsThreePaneLayout(context);

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(announcementFeedProvider);
    final splitLayout = _useSplitLayout(context);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        leading: !splitLayout && _selectedRecordId != null
            ? IconButton(
                onPressed: () => setState(() => _selectedRecordId = null),
                icon: const Icon(Icons.arrow_back),
              )
            : null,
        title: Text(_appBarTitle(context, entriesAsync.asData?.value, splitLayout)),
      ),
      body: entriesAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox_outlined, size: 56, color: context.theme.colorScheme.outline),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.announcementNoEntries,
                      style: context.theme.textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final selectedRecord = _resolveSelectedRecord(records: records, splitLayout: splitLayout);

          if (splitLayout) {
            return Row(
              children: [
                Flexible(
                  child: Column(
                    children: [
                      _buildActionBar(context, records),
                      Expanded(
                        child: _AnnouncementListPane(
                          records: records,
                          selectedRecordId: selectedRecord?.id,
                          onSelect: _selectRecord,
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1),
                Flexible(flex: 2, child: AnnouncementDetailContent(record: selectedRecord)),
              ],
            );
          }

          if (selectedRecord == null) {
            return Column(
              children: [
                _buildActionBar(context, records),
                Expanded(
                  child: _AnnouncementListPane(
                    records: records,
                    selectedRecordId: null,
                    onSelect: _selectRecord,
                  ),
                ),
              ],
            );
          }

          return AnnouncementDetailContent(record: selectedRecord);
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
                  context.l10n.announcementBodyLoadError,
                  style: context.theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _appBarTitle(BuildContext context, List<AnnouncementRecord>? records, bool splitLayout) {
    if (splitLayout || _selectedRecordId == null || records == null) {
      return context.l10n.announcementFeedTitle;
    }
    final selected = records.firstWhereOrNull((r) => r.id == _selectedRecordId);
    return selected?.title ?? context.l10n.announcementFeedTitle;
  }

  AnnouncementRecord? _resolveSelectedRecord({
    required List<AnnouncementRecord> records,
    required bool splitLayout,
  }) {
    if (splitLayout) {
      if (_selectedRecordId != null) {
        return records.firstWhereOrNull((r) => r.id == _selectedRecordId);
      }
      return records.isNotEmpty ? records.first : null;
    }
    if (_selectedRecordId == null) return null;
    return records.firstWhereOrNull((r) => r.id == _selectedRecordId);
  }

  void _selectRecord(AnnouncementRecord record) {
    ref.read(announcementStateServiceProvider.notifier).markRead(record.id);
    setState(() => _selectedRecordId = record.id);
  }

  Widget _buildActionBar(BuildContext context, List<AnnouncementRecord> records) {
    final allIds = records.map((r) => r.id);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(announcementStateServiceProvider.notifier).markAllRead(allIds),
            icon: const Icon(Icons.done_all, size: 16),
            label: Text(context.l10n.documentMarkAllRead),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: () => ref.read(announcementStateServiceProvider.notifier).markUnread(allIds),
            icon: const Icon(Icons.remove_done, size: 16),
            label: Text(context.l10n.documentMarkAllUnread),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementListPane extends StatelessWidget {
  const _AnnouncementListPane({
    required this.records,
    required this.selectedRecordId,
    required this.onSelect,
  });

  final List<AnnouncementRecord> records;
  final String? selectedRecordId;
  final ValueChanged<AnnouncementRecord> onSelect;

  @override
  Widget build(BuildContext context) => ListView.builder(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    itemCount: records.length,
    itemBuilder: (context, index) {
      final record = records[index];
      return _AnnouncementCard(
        record: record,
        selected: record.id == selectedRecordId,
        onTap: () => onSelect(record),
      );
    },
  );
}

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard({required this.record, required this.selected, required this.onTap});

  final AnnouncementRecord record;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = context.theme.colorScheme;
    final dateText = DateFormat.yMMMMd(
      context.locale.toString(),
    ).format(record.publishedAt.toLocal());

    final appVer = ref
        .watch(appVersionProvider)
        .when(data: (v) => v, loading: () => null, error: (_, _) => null);
    final showMinVerWarning =
        record.minAppVersion != null &&
        appVer != null &&
        isAppVersionBelow(appVer, record.minAppVersion!);

    final trailingWidget = showMinVerWarning || !record.isRead
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showMinVerWarning)
                Tooltip(
                  message: context.l10n.documentMinAppVerWarning(version: record.minAppVersion!),
                  child: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                ),
              if (showMinVerWarning && !record.isRead) const SizedBox(width: 4),
              if (!record.isRead)
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                ),
            ],
          )
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: selected ? colorScheme.secondaryContainer : colorScheme.surfaceContainer,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _AnnouncementBadge(
                        label: record.source == AnnouncementEntrySource.bundled
                            ? context.l10n.announcementSourceBundled
                            : context.l10n.announcementSourceRemote,
                        icon: record.source == AnnouncementEntrySource.bundled
                            ? Icons.phone_android_outlined
                            : Icons.cloud_outlined,
                      ),
                      if (record.appVersion != null)
                        _AnnouncementBadge(
                          label: context.l10n.documentVersionBadge(version: record.appVersion!),
                          icon: Icons.sell_outlined,
                        ),
                      _AnnouncementBadge(label: dateText, icon: Icons.event_outlined),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(record.title, style: context.theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    record.summary,
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (trailingWidget != null) Positioned(top: 10, right: 10, child: trailingWidget),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementBadge extends StatelessWidget {
  const _AnnouncementBadge({required this.label, required this.icon});

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
