import 'package:eve_fit_assistant/front.dart' as front;
import 'package:eve_fit_assistant/native/port/frb_generated.dart';
import 'package:eve_fit_assistant/storage/storage.dart';
import 'package:eve_fit_assistant/theme/color.dart';
import 'package:eve_fit_assistant/widgets/loading.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

Future main() async {
  await RustLib.init();
  GlobalLoading().init();
  runApp(const ProviderScope(child: MyApp()));
}

final globalNavigatorKey = GlobalKey<NavigatorState>();

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future.delayed(const Duration(milliseconds: 10)).then((_) => GlobalStorage().init(ref));

    return MaterialApp(
      title: 'EVE Fit Assistant',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(brightness: Brightness.dark, seedColor: primaryBlue),
        primaryColor: primaryBlue,
        scaffoldBackgroundColor: deepSpace,
        cardColor: neonGreen,
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            color: neonHighlight,
            fontSize: 20,
          ),
          elevation: 0,
          iconTheme: IconThemeData(color: neonHighlight),
        ),
        textTheme: TextTheme(
          titleLarge: const TextStyle(
            color: terminalText,
            fontSize: 24,
          ),
          bodyMedium: TextStyle(
            color: terminalText.withAlpha(204),
            fontSize: 14,
          ),
          labelSmall: const TextStyle(
            color: neonHighlight,
            letterSpacing: 1.5,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue.withAlpha(51),
          foregroundColor: neonHighlight,
          side: const BorderSide(color: primaryBlue, width: 1.5),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        )),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: neonHighlight,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          ),
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: deepSpace,
          titleTextStyle: TextStyle(
            color: neonHighlight,
            fontSize: 20,
          ),
          contentTextStyle: TextStyle(
            color: terminalText,
            fontSize: 16,
          ),
        ),
        canvasColor: deepSpace,
        dividerTheme: const DividerThemeData(
          color: cyberTeal,
          indent: 10,
          endIndent: 10,
        ),
        dividerColor: cyberTeal,
        iconTheme: const IconThemeData(color: neonHighlight),
      ),
      home: const front.FrontendPage(),
      builder: (context, child) {
        child = EasyLoading.init()(context, child);
        child = FToastBuilder()(context, child);
        return child;
      },
      navigatorKey: globalNavigatorKey,
    );
  }
}
