import "dart:async";
import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/storage/repo/migration/action/service.dart";
import "package:eve_fit_assistant/storage/repo/schema_version.dart";
import "package:eve_fit_assistant/utils/context.dart";
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
    // Scan old fittings/ for legacy fit files.
    var hasLegacyFits = false;
    final oldFittingsDir = Directory(PathProvider.oldFittingsPath);
    if (oldFittingsDir.existsSync()) {
      try {
        for (final entity in oldFittingsDir.listSync()) {
          if (entity is! File || !entity.path.endsWith(".json")) continue;
          if (p.basename(entity.path) == "registry.json") continue;
          try {
            final content = jsonDecode(entity.readAsStringSync());
            if (content is! Map<String, dynamic>) continue;
            final fit = content["fit"];
            if (fit is Map<String, dynamic>) {
              final metadata = fit["metadata"];
              if (metadata is Map<String, dynamic> &&
                  metadata["checkoutRef"] == null &&
                  metadata.containsKey("bundleSnapshot")) {
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
        warning("Cannot scan old fittings directory for legacy data: $e");
      }
    }

    // Scan old characters/ for legacy character files.
    var hasLegacyCharacters = false;
    final oldCharactersDir = Directory(PathProvider.oldCharactersPath);
    if (oldCharactersDir.existsSync()) {
      try {
        for (final entity in oldCharactersDir.listSync()) {
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
        warning("Cannot scan old characters directory for legacy data: $e");
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
        ScaffoldMessenger.of(navigator.context).showSnackBar(
          SnackBar(
            content: Text(navigator.context.l10n.migrationFailedError(message: e.toString())),
          ),
        );
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
                      context.l10n.migrationRequiredTitle,
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.l10n.migrationRequiredDescription,
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    FilledButton(
                      onPressed: () {
                        unawaited(_startMigration());
                      },
                      child: Text(context.l10n.migrationStartButton),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        final navigator = _navigatorKey.currentState!;
                        unawaited(
                          showDialog<void>(
                            context: navigator.context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(context.l10n.migrationSkipConfirmTitle),
                              content: Text(context.l10n.migrationSkipConfirmDescription),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(dialogContext).pop(),
                                  child: Text(context.l10n.cancel),
                                ),
                                FilledButton(
                                  onPressed: () {
                                    Navigator.of(dialogContext).pop();
                                    _activateRepoAndReload();
                                  },
                                  child: Text(context.l10n.migrationSkipButton),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Text(context.l10n.migrationSkipMigrationButton),
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
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: Text(context.l10n.migrationInProgressTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(),
          const SizedBox(height: 16),
          Text(context.l10n.migrationInProgressDescription),
        ],
      ),
    ),
  );
}
