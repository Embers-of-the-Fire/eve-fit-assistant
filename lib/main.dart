import "dart:async";

import "package:eve_fit_assistant/constant/colors.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/features/announcements/announcements.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_notifier.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/features/deeplink/providers.dart";
import "package:eve_fit_assistant/features/feedback/feedback.dart";
import "package:eve_fit_assistant/features/schema_guard/schema_guard.dart";
import "package:eve_fit_assistant/features/welcome/welcome_gate.dart";
import "package:eve_fit_assistant/init.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/persistence/startup_repair.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:eve_fit_assistant/utils/fd_limit.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

void main() async {
  raiseFdSoftLimitToHard();
  final stores = await initSingletons();
  runApp(
    ProviderScope(
      overrides: [
        announcementStateStoreProvider.overrideWithValue(stores.announcementStateStore),
        appVersionStateStoreProvider.overrideWithValue(stores.appVersionStateStore),
        routeCollectionProvider.overrideWithValue(MyApp.appRouter.routeCollection),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  static final appRouter = AppRouter();
  static final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  // ignore: unreachable_from_main
  static GlobalKey<NavigatorState> get navigatorKey => appRouter.navigatorKey;

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
    final fontScale = ref.watch(fontScaleProvider);

    return WelcomeGate(
      child: SchemaGuard(
        theme: theme,
        builder: (active) => MaterialApp.router(
          onGenerateTitle: (context) => context.l10n.appTitle,
          theme: theme,
          scaffoldMessengerKey: _scaffoldMessengerKey,
          locale: Locale(ref.watch(localeProvider).name),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: appRouter.config(),
          builder: (context, child) {
            final report = StartupPersistenceRepairReporter.instance.peek();
            if (report != null) {
              final l10n = context.l10n;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final messenger = _scaffoldMessengerKey.currentState;
                if (messenger == null) {
                  return;
                }
                final consumedReport = StartupPersistenceRepairReporter.instance.consume();
                if (consumedReport == null) {
                  return;
                }
                unawaited(
                  Future.microtask(() {
                    if (!messenger.mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(_formatStartupPersistenceReport(l10n, consumedReport)),
                        duration: Duration(seconds: consumedReport.hasWarnings ? 6 : 4),
                      ),
                    );
                  }),
                );
              });
            }
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(fontScale)),
              child: FeedbackGate(
                appRouter: appRouter,
                child: StartupAnnouncementGate(
                  appRouter: appRouter,
                  child: initBuilder(context, child),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

String _formatStartupPersistenceReport(
  AppLocalizations l10n,
  StartupPersistenceRepairReport report,
) {
  final details = <String>[
    if (report.rewroteFitRegistry) l10n.startupPersistenceRepairRebuiltMetadata,
    if (report.removedMissingFitEntries > 0)
      l10n.startupPersistenceRepairRemovedMissingFits(count: report.removedMissingFitEntries),
    if (report.restoredFitEntries > 0)
      l10n.startupPersistenceRepairRestoredFits(count: report.restoredFitEntries),
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
