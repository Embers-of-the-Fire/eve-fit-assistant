import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/branch.dart";
import "package:eve_fit_assistant/storage/repo/checkout.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/storage/repo/models/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;

void main() {
  late String tempDir;
  late BranchService branchService;

  final meta = GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX");
  final source = BranchSource(channel: "stable");

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_branch_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_branch_svc_").path;
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
    name: IMap({"en": "Test Branch", "zh": "测试分支"}),
  );

  group("BranchService.createBranch / readBranch", () {
    test("creates and reads a branch back", () {
      final branch = makeBranch("550e8400-e29b-41d4-a716-446655440000", "checkout_hash_1");

      branchService.createBranch(branch);
      final restored = branchService.readBranch("550e8400-e29b-41d4-a716-446655440000");

      expect(restored.isSome(), isTrue);
      expect(restored.toNullable()!.id, "550e8400-e29b-41d4-a716-446655440000");
      expect(restored.toNullable()!.checkout, "checkout_hash_1");
      expect(restored.toNullable()!.serverId, "serenity");
    });

    test("returns None for non-existent branch", () {
      expect(branchService.readBranch("nonexistent"), const None());
    });
  });

  group("BranchService.discoverBranches", () {
    test("returns empty list when branches directory is empty", () {
      expect(branchService.discoverBranches().isEmpty, isTrue);
    });

    test("discovers all created branches", () {
      branchService.createBranch(makeBranch("id_1", "chk_1"));
      branchService.createBranch(makeBranch("id_2", "chk_2"));
      branchService.createBranch(makeBranch("id_3", "chk_3"));

      final branches = branchService.discoverBranches();

      expect(branches.length, 3);
      final ids = branches.map((b) => b.id).toSet();
      expect(ids, {"id_1", "id_2", "id_3"});
    });

    test("excludes branch after deletion", () {
      branchService.createBranch(makeBranch("id_1", "chk_1"));
      branchService.createBranch(makeBranch("id_2", "chk_2"));

      branchService.deleteBranch("id_1");

      final branches = branchService.discoverBranches();
      expect(branches.length, 1);
      expect(branches.first.id, "id_2");
    });
  });

  group("BranchService.updateBranchHead", () {
    test("updates checkout and appends reflog entry", () {
      branchService.createBranch(makeBranch("branch_1", "initial_chk"));

      branchService.updateBranchHead("branch_1", "new_chk");

      final branch = branchService.readBranch("branch_1").toNullable()!;
      expect(branch.checkout, "new_chk");
      expect(branch.reflog.length, 1);
      expect(branch.reflog.first.from, "initial_chk");
      expect(branch.reflog.first.to, "new_chk");
    });

    test("accumulates reflog entries across multiple HEAD movements", () {
      branchService.createBranch(makeBranch("branch_1", "chk_1"));

      branchService.updateBranchHead("branch_1", "chk_2");
      branchService.updateBranchHead("branch_1", "chk_3");

      final branch = branchService.readBranch("branch_1").toNullable()!;
      expect(branch.checkout, "chk_3");
      expect(branch.reflog.length, 2);
      expect(branch.reflog[0].from, "chk_1");
      expect(branch.reflog[0].to, "chk_2");
      expect(branch.reflog[1].from, "chk_2");
      expect(branch.reflog[1].to, "chk_3");
    });
  });

  group("BranchService.pinBranch / unpinBranch", () {
    test("pinBranch sets pinned to true", () {
      branchService.createBranch(makeBranch("branch_1", "chk_1"));

      branchService.pinBranch("branch_1");
      final branch = branchService.readBranch("branch_1").toNullable()!;
      expect(branch.pinned, isTrue);
    });

    test("unpinBranch sets pinned back to false", () {
      branchService.createBranch(makeBranch("branch_1", "chk_1"));
      branchService.pinBranch("branch_1");
      branchService.unpinBranch("branch_1");

      final branch = branchService.readBranch("branch_1").toNullable()!;
      expect(branch.pinned, isFalse);
    });
  });

  group("BranchService.deleteBranch", () {
    test("removes branch file", () {
      branchService.createBranch(makeBranch("branch_1", "chk_1"));
      expect(branchService.readBranch("branch_1").isSome(), isTrue);

      branchService.deleteBranch("branch_1");
      expect(branchService.readBranch("branch_1"), const None());
    });

    test("deleting non-existent branch does not throw", () {
      branchService.deleteBranch("nonexistent");
    });
  });

  group("BranchService.create", () {
    test("generates UUID and writes branch with initial reflog", () {
      final branch = branchService.create(
        schemaVersion: 1,
        checkout: "initial_checkout",
        name: IMap({"en": "Factory Branch"}),
        serverId: "serenity",
        metadata: meta,
        source: source,
      );

      expect(branch.id, isNotEmpty);
      expect(branch.id.length, greaterThan(10));
      expect(branch.checkout, "initial_checkout");
      expect(branch.reflog.length, 1);
      expect(branch.reflog.first.from, "initial_checkout");
      expect(branch.reflog.first.to, "initial_checkout");
      expect(branch.reflog.first.timestamp, isNotEmpty);

      final restored = branchService.readBranch(branch.id);
      expect(restored.isSome(), isTrue);
      expect(restored.toNullable()!.id, branch.id);
    });

    test("supports pinned flag", () {
      final branch = branchService.create(
        schemaVersion: 1,
        checkout: "chk",
        name: IMap({"en": "Pinned"}),
        serverId: "serenity",
        metadata: meta,
        source: source,
        pinned: true,
      );

      expect(branch.pinned, isTrue);
    });
  });

  group("BranchService.moveHead", () {
    test("atomically stores reflog entry and diff", () {
      branchService.createBranch(makeBranch("mb_1", "from_chk"));

      final diff = Diff(
        from: "from_chk",
        to: "to_chk",
        fromCreatedAt: "2025-01-01T00:00:00Z",
        toCreatedAt: "2025-06-01T00:00:00Z",
        adds: IList([DiffAdd(path: "a.dat", pathHash: "ph", hash: "h", size: 42)]),
      );
      final result = branchService.moveHead(
        branchId: "mb_1",
        toCheckoutId: "to_chk",
        diff: diff,
        timestamp: "2025-06-01T12:00:00Z",
      );

      expect(result.isNone(), isTrue);

      final branch = branchService.readBranch("mb_1").toNullable()!;
      expect(branch.checkout, "to_chk");
      expect(branch.reflog.length, 1);
      expect(branch.reflog.first.from, "from_chk");
      expect(branch.reflog.first.to, "to_chk");
      expect(branch.reflog.first.timestamp, "2025-06-01T12:00:00Z");
      expect(branch.diffs.length, 1);
      expect(branch.diffs.values.first.to, "to_chk");
    });

    test("accumulates reflog and diffs across multiple moves", () {
      branchService.createBranch(makeBranch("mb_2", "chk_a"));

      final diff1 = Diff(
        from: "chk_a",
        to: "chk_b",
        fromCreatedAt: "2025-01-01T00:00:00Z",
        toCreatedAt: "2025-02-01T00:00:00Z",
      );
      branchService.moveHead(
        branchId: "mb_2",
        toCheckoutId: "chk_b",
        diff: diff1,
        timestamp: "ts1",
      );

      final diff2 = Diff(
        from: "chk_b",
        to: "chk_c",
        fromCreatedAt: "2025-02-01T00:00:00Z",
        toCreatedAt: "2025-03-01T00:00:00Z",
      );
      branchService.moveHead(
        branchId: "mb_2",
        toCheckoutId: "chk_c",
        diff: diff2,
        timestamp: "ts2",
      );

      final branch = branchService.readBranch("mb_2").toNullable()!;
      expect(branch.checkout, "chk_c");
      expect(branch.reflog.length, 2);
      expect(branch.reflog[0].from, "chk_a");
      expect(branch.reflog[0].to, "chk_b");
      expect(branch.reflog[1].from, "chk_b");
      expect(branch.reflog[1].to, "chk_c");
      expect(branch.diffs.length, 2);
    });

    test("returns Some with error message when diff.from does not match checkout", () {
      branchService.createBranch(makeBranch("mb_3", "chk_x"));

      final diff = Diff(
        from: "wrong_chk",
        to: "chk_y",
        fromCreatedAt: "2025-01-01T00:00:00Z",
        toCreatedAt: "2025-02-01T00:00:00Z",
      );
      final result = branchService.moveHead(
        branchId: "mb_3",
        toCheckoutId: "chk_y",
        diff: diff,
        timestamp: "ts",
      );

      expect(result.isSome(), isTrue);
      expect(result.toNullable()!, contains("does not match"));

      final branch = branchService.readBranch("mb_3").toNullable()!;
      expect(branch.checkout, "chk_x");
      expect(branch.reflog.length, 0);
      expect(branch.diffs.length, 0);
    });

    test("returns Some with error message when diff.to does not match toCheckoutId", () {
      branchService.createBranch(makeBranch("mb_4", "chk_x"));

      final diff = Diff(
        from: "chk_x",
        to: "wrong_to",
        fromCreatedAt: "2025-01-01T00:00:00Z",
        toCreatedAt: "2025-02-01T00:00:00Z",
      );
      final result = branchService.moveHead(
        branchId: "mb_4",
        toCheckoutId: "chk_y",
        diff: diff,
        timestamp: "ts",
      );

      expect(result.isSome(), isTrue);
      expect(result.toNullable()!, contains("does not match"));
    });

    test("returns None when branch not found", () {
      final diff = Diff(
        from: "chk_a",
        to: "chk_b",
        fromCreatedAt: "2025-01-01T00:00:00Z",
        toCreatedAt: "2025-02-01T00:00:00Z",
      );
      final result = branchService.moveHead(
        branchId: "nonexistent",
        toCheckoutId: "chk_b",
        diff: diff,
        timestamp: "ts",
      );

      expect(result.isNone(), isTrue);
    });
  });

  group("BranchService.branchExists", () {
    test("returns true for created branch", () {
      branchService.createBranch(makeBranch("be_1", "chk"));
      expect(branchService.branchExists("be_1"), isTrue);
    });

    test("returns false for non-existent branch", () {
      expect(branchService.branchExists("no_such_branch"), isFalse);
    });
  });

  group("BranchService.sourceChannel", () {
    test("returns channel string for existing branch", () {
      branchService.createBranch(makeBranch("sc_1", "chk"));
      expect(branchService.sourceChannel("sc_1"), some("stable"));
    });

    test("returns None for non-existent branch", () {
      expect(branchService.sourceChannel("no_such_branch"), const None());
    });

    test("returns correct channel for testing source", () {
      final testingSource = BranchSource(channel: "testing");
      final branch = Branch(
        schemaVersion: 1,
        id: "sc_2",
        checkout: "chk",
        serverId: "serenity",
        metadata: meta,
        source: testingSource,
      );
      branchService.createBranch(branch);
      expect(branchService.sourceChannel("sc_2"), some("testing"));
    });
  });

  group("BranchService.isCheckoutReferenced", () {
    test("returns true when checkout is a branch HEAD", () {
      branchService.createBranch(makeBranch("ref_h_1", "chk_head"));

      expect(branchService.isCheckoutReferenced("chk_head"), isTrue);
    });

    test("returns true when checkout appears in a branch reflog", () {
      branchService.createBranch(makeBranch("ref_r_1", "chk_a"));
      branchService.updateBranchHead("ref_r_1", "chk_b");

      expect(branchService.isCheckoutReferenced("chk_a"), isTrue);
      expect(branchService.isCheckoutReferenced("chk_b"), isTrue);
    });

    test("returns false for orphaned checkout not in any HEAD or reflog", () {
      branchService.createBranch(makeBranch("ref_o_1", "chk_present"));

      expect(branchService.isCheckoutReferenced("chk_orphaned"), isFalse);
    });

    test("checks across all branches", () {
      branchService.createBranch(makeBranch("ref_x_1", "chk_x"));
      branchService.createBranch(makeBranch("ref_x_2", "chk_y"));

      branchService.updateBranchHead("ref_x_1", "chk_z");

      expect(branchService.isCheckoutReferenced("chk_x"), isTrue);
      expect(branchService.isCheckoutReferenced("chk_y"), isTrue);
      expect(branchService.isCheckoutReferenced("chk_z"), isTrue);
      expect(branchService.isCheckoutReferenced("chk_w"), isFalse);
    });

    test("excludes branch from reference check", () {
      branchService.createBranch(makeBranch("ref_ex_1", "chk_old"));
      branchService.updateBranchHead("ref_ex_1", "chk_new");

      // Without exclusion, chk_old is in ref_ex_1's reflog → referenced
      expect(branchService.isCheckoutReferenced("chk_old"), isTrue);

      // With exclusion of ref_ex_1, chk_old is not referenced by other branches
      expect(branchService.isCheckoutReferenced("chk_old", excludeBranchId: "ref_ex_1"), isFalse);
    });
  });

  group("BranchService.revertTo", () {
    AssetManifest makeManifest(Map<String, AssetFile> files) =>
        AssetManifest(assetsVersion: 1, files: IMap(files));

    AssetFile makeFile(String pathHash, String hash, int size) =>
        AssetFile(pathHash: pathHash, hash: hash, size: size);

    // Helper: sets up a branch with a chain of checkouts and stored diffs.
    // Returns the branch ID and list of checkout IDs in order [H1, H2, ...].
    Future<({String id, IList<String> checkouts})> setupChain(
      IList<String> diffFromCreatedAts,
    ) async {
      const engine = DiffEngine();

      // Build checkout IDs in order: H1, H2, ...
      final checkouts = <String>[];
      for (var i = 0; i <= diffFromCreatedAts.length; i++) {
        final num = i + 1;
        checkouts.add("H$num");
      }

      // Build manifests: each checkout adds one file (plus keeps all previous)
      // H1: {a}
      // H2: {a, b}
      // H3: {a, b, c}
      // H4: {a, b, c, d} ...
      for (var i = 0; i < checkouts.length; i++) {
        final files = <String, AssetFile>{};
        for (var j = 0; j <= i; j++) {
          final letter = String.fromCharCode("a".codeUnitAt(0) + j);
          files[letter] = makeFile("ph_$letter", "h_${letter}1", (j + 1) * 10);
        }
        branchService.checkoutService.writeManifest(checkouts[i], makeManifest(files));
      }

      // Write asset files for all checkouts so revert can find and delete them
      for (final checkout in checkouts) {
        final manifest = branchService.checkoutService.readManifest(checkout).toNullable()!;
        for (final entry in manifest.files.entries) {
          final file = entry.value;
          branchService.assetStore.writeFileByHashesSync(
            file.pathHash,
            file.hash,
            Uint8List(file.size),
          );
        }
      }

      // Create branch at H1
      final branch = branchService.create(
        schemaVersion: 1,
        checkout: checkouts.first,
        name: IMap({"en": "Revert Test Branch"}),
        serverId: "serenity",
        metadata: meta,
        source: source,
      );

      // Move HEAD through the chain, computing and storing diffs
      for (var i = 0; i < diffFromCreatedAts.length; i++) {
        final fromManifest = branchService.checkoutService.readManifest(checkouts[i]).toNullable()!;
        final toManifest = branchService.checkoutService
            .readManifest(checkouts[i + 1])
            .toNullable()!;
        final diff = engine.computeDiff(
          fromManifest,
          toManifest,
          fromCheckoutId: checkouts[i],
          toCheckoutId: checkouts[i + 1],
          fromCreatedAt: diffFromCreatedAts[i],
          toCreatedAt: "",
        );
        branchService.moveHead(
          branchId: branch.id,
          toCheckoutId: checkouts[i + 1],
          diff: diff,
          timestamp: "2025-0${i + 1}-01T00:00:00Z",
        );
      }

      return (id: branch.id, checkouts: checkouts.toIList());
    }

    test("returns error for non-existent branch", () async {
      final result = await branchService.revertTo(
        branchId: "nonexistent",
        targetCheckoutId: "H1",
        channel: Channel.stable,
      );

      expect(result.isSome(), isTrue);
      expect(result.toNullable()!, contains("branch not found"));
    });

    test("returns error when target not in reflog chain", () async {
      // Set up branch at H1 with no history
      branchService.createBranch(
        Branch(
          schemaVersion: 1,
          id: "br_no_tgt",
          checkout: "H1",
          serverId: "serenity",
          metadata: meta,
          source: source,
        ),
      );
      branchService.checkoutService.writeManifest("H1", makeManifest({}));

      final result = await branchService.revertTo(
        branchId: "br_no_tgt",
        targetCheckoutId: "H9",
        channel: Channel.stable,
      );

      expect(result.isSome(), isTrue);
      expect(result.toNullable()!, contains("not in reflog chain"));
    });

    test("reverts one step: H2→H1", () async {
      final setup = await setupChain(IList(["2025-01-01T00:00:00Z"]));

      final result = await branchService.revertTo(
        branchId: setup.id,
        targetCheckoutId: setup.checkouts[0], // H1
        channel: Channel.stable,
      );

      expect(result.isNone(), isTrue);

      final branch = branchService.readBranch(setup.id).toNullable()!;
      // HEAD should be back at H1
      expect(branch.checkout, setup.checkouts[0]);
      // Reflog: self-ref from create, H1→H2 move, H2→H1 revert = 3 entries
      expect(branch.reflog.length, 3);
      expect(branch.reflog[2].from, setup.checkouts[1]); // H2
      expect(branch.reflog[2].to, setup.checkouts[0]); // H1
      // Two diffs stored: H1→H2 (moveHead) + H2→H1 (forward diff from revert)
      expect(branch.diffs.length, 2);
    });

    test("reverts multi-step: H4→H1", () async {
      final setup = await setupChain(
        IList(["2025-01-01T00:00:00Z", "2025-02-01T00:00:00Z", "2025-03-01T00:00:00Z"]),
      );

      final result = await branchService.revertTo(
        branchId: setup.id,
        targetCheckoutId: setup.checkouts[0], // H1
        channel: Channel.stable,
      );

      expect(result.isNone(), isTrue);

      final branch = branchService.readBranch(setup.id).toNullable()!;
      expect(branch.checkout, setup.checkouts[0]);
      // 1 self-ref + 3 moveHead + 1 revert = 5 reflog entries
      expect(branch.reflog.length, 5);
      expect(branch.reflog[4].from, setup.checkouts[3]); // H4
      expect(branch.reflog[4].to, setup.checkouts[0]); // H1
      expect(branch.diffs.length, 4);
    });

    test("returns error when missing diff entry", () async {
      final now = DateTime.now().toUtc();
      final y = now.year.toString().padLeft(4, "0");
      final mo = now.month.toString().padLeft(2, "0");
      final d = now.day.toString().padLeft(2, "0");
      final h = now.hour.toString().padLeft(2, "0");
      final mi = now.minute.toString().padLeft(2, "0");
      final s = now.second.toString().padLeft(2, "0");
      final timestamp = "$y-$mo-${d}T$h:$mi:${s}Z";

      final branch = Branch(
        schemaVersion: 1,
        id: "br_missing_diff",
        checkout: "H3",
        serverId: "serenity",
        metadata: meta,
        source: source,
        reflog: IList([
          ReflogEntry(id: "diff_0", timestamp: timestamp, from: "H1", to: "H1"),
          ReflogEntry(id: "diff_1", timestamp: timestamp, from: "H1", to: "H2"),
          ReflogEntry(id: "diff_2", timestamp: timestamp, from: "H2", to: "H3"),
        ]),
        diffs: IMap({
          "diff_0": Diff(from: "H1", to: "H1", fromCreatedAt: "", toCreatedAt: ""),
          "diff_1": Diff(from: "H1", to: "H2", fromCreatedAt: "", toCreatedAt: ""),
          // diff_2 is intentionally missing
        }),
      );
      branchService.createBranch(branch);
      branchService.checkoutService.writeManifest("H1", makeManifest({}));
      branchService.checkoutService.writeManifest("H2", makeManifest({}));
      branchService.checkoutService.writeManifest("H3", makeManifest({}));

      final result = await branchService.revertTo(
        branchId: "br_missing_diff",
        targetCheckoutId: "H1",
        channel: Channel.stable,
      );

      expect(result.isSome(), isTrue);
      expect(result.toNullable()!, contains("missing diff"));
    });

    test("returns error when target manifest is missing", () async {
      final setup = await setupChain(IList(["2025-01-01T00:00:00Z"]));

      // Delete the target manifest
      branchService.checkoutService.deleteManifest(setup.checkouts[0]);

      final result = await branchService.revertTo(
        branchId: setup.id,
        targetCheckoutId: setup.checkouts[0],
        channel: Channel.stable,
      );

      expect(result.isSome(), isTrue);
      expect(result.toNullable()!, contains("missing manifest"));
    });
  });
}
