// Init helpers for the package

import "dart:ui";

import "package:eve_fit_assistant/config/loading.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/native/frb_generated.dart";
import "package:eve_fit_assistant/storage/bundle/manager.dart";
import "package:eve_fit_assistant/storage/bundle/service/collection.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter/widgets.dart";
import "package:flutter_easyloading/flutter_easyloading.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fluttertoast/fluttertoast.dart";

Future<void> initSingletons() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await PathProvider.init();
  AppSettingService.init();
  GlobalLogger.init(
    PathProvider.logsPath,
    enableDebugLog: AppSettingService.appSetting.enableDebugLog,
  );
  GlobalLoading.init();
}

Widget initBuilder(BuildContext context, Widget? child) =>
    EasyLoading.init()(context, FToastBuilder()(context, child));

void initErrorBoundary() {
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    fatal(
      "Found Flutter error ${details.exceptionAsString()}",
      stackTrace: details.stack,
      error: details.exception,
    );
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    fatal("Uncaught platform error: $error", stackTrace: stack, error: error);
    return true;
  };
}

void initWithRef(WidgetRef ref) {
  ref
    ..read(fitManagerProvider)
    ..read(bundleManagerProvider)
    ..read(bundleCollectionProvider);
}
