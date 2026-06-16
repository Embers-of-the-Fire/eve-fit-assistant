import "dart:async";
import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/service.dart";
import "package:eve_fit_assistant/storage/repo/schema_version.dart";
import "package:flutter/material.dart";
import "package:path/path.dart" as p;

class MigrationGate extends StatefulWidget {
  const MigrationGate({required this.onMigrationComplete, required this.theme, super.key});

  final VoidCallback onMigrationComplete;
  final ThemeData theme;

  @override
  State<MigrationGate> createState() => _MigrationGateState();
}

class _MigrationGateState extends State<MigrationGate> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _detectLegacyData();
  }

  void _detectLegacyData() {
    // Scan fittings/ for pre-v3 fit files that haven't been migrated.
    var hasLegacyFits = false;
    final fittingsDir = Directory(PathProvider.fittingsPath);
    if (fittingsDir.existsSync()) {
      try {
        for (final entity in fittingsDir.listSync()) {
          if (entity is! File || !entity.path.endsWith(".json")) continue;
          if (p.basename(entity.path) == "registry.json") continue;
          try {
            final content = jsonDecode(entity.readAsStringSync());
            if (content is! Map<String, dynamic>) continue;
            final version = content["version"] as int?;
            if (version == null || version < 3) {
              hasLegacyFits = true;
              break;
            }
            final fit = content["fit"];
            if (fit is Map<String, dynamic>) {
              final metadata = fit["metadata"];
              if (metadata is Map<String, dynamic> && metadata["checkoutRef"] == null) {
                hasLegacyFits = true;
                break;
              }
            }
          } on FormatException {
            hasLegacyFits = true;
            break;
          }
        }
      } on FileSystemException catch (e) {
        warning("Cannot scan fittings directory for legacy data: $e");
      }
    }

    // Scan characters/ for pre-v3 character files that haven't been migrated.
    var hasLegacyCharacters = false;
    final charactersDir = Directory(PathProvider.charactersPath);
    if (charactersDir.existsSync()) {
      try {
        for (final entity in charactersDir.listSync()) {
          if (entity is! File || !entity.path.endsWith(".json")) continue;
          if (p.basename(entity.path) == "registry.json") continue;
          try {
            final content = jsonDecode(entity.readAsStringSync());
            if (content is! Map<String, dynamic>) continue;
            if (content["checkoutRef"] == null && content.containsKey("bundleSnapshot")) {
              hasLegacyCharacters = true;
              break;
            }
          } on FormatException {
            hasLegacyCharacters = true;
            break;
          }
        }
      } on FileSystemException catch (e) {
        warning("Cannot scan characters directory for legacy data: $e");
      }
    }

    if (!hasLegacyFits && !hasLegacyCharacters) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _activateRepoAndReload());
      return;
    }

    setState(() {
      _checking = false;
    });
  }

  void _activateRepoAndReload() {
    const SchemaVersionService().ensure();
    widget.onMigrationComplete();
  }

  Future<void> _startMigration() async {
    final navigator = _navigatorKey.currentState!;
    unawaited(
      showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        builder: (_) => const _MigrationProgressDialog(),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));

    try {
      await MigrateService(schemaVersionService: const SchemaVersionService()).migrate();

      if (mounted) {
        navigator.popUntil((route) => route.isFirst);
        _activateRepoAndReload();
      }
    } catch (e, stackTrace) {
      warning("Migration failed: $e", stackTrace: stackTrace);
      if (mounted) {
        navigator.popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(
          navigator.context,
        ).showSnackBar(SnackBar(content: Text("Migration failed: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return MaterialApp(
        navigatorKey: _navigatorKey,
        theme: widget.theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => const Scaffold(body: Center(child: CircularProgressIndicator())),
        ),
      );
    }

    return MaterialApp(
      navigatorKey: _navigatorKey,
      theme: widget.theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync, size: 64),
                    const SizedBox(height: 16),
                    Text(
                      "Data Migration Required",
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "This version uses a new data storage format. "
                      "Your existing fits and characters will be migrated. "
                      "Legacy data will be cleaned up.",
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () {
                        unawaited(_startMigration());
                      },
                      child: const Text("Start Migration"),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        final navigator = _navigatorKey.currentState!;
                        unawaited(
                          showDialog<void>(
                            context: navigator.context,
                            builder: (dialogContext) => AlertDialog(
                              title: const Text("Skip Migration?"),
                              content: const Text(
                                "Fits and characters will keep the old format and may not "
                                "work correctly. New data will be downloaded separately.",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(),
                                  child: const Text("Cancel"),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    _activateRepoAndReload();
                                  },
                                  child: const Text("Skip"),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: const Text("Skip Migration"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MigrationProgressDialog extends StatefulWidget {
  const _MigrationProgressDialog();

  @override
  State<_MigrationProgressDialog> createState() => _MigrationProgressDialogState();
}

class _MigrationProgressDialogState extends State<_MigrationProgressDialog> {
  @override
  Widget build(BuildContext context) => const PopScope(
    canPop: false,
    child: AlertDialog(
      title: Text("Migrating..."),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(),
          SizedBox(height: 16),
          Text("Upgrading fits and characters..."),
        ],
      ),
    ),
  );
}
