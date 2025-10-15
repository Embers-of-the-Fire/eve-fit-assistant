import 'package:eve_fit_assistant/constant/colors.dart';
import 'package:eve_fit_assistant/data/l10n/app_localizations.dart';
import 'package:eve_fit_assistant/init.dart';
import 'package:eve_fit_assistant/pages/router.dart';
import 'package:eve_fit_assistant/storage/setting/setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  await initSingletons();
  initErrorBoundary();
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  static final _appRouter = AppRouter();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      appBarTheme: AppBarThemeData(elevation: 2),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 2,
        backgroundColor: colorScheme.surfaceContainerLow,
      ),
      dialogTheme: DialogThemeData(backgroundColor: colorScheme.surface),
      tabBarTheme: TabBarThemeData(indicatorColor: colorScheme.primary),
    );
    return MaterialApp.router(
      title: 'Flutter Demo',
      theme: theme,
      locale: Locale(ref.watch(localeProvider).name),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: _appRouter.config(),
      builder: initBuilder,
    );
  }
}
