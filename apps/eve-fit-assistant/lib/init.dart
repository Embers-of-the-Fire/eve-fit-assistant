// Init helpers for the package

import "dart:async";

import "package:efa_compat/wasm_probe.dart";
import "package:eve_fit_assistant/config/engine_availability.dart";
import "package:eve_fit_assistant/config/loading.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/storage_root.dart";
import "package:eve_fit_assistant/features/announcements/remote/body_cache.dart";
import "package:eve_fit_assistant/features/announcements/repository/repository.dart";
import "package:eve_fit_assistant/features/announcements/state/announcement_state_store.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_notifier.dart";
import "package:eve_fit_assistant/features/app_update/state/app_version_state_store.dart";
import "package:eve_fit_assistant/features/feedback/feedback_state_store.dart";
import "package:eve_fit_assistant/features/fit_link/boot_probe.dart";
import "package:eve_fit_assistant/features/remote_content/cache_manager.dart";
import "package:eve_fit_assistant/native/api/init.dart" as native_init;
import "package:eve_fit_assistant/native/api/logging.dart" as native_logging;
import "package:eve_fit_assistant/native/frb_generated.dart";
import "package:eve_fit_assistant/storage/chat/service.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:eve_fit_assistant/storage/fs/user_store.dart";
import "package:eve_fit_assistant/storage/path_migration.dart";
import "package:eve_fit_assistant/storage/persistence/startup_repair.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/foundation.dart";
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
  if (kIsWeb) {
    // The engine wasm is built with atomics so FRB can run engine calls in
    // its Web Worker pool; the shared memory behind that only exists on
    // cross-origin isolated origins. Without the COOP/COEP headers the module
    // cannot instantiate, so boot without the native engine instead. Also
    // probe the bundle first: FRB's web loader awaits the script's onLoad,
    // which never fires when the WASM bundle is missing (onError fires
    // instead) — init would hang forever.
    const engineBundleUrl = "pkg/rust_lib_eve_fit_assistant.js";
    if (!crossOriginIsolated()) {
      debugPrint(
        "Page is not cross-origin isolated (missing COOP/COEP headers); "
        "booting without native engine.",
      );
    } else if (await wasmBundleAvailable(engineBundleUrl)) {
      try {
        await RustLib.init();
        NativeEngineAvailability.setAvailable(value: true);
      } on Object catch (e) {
        debugPrint("RustLib.init() failed on web: $e");
      }
    } else {
      debugPrint(
        "WASM engine bundle not found at $engineBundleUrl; booting without native engine.",
      );
    }
  } else {
    await RustLib.init();
    NativeEngineAvailability.setAvailable(value: true);
    if (defaultTargetPlatform == TargetPlatform.android) {
      native_init.initPlatform();
    }
  }
  await PathProvider.init();
  if (!kIsWeb) {
    // The configured storage root must apply before any store opens; it is
    // read from a bootstrap file under the platform-default support dir.
    PathProvider.applyStorageRootOverride(await StorageRootPreference.read());
    await const StoragePathMigrator().migrateIfNeeded();
  }
  await AppSettingService.init();
  await ChatStorageService.init();
  GlobalLogger.init(
    PathProvider.logsPath,
    enableDebugLog: AppSettingService.appSetting.enableDebugLog,
  );
  _setupRustLogging();
  await RemoteCache.init();
  initErrorBoundary();
  GlobalLoading.init();

  final settingsStore = createUserDocStore(UserDataDomain.settings);
  await settingsStore.init();
  final announcementStateStore = AnnouncementStateStore(store: settingsStore);
  final appVersionStateStore = AppVersionStateStore(store: settingsStore);
  // Must complete before runApp: the update gate reads pendingInstall
  // synchronously as soon as a release resolves, so the persisted state has
  // to be loaded before the gate mounts.
  await appVersionStateStore.init();

  probeFitLinkBootUrl();

  unawaited(_deferredInit(announcementStateStore, appVersionStateStore));

  return InitializedStores(
    announcementStateStore: announcementStateStore,
    appVersionStateStore: appVersionStateStore,
  );
}

/// Forwards Rust `log` records into the app logger so native-side logs
/// (e.g. chat tool timings) share the Dart console + file pipeline.
///
/// Best-effort: skipped when the native engine is unavailable (e.g. web
/// without cross-origin isolation), where the FRB runtime never initializes.
void _setupRustLogging() {
  if (!NativeEngineAvailability.available) return;
  try {
    native_logging.createLogStream(debug: AppSettingService.appSetting.enableDebugLog).listen((
      entry,
    ) {
      final message = "[${entry.target}] ${entry.message}";
      switch (entry.level) {
        case "ERROR":
          error(message);
        case "WARN":
          warning(message);
        case "INFO":
          info(message);
        default:
          debug(message);
      }
    }, onError: (Object e) => debugPrint("Rust log stream error: $e"));
  } on Object catch (e) {
    debugPrint("Failed to set up Rust logging: $e");
  }
}

Future<void> _deferredInit(
  AnnouncementStateStore announcementStateStore,
  AppVersionStateStore appVersionStateStore,
) async {
  try {
    final migration = await announcementStateStore.init();

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

    await FeedbackStateStore.init();
    await AnnouncementBodyCache.init();
    await repairStartupPersistence();
  } catch (e, st) {
    error("Deferred initialization failed", stackTrace: st, error: e);
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
