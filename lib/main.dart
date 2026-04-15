import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/init.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/persistence/startup_repair.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

void main() async {
  await initSingletons();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  static final _appRouter = AppRouter();
  static final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    initWithRef(ref);

    final colorScheme = ColorScheme.fromSeed(brightness: Brightness.dark, seedColor: deepSpace);

    final theme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
      primaryColor: colorScheme.primary,
      canvasColor: colorScheme.surface,
      scaffoldBackgroundColor: colorScheme.surface,
      cardColor: colorScheme.surface,
      dividerColor: colorScheme.onSurface.withAlpha(30),
      applyElevationOverlayColor: true,
      appBarTheme: const AppBarThemeData(elevation: 2),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 2,
        backgroundColor: colorScheme.surfaceContainerLow,
      ),
      dialogTheme: DialogThemeData(backgroundColor: colorScheme.surface),
      tabBarTheme: TabBarThemeData(indicatorColor: colorScheme.primary),
    );
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: theme,
      scaffoldMessengerKey: _scaffoldMessengerKey,
      locale: Locale(ref.watch(localeProvider).name),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _appRouter.config(),
      builder: (context, child) {
        final report = StartupPersistenceRepairReporter.instance.peek();
        if (report != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final messenger = _scaffoldMessengerKey.currentState;
            if (messenger == null) {
              return;
            }
            final consumedReport = StartupPersistenceRepairReporter.instance.consume();
            if (consumedReport == null) {
              return;
            }
            messenger.showSnackBar(
              SnackBar(
                content: Text(_formatStartupPersistenceReport(context.l10n, consumedReport)),
                duration: Duration(seconds: consumedReport.hasWarnings ? 6 : 4),
              ),
            );
          });
        }
        return initBuilder(context, child);
      },
    );
  }
}

String _formatStartupPersistenceReport(
  AppLocalizations l10n,
  StartupPersistenceRepairReport report,
) {
  final details = <String>[
    if (report.rewroteFitRegistry || report.rewroteBundleRegistry)
      l10n.startupPersistenceRepairRebuiltMetadata,
    if (report.removedMissingFitEntries > 0)
      l10n.startupPersistenceRepairRemovedMissingFits(count: report.removedMissingFitEntries),
    if (report.restoredFitEntries > 0)
      l10n.startupPersistenceRepairRestoredFits(count: report.restoredFitEntries),
    if (report.removedMissingBundleEntries > 0)
      l10n.startupPersistenceRepairRemovedMissingBundles(count: report.removedMissingBundleEntries),
    if (report.restoredBundleEntries > 0)
      l10n.startupPersistenceRepairRestoredBundles(count: report.restoredBundleEntries),
    if (report.selectedBundleChanged) l10n.startupPersistenceRepairUpdatedSelectedBundle,
  ];

  final detailsText = details.isEmpty && report.hasWarnings
      ? l10n.startupPersistenceRepairFoundUnreadableFits
      : details.isEmpty
      ? l10n.startupPersistenceRepairRebuiltMetadata
      : details.join(", ");
  final summary = l10n.startupPersistenceRepairSummary(details: detailsText);
  if (!report.hasWarnings) {
    return summary;
  }
  return l10n.startupPersistenceRepairSummaryWithWarnings(
    details: detailsText,
    unreadableCount: report.unrestoredFitFiles,
  );
}
