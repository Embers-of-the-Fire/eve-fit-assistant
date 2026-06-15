import "dart:io";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/repo_error.dart";
import "package:eve_fit_assistant/storage/repo/repo_state.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;
import "package:riverpod/riverpod.dart";

void main() {
  late String tempDir;

  final meta = GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX");
  final testDio = Dio();

  AppSetting testAppSetting() => AppSetting(
    locale: Locale.en,
    enableDebugLog: false,
    shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
    showCheckoutImpactWarnings: true,
    typeListReturnBehavior: TypeListReturnBehavior.previousPage,
    remoteContent: const RemoteContentSetting(originUrl: "https://example.com"),
  );

  ProviderContainer createContainer() {
    return ProviderContainer(
      overrides: [
        appSettingServiceProvider.overrideWithValue(testAppSetting()),
        remoteDioProvider.overrideWithValue(testDio),
      ],
    );
  }

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_repo_st_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_repo_st_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    Directory(p.join(tempDir, "tmp")).createSync(recursive: true);
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("RepoStateNotifier.default state", () {
    test("initial state is uninitialized", () {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(repoStateProvider.notifier);
      expect(notifier.state, const RepoState.uninitialized());
    });

    test("isInitialized returns false for uninitialized", () {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(repoStateProvider.notifier);
      expect(notifier.isInitialized, isFalse);
    });

    test("active getter returns null for uninitialized", () {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(repoStateProvider.notifier);
      expect(notifier.active, isNull);
    });
  });

  group("RepoStateNotifier.initialize", () {
    test("transitions to active with empty checkoutId when no active.json exists", () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(repoStateProvider.notifier);
      await notifier.initialize();

      expect(notifier.isInitialized, isTrue);
      expect(notifier.state, isA<RepoStateActive>());
      final active = notifier.active!;
      expect(active.checkoutId, "");
      expect(active.branchId, isNull);
      expect(active.schemaVersion, 2);
    });

    test("transitions through initializing to active", () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(repoStateProvider.notifier);

      final states = <RepoState>[];
      container.listen(repoStateProvider, (prev, next) {
        states.add(next);
      });

      await notifier.initialize();

      expect(states.length, 2);
      expect(states[0], isA<RepoStateInitializing>());
      expect(states[1], isA<RepoStateActive>());
    });

    test("transitions to active with valid data when active.json and manifest exist", () async {
      final container = createContainer();
      addTearDown(container.dispose);

      const checkoutId = "hash_abc123";
      final checkoutService = container.read(checkoutServiceProvider);
      final activeService = container.read(activeServiceProvider);

      // Write a manifest
      final manifest = AssetManifest(assetsVersion: 1, files: const IMap.empty());
      checkoutService.writeManifest(checkoutId, manifest);

      // Write active.json
      final active = Active(
        schemaVersion: 2,
        branchId: "branch_1",
        checkoutId: checkoutId,
        activatedAt: "2024-01-15T10:30:00Z",
        serverId: "serenity",
        metadata: meta,
      );
      await activeService.writeActive(active);

      final notifier = container.read(repoStateProvider.notifier);
      await notifier.initialize();

      expect(notifier.isInitialized, isTrue);
      expect(notifier.state, isA<RepoStateActive>());
      final result = notifier.active!;
      expect(result.checkoutId, checkoutId);
      expect(result.branchId, "branch_1");
    });

    test("transitions to error when active.json is corrupt", () async {
      final container = createContainer();
      addTearDown(container.dispose);

      // Write invalid JSON to active.json
      final activeFile = File(RepoPaths.activePath);
      activeFile.parent.createSync(recursive: true);
      activeFile.writeAsStringSync("not valid json");

      final notifier = container.read(repoStateProvider.notifier);
      await notifier.initialize();

      expect(notifier.state, isA<RepoStateError>());
      final error = (notifier.state as RepoStateError).error;
      expect(error, isA<RepoErrorCorrupt>());
      final corrupt = error as RepoErrorCorrupt;
      expect(corrupt.message, contains("corrupt"));
    });

    test("transitions to error when active.json points to a checkout with no manifest", () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final activeService = container.read(activeServiceProvider);

      // Write a valid active.json pointing to a nonexistent checkout
      const missingCheckoutId = "nonexistent_checkout";
      final active = Active(
        schemaVersion: 2,
        branchId: "branch_1",
        checkoutId: missingCheckoutId,
        activatedAt: "2024-01-15T10:30:00Z",
        serverId: "serenity",
        metadata: meta,
      );
      await activeService.writeActive(active);

      final notifier = container.read(repoStateProvider.notifier);
      await notifier.initialize();

      expect(notifier.state, isA<RepoStateError>());
      final error = (notifier.state as RepoStateError).error;
      expect(error, isA<RepoErrorCorrupt>());
      final corrupt = error as RepoErrorCorrupt;
      expect(corrupt.message, contains("manifest is missing"));
    });
  });

  group("RepoStateNotifier.isInitialized", () {
    test("returns true only in active state", () {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(repoStateProvider.notifier);
      expect(notifier.isInitialized, isFalse);

      notifier.state = const RepoState.initializing();
      expect(notifier.isInitialized, isFalse);

      notifier.state = RepoState.active(
        active: Active(
          schemaVersion: 2,
          branchId: null,
          checkoutId: "",
          activatedAt: "2024-01-15T10:30:00Z",
          serverId: "",
          metadata: meta,
        ),
      );
      expect(notifier.isInitialized, isTrue);

      notifier.state = RepoState.error(error: RepoError.storage(message: "test"));
      expect(notifier.isInitialized, isFalse);
    });
  });

  group("RepoStateNotifier.active getter", () {
    test("returns non-null Active only in active state", () {
      final container = createContainer();
      addTearDown(container.dispose);

      final notifier = container.read(repoStateProvider.notifier);

      notifier.state = RepoState.active(
        active: Active(
          schemaVersion: 2,
          branchId: "b1",
          checkoutId: "c1",
          activatedAt: "2024-01-15T10:30:00Z",
          serverId: "serenity",
          metadata: meta,
        ),
      );
      expect(notifier.active, isNotNull);
      expect(notifier.active!.checkoutId, "c1");

      notifier.state = const RepoState.uninitialized();
      expect(notifier.active, isNull);

      notifier.state = const RepoState.initializing();
      expect(notifier.active, isNull);

      notifier.state = RepoState.error(error: RepoError.storage(message: "test"));
      expect(notifier.active, isNull);
    });
  });

  group("Provider cycle check", () {
    test("repoStateProvider and repoServiceProvider coexist without cycles", () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(() => container.read(repoStateProvider), returnsNormally);
      expect(() => container.read(repoServiceProvider), returnsNormally);

      final notifier = container.read(repoStateProvider.notifier);
      expect(notifier.state, isA<RepoStateUninitialized>());
    });
  });
}
