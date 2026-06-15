import "dart:io";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/branch.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/checkout.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late String tempDir;
  late BranchService branchService;

  final meta = GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX");
  final source = BranchSource(channel: "stable");

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_branch_watch_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_branch_watch_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");

    final checkoutService = CheckoutService(
      assetStore: const AssetStore(),
      remoteCatalogService: RemoteCatalogService(dio: Dio(), originUrl: "https://example.com"),
      diffEngine: const DiffEngine(),
    );
    branchService = BranchService(
      checkoutService: checkoutService,
      diffEngine: const DiffEngine(),
      assetStore: checkoutService.assetStore,
      remoteCatalogService: checkoutService.remoteCatalogService,
    );
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Branch makeBranch(String id, String checkout) => Branch(
    schemaVersion: 1,
    id: id,
    checkout: checkout,
    serverId: "serenity",
    metadata: meta,
    source: source,
    name: IMap({"en": "Test Branch"}),
  );

  group("BranchService.watchBranches", () {
    test("emits branch list after a new branch is created", () async {
      final stream = branchService.watchBranches();

      branchService.createBranch(makeBranch("wb_1", "chk_1"));

      final result = await stream
          .firstWhere((list) => list.any((b) => b.id == "wb_1"))
          .timeout(const Duration(seconds: 5));
      expect(result.length, 1);
      expect(result.first.id, "wb_1");
    });

    test("emits updated branch list after branch deletion", () async {
      branchService.createBranch(makeBranch("wb_a", "chk_a"));
      branchService.createBranch(makeBranch("wb_b", "chk_b"));

      final stream = branchService.watchBranches();

      branchService.deleteBranch("wb_a");

      final result = await stream
          .firstWhere((list) => list.length == 1 && list.first.id == "wb_b")
          .timeout(const Duration(seconds: 5));
      expect(result.length, 1);
      expect(result.first.id, "wb_b");
    });

    test("emits initial empty list when no branches exist", () async {
      final stream = branchService.watchBranches();

      // Capture the first two emissions
      final future = stream.take(2).toList();

      // Trigger a directory scan by touching a file inside the branches directory,
      // then removing it. This causes the watcher to fire and discoverBranches()
      // to run against the (still-empty) directory.
      final triggerFile = File(p.join(RepoPaths.branchesPath, ".trigger"));
      triggerFile.createSync();
      triggerFile.deleteSync();

      // Wait for the debounced empty-scan emission
      await Future<void>.delayed(const Duration(milliseconds: 400));

      // Create a branch to produce the second emission
      branchService.createBranch(makeBranch("wb_1", "chk_1"));

      final events = await future.timeout(const Duration(seconds: 5));

      expect(events.first, isEmpty);
      expect(events.last.any((b) => b.id == "wb_1"), isTrue);
    });
  });
}
