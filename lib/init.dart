// Init helpers for the package

import "dart:async";
import "dart:ui";

import "package:eve_fit_assistant/config/loading.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/announcements/remote/body_cache.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:eve_fit_assistant/features/feedback/feedback_state_store.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/native/frb_generated.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/persistence/startup_repair.dart";
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
  AnnouncementStateStore.init();
  FeedbackStateStore.init();
  await AnnouncementBodyCache.init();
  EtagCache.init();
  GlobalLogger.init(
    PathProvider.logsPath,
    enableDebugLog: AppSettingService.appSetting.enableDebugLog,
  );
  initErrorBoundary();
  await repairStartupPersistence();
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
    ..read(nativeFitEngineServiceProvider);
  unawaited(_initVersionTracking(ref));
}

Future<void> _initVersionTracking(WidgetRef ref) async {
  final completer = Completer<String>();
  late final ProviderSubscription<AsyncValue<String>> sub;
  sub = ref.listenManual(appVersionProvider, (_, AsyncValue<String> next) {
    if (completer.isCompleted) return;
    next.whenData(completer.complete);
    if (next.hasError && !completer.isCompleted) {
      completer.completeError(next.error!, next.stackTrace);
    }
  }, fireImmediately: true);

  try {
    final appVersion = await completer.future.timeout(const Duration(milliseconds: 500));
    if (AnnouncementStateStore.lastSeenAppVersion != null) return;
    AnnouncementStateStore.setLastSeenAppVersion(appVersion);
  } on TimeoutException {
    // Provider didn't resolve in time
  } catch (_) {
    // Provider errored
  } finally {
    sub.close();
  }
}
