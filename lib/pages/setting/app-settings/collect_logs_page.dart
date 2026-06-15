import "dart:async";
import "dart:io";

import "package:archive/archive.dart";
import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:path/path.dart" as p;
import "package:share_plus/share_plus.dart";

enum TimeFilter { oneHour, twentyFourHours, sevenDays, thirtyDays, all }

@RoutePage()
class CollectLogsPage extends ConsumerStatefulWidget {
  const CollectLogsPage({super.key});

  @override
  ConsumerState<CollectLogsPage> createState() => _CollectLogsPageState();
}

class _CollectLogsPageState extends ConsumerState<CollectLogsPage> {
  List<FileSystemEntity> _allFiles = [];
  final Set<String> _selectedPaths = {};
  TimeFilter _activeFilter = TimeFilter.all;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadFiles());
  }

  Future<void> _loadFiles() async {
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final dir = Directory(PathProvider.logsPath);
      if (!dir.existsSync()) {
        if (!mounted) return;
        setState(() {
          _allFiles = [];
          _loading = false;
        });
        return;
      }
      final entities = await dir.list().toList();
      if (!mounted) return;
      entities.sort((a, b) {
        final aStat = a.statSync();
        final bStat = b.statSync();
        return bStat.modified.compareTo(aStat.modified);
      });
      setState(() => _allFiles = entities);
      _applyFilter(_activeFilter);
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  void _applyFilter(TimeFilter filter) {
    final now = DateTime.now();
    final cutoff = switch (filter) {
      TimeFilter.oneHour => now.subtract(const Duration(hours: 1)),
      TimeFilter.twentyFourHours => now.subtract(const Duration(hours: 24)),
      TimeFilter.sevenDays => now.subtract(const Duration(days: 7)),
      TimeFilter.thirtyDays => now.subtract(const Duration(days: 30)),
      TimeFilter.all => null,
    };

    _selectedPaths.clear();
    for (final entity in _allFiles) {
      if (entity is! File) continue;
      final basename = p.basename(entity.path);
      if (!basename.endsWith(".log")) continue;
      if (cutoff == null || entity.lastModifiedSync().isAfter(cutoff)) {
        _selectedPaths.add(entity.path);
      }
    }
    setState(() {
      _activeFilter = filter;
      _loading = false;
    });
  }

  void _toggleFile(String path) {
    setState(() {
      _activeFilter = TimeFilter.all;
      if (_selectedPaths.contains(path)) {
        _selectedPaths.remove(path);
      } else {
        _selectedPaths.add(path);
      }
    });
  }

  int get _selectedCount => _selectedPaths.length;

  int get _totalSize {
    int size = 0;
    for (final path in _selectedPaths) {
      try {
        size += File(path).lengthSync();
      } on Object {
        // file rotated or deleted since listing
      }
    }
    return size;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  String _formatDateTime(DateTime dt) {
    String pad(int n) => n.toString().padLeft(2, "0");
    return "${dt.year}-${pad(dt.month)}-${pad(dt.day)} ${pad(dt.hour)}:${pad(dt.minute)}";
  }

  Future<void> _shareLogs() async {
    if (_selectedPaths.isEmpty) return;

    final archive = Archive();
    for (final path in _selectedPaths) {
      final basename = p.basename(path);
      try {
        final bytes = await File(path).readAsBytes();
        archive.addFile(ArchiveFile(basename, bytes.length, bytes));
      } on Object {
        // file rotated or deleted since selection
      }
    }

    if (archive.isEmpty) return;

    final zipData = ZipEncoder().encode(archive);
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipPath = p.join(PathProvider.tempPath, "efa_logs_$timestamp.zip");
    await File(zipPath).writeAsBytes(zipData);

    if (!mounted) return;
    await SharePlus.instance.share(ShareParams(files: [XFile(zipPath)], subject: "EFA Logs"));
  }

  Iterable<File> get _logFiles =>
      _allFiles.whereType<File>().where((f) => p.basename(f.path).endsWith(".log"));

  @override
  Widget build(BuildContext context) => Layout(
    title: context.l10n.collectLogsPageTitle,
    child: Column(
      children: [
        _buildFilters(context),
        const Divider(height: 1),
        Expanded(child: _buildFileList(context)),
        _buildBottomBar(context),
      ],
    ),
  );

  Widget _buildFilters(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.collectLogsQuickFilter, style: context.theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: TimeFilter.values
                .map(
                  (filter) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(switch (filter) {
                        TimeFilter.oneHour => context.l10n.collectLogsFilter1Hour,
                        TimeFilter.twentyFourHours => context.l10n.collectLogsFilter24Hours,
                        TimeFilter.sevenDays => context.l10n.collectLogsFilter7Days,
                        TimeFilter.thirtyDays => context.l10n.collectLogsFilter30Days,
                        TimeFilter.all => context.l10n.collectLogsFilterAll,
                      }),
                      selected: _activeFilter == filter,
                      onSelected: (_) => _applyFilter(filter),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );

  Widget _buildFileList(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(context.l10n.collectLogsLoadError),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _loadFiles, child: const Text("Retry")),
            ],
          ),
        ),
      );
    }
    if (_logFiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(context.l10n.collectLogsNoLogFiles),
        ),
      );
    }
    return ListView(children: _logFiles.map((file) => _logFileTile(context, file)).toList());
  }

  Widget _logFileTile(BuildContext context, File file) {
    final basename = p.basename(file.path);
    final isActive = basename == "latest.log";

    String sizeLabel;
    String modifiedLabel;
    try {
      sizeLabel = _formatSize(file.lengthSync());
    } on Object {
      sizeLabel = "—";
    }
    try {
      modifiedLabel = _formatDateTime(file.lastModifiedSync());
    } on Object {
      modifiedLabel = "—";
    }

    return CheckboxListTile(
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: basename),
            if (isActive)
              TextSpan(
                text: " ${context.l10n.collectLogsFileActive}",
                style: TextStyle(color: context.theme.colorScheme.primary, fontSize: 12),
              ),
          ],
        ),
      ),
      subtitle: Text("$modifiedLabel — $sizeLabel"),
      value: _selectedPaths.contains(file.path),
      onChanged: (_) => _toggleFile(file.path),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = context.theme;
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: 12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.collectLogsTotalSize(
                size: _formatSize(_totalSize),
                count: _selectedCount,
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _selectedCount > 0 ? _shareLogs : null,
            icon: const Icon(Icons.share),
            label: Text(context.l10n.collectLogsShareButton),
          ),
        ],
      ),
    );
  }
}
