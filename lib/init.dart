// Init helpers for the package

import "dart:async";
import "dart:ui";

import "package:eve_fit_assistant/config/loading.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/announcements/remote/body_cache.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_store.dart";
import "package:eve_fit_assistant/features/feedback/feedback_state_store.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:eve_fit_assistant/native/frb_generated.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/path_migration.dart";
import "package:eve_fit_assistant/storage/persistence/startup_repair.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter/widgets.dart";
import "package:flutter_easyloading/flutter_easyloading.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:fluttertoast/fluttertoast.dart";

/// Holds the initialized state stores so callers can build ProviderScope
/// overrides from them.
class InitializedStores {
  const InitializedStores({
    required this.announcementStateStore,
    required this.appVersionStateStore,
  });

  final AnnouncementStateStore announcementStateStore;
  final AppVersionStateStore appVersionStateStore;
}

Future<InitializedStores> initSingletons() async {
  WidgetsFlutterBinding.ensureInitialized();
  await RustLib.init();
  await PathProvider.init();
  AppSettingService.init();
  GlobalLogger.init(
    PathProvider.logsPath,
    enableDebugLog: AppSettingService.appSetting.enableDebugLog,
  );
  await RemoteCache.init();
  initErrorBoundary();
  GlobalLoading.init();

  final announcementStateStore = AnnouncementStateStore(settingsPath: PathProvider.settingsPath);
  final appVersionStateStore = AppVersionStateStore(settingsPath: PathProvider.settingsPath);

  unawaited(_deferredInit(announcementStateStore, appVersionStateStore));

  return InitializedStores(
    announcementStateStore: announcementStateStore,
    appVersionStateStore: appVersionStateStore,
  );
}

Future<void> _deferredInit(
  AnnouncementStateStore announcementStateStore,
  AppVersionStateStore appVersionStateStore,
) async {
  try {
    await const StoragePathMigrator().migrateIfNeeded();

    final migration = await announcementStateStore.init();
    await appVersionStateStore.init();

    if (migration != null) {
      final lastSeen = migration.lastSeenAppVersion;
      if (lastSeen != null && appVersionStateStore.lastSeenAppVersion == null) {
        appVersionStateStore.setLastSeenAppVersion(lastSeen);
      }
      final lastAck = migration.lastAcknowledgedReleaseId;
      if (lastAck != null && appVersionStateStore.lastAcknowledgedReleaseId == null) {
        appVersionStateStore.acknowledgeRelease(lastAck);
      }
      await appVersionStateStore.ensureSynced;
    }

    FeedbackStateStore.init();
    await AnnouncementBodyCache.init();
    await repairStartupPersistence();
  } catch (_) {
    // Deferred init failures are non-fatal; individual features degrade gracefully.
  }
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
    final store = ref.read(appVersionStateStoreProvider);
    if (store.lastSeenAppVersion != null) return;
    store.setLastSeenAppVersion(appVersion);
  } on TimeoutException {
    // Provider didn't resolve in time
  } catch (_) {
    // Provider errored
  } finally {
    sub.close();
  }
}
