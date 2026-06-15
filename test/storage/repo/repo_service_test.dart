import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/storage/repo/active.dart";
import "package:eve_fit_assistant/storage/repo/announcements.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/branch.dart";
import "package:eve_fit_assistant/storage/repo/checkout.dart";
import "package:eve_fit_assistant/storage/repo/checkout_resolution.dart";
import "package:eve_fit_assistant/storage/repo/compatibility.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_index.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/models/compatibility.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/service.dart";
import "package:eve_fit_assistant/storage/repo/verification.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;

void main() {
  late String tempDir;
  late RepoService repoService;
  late ActiveService activeService;
  late BranchService branchService;
  late CheckoutService checkoutService;
  late AssetStore assetStore;
  late DiffEngine diffEngine;
  late CheckoutResolver checkoutResolver;
  late VerificationService verificationService;
  late RemoteCatalogService remoteCatalogService;
  late AnnouncementService announcementService;
  late CompatibilityService compatibilityService;

  final meta = GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX");
  const checkoutId = "hash_abc123";

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_repo_svc_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    Directory(p.join(tempDir, "tmp")).createSync(recursive: true);
    EtagCache.init();

    activeService = ActiveService();
    assetStore = const AssetStore();
    diffEngine = const DiffEngine();
    announcementService = const AnnouncementService();
    compatibilityService = const CompatibilityService();
    remoteCatalogService = RemoteCatalogService(dio: Dio(), originUrl: "https://example.com");
    checkoutService = CheckoutService(
      assetStore: assetStore,
      remoteCatalogService: remoteCatalogService,
      diffEngine: diffEngine,
    );
    branchService = BranchService(
      checkoutService: checkoutService,
      diffEngine: diffEngine,
      assetStore: assetStore,
      remoteCatalogService: remoteCatalogService,
    );
    checkoutResolver = CheckoutResolver(
      checkoutService: checkoutService,
      remoteCatalogService: remoteCatalogService,
      activeService: activeService,
      compatibilityService: compatibilityService,
    );
    verificationService = VerificationService(
      checkoutService: checkoutService,
      assetStore: assetStore,
      branchService: branchService,
      remoteCatalogService: remoteCatalogService,
    );
    repoService = RepoService(
      activeService: activeService,
      branchService: branchService,
      checkoutService: checkoutService,
      assetStore: assetStore,
      diffEngine: diffEngine,
      checkoutResolver: checkoutResolver,
      verificationService: verificationService,
      remoteCatalogService: remoteCatalogService,
      announcementService: announcementService,
    );
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("RepoService.activeBranch / activeBranchId / activeCheckoutId", () {
    final active = Active(
      schemaVersion: 2,
      branchId: "550e8400-e29b-41d4-a716-446655440000",
      checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
      activatedAt: "2024-01-15T10:30:00Z",
      serverId: "serenity",
      metadata: meta,
    );

    test("returns None when active.json does not exist", () {
      expect(repoService.activeBranch(), const None());
      expect(repoService.activeBranchId(), const None());
      expect(repoService.activeCheckoutId(), const None());
    });

    test("delegates to ActiveService for activeBranch()", () async {
      await activeService.writeActive(active);

      final result = repoService.activeBranch();
      expect(result.isSome(), isTrue);
      expect(result.toNullable(), active);
    });

    test("delegates to ActiveService for activeBranchId()", () async {
      await activeService.writeActive(active);

      final result = repoService.activeBranchId();
      expect(result.isSome(), isTrue);
      expect(result.toNullable(), active.branchId);
    });

    test("delegates to ActiveService for activeCheckoutId()", () async {
      await activeService.writeActive(active);

      final result = repoService.activeCheckoutId();
      expect(result.isSome(), isTrue);
      expect(result.toNullable(), active.checkoutId);
    });

    test("activeBranch returns None for active without branchId", () async {
      final activeNoBranch = active.copyWith(branchId: null);
      await activeService.writeActive(activeNoBranch);

      expect(repoService.activeBranch().isSome(), isTrue);
      expect(repoService.activeBranchId(), const None());
    });
  });

  group("RepoService.branches", () {
    test("returns empty list when no branches exist", () {
      expect(repoService.branches(), const IList<Branch>.empty());
    });

    test("delegates to BranchService.discoverBranches()", () {
      final branch = Branch(
        schemaVersion: 1,
        id: "550e8400-e29b-41d4-a716-446655440000",
        checkout: "checkout_hash_1",
        serverId: "serenity",
        metadata: meta,
        source: BranchSource(channel: "stable"),
        name: IMap({"en": "Test Branch"}),
      );
      branchService.createBranch(branch);

      final result = repoService.branches();
      expect(result.length, 1);
      expect(result.first.id, "550e8400-e29b-41d4-a716-446655440000");
    });
  });

  group("RepoService.resolveCheckoutRef", () {
    test("delegates to CheckoutResolver.resolveAsync()", () async {
      final ref = CheckoutRef(checkoutId: "nonexistent", serverId: "serenity", metadata: meta);

      final resolution = await repoService.resolveCheckoutRef(ref, channel: Channel.stable);
      expect(resolution is CheckoutResolutionApproximate, isTrue);
    });

    test("returns Approximate for empty checkoutId", () async {
      final ref = CheckoutRef(checkoutId: "", serverId: "serenity", metadata: meta);

      final resolution = await repoService.resolveCheckoutRef(ref, channel: Channel.stable);
      expect(resolution is CheckoutResolutionApproximate, isTrue);
    });
  });

  group("RepoService.resolveCheckoutRefAsync", () {
    test("delegates to CheckoutResolver.resolveAsync()", () async {
      final ref = CheckoutRef(checkoutId: "nonexistent", serverId: "serenity", metadata: meta);

      final resolution = await repoService.resolveCheckoutRefAsync(ref, channel: Channel.stable);
      expect(resolution is CheckoutResolutionApproximate, isTrue);
    });

    test("returns Approximate for empty checkoutId", () async {
      final ref = CheckoutRef(checkoutId: "", serverId: "serenity", metadata: meta);

      final resolution = await repoService.resolveCheckoutRefAsync(ref, channel: Channel.stable);
      expect(resolution is CheckoutResolutionApproximate, isTrue);
    });

    test("returns Compatible when checkout is installed locally", () async {
      checkoutService.setState("hash_1", CheckoutState.installed);

      final ref = CheckoutRef(checkoutId: "hash_1", serverId: "serenity", metadata: meta);
      final resolution = await repoService.resolveCheckoutRefAsync(ref, channel: Channel.stable);
      expect(resolution is CheckoutResolutionCompatible, isTrue);
    });
  });

  group("RepoService.verify", () {
    test("delegates to VerificationService.verify()", () {
      final issues = repoService.verify();
      expect(issues, const IList.empty());
    });
  });

  group("RepoService.prune", () {
    test("delegates to VerificationService.prune() without error", () {
      expect(() => repoService.prune(), returnsNormally);
    });
  });

  group("RepoService.verifyAndRepair", () {
    test("delegates to VerificationService.repairAll()", () async {
      final issues = await repoService.verifyAndRepair(channel: Channel.stable);
      expect(issues, const IList.empty());
    });
  });

  group("RepoService.recoverPartialDownloads", () {
    test("resets installed checkout with no manifest to known", () {
      checkoutService.setState("hash_partial", CheckoutState.installed);
      // No manifest written — simulate partial download

      repoService.recoverPartialDownloads();

      final state = checkoutService.getState("hash_partial").toNullable()!;
      expect(state, CheckoutState.known);
    });

    test("preserves installed checkout with intact manifest", () {
      checkoutService.setState(checkoutId, CheckoutState.installed);
      // Write a valid manifest and asset file
      final content = Uint8List.fromList([1, 2, 3]);
      final hashes = assetStore.writeFileSync("data/keep.txt", content);
      final manifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          hashes.pathHash: AssetFile(
            pathHash: hashes.pathHash,
            hash: hashes.contentHash,
            size: content.length,
          ),
        }),
      );
      checkoutService.writeManifest(checkoutId, manifest);

      repoService.recoverPartialDownloads();

      final state = checkoutService.getState(checkoutId).toNullable()!;
      expect(state, CheckoutState.installed);
    });

    test("ignores non-installed checkouts", () {
      checkoutService.setState("hash_known", CheckoutState.known);
      checkoutService.setState("hash_hist", CheckoutState.historical);

      repoService.recoverPartialDownloads();

      expect(checkoutService.getState("hash_known").toNullable()!, CheckoutState.known);
      expect(checkoutService.getState("hash_hist").toNullable()!, CheckoutState.historical);
    });
  });

  group("RepoService.revertActiveBranchTo", () {
    AssetManifest makeManifest(Map<String, AssetFile> files) =>
        AssetManifest(assetsVersion: 1, files: IMap(files));

    AssetFile makeFile(String pathHash, String hash, int size) =>
        AssetFile(pathHash: pathHash, hash: hash, size: size);

    test("returns error in detached mode (no active branch)", () async {
      final result = await repoService.revertActiveBranchTo(
        targetCheckoutId: "H1",
        channel: Channel.stable,
      );

      expect(result.isSome(), isTrue);
      expect(result.toNullable()!, contains("detached mode"));
    });

    test("success path: updates branch HEAD, active.json, and index", () async {
      const engine = DiffEngine();

      // Set up checkout chain H1→H2
      final h1Files = {"a": makeFile("ph_a", "h_a1", 10)};
      final h2Files = {"a": makeFile("ph_a", "h_a1", 10), "b": makeFile("ph_b", "h_b1", 20)};

      checkoutService.writeManifest("H1", makeManifest(h1Files));
      checkoutService.writeManifest("H2", makeManifest(h2Files));

      // Write assets for both checkouts
      for (final file in h1Files.values) {
        assetStore.writeFileByHashesSync(file.pathHash, file.hash, Uint8List(file.size));
      }
      for (final file in h2Files.values) {
        assetStore.writeFileByHashesSync(file.pathHash, file.hash, Uint8List(file.size));
      }

      // Set up index
      checkoutService.setState("H1", CheckoutState.installed);
      checkoutService.setState("H2", CheckoutState.installed);

      // Create branch at H1
      final branch = branchService.create(
        schemaVersion: 1,
        checkout: "H1",
        name: IMap({"en": "Revert Test"}),
        serverId: "serenity",
        metadata: meta,
        source: BranchSource(channel: "stable"),
      );

      // Move HEAD to H2
      final h1Manifest = checkoutService.readManifest("H1").toNullable()!;
      final h2Manifest = checkoutService.readManifest("H2").toNullable()!;
      final diff = engine.computeDiff(
        h1Manifest,
        h2Manifest,
        fromCheckoutId: "H1",
        toCheckoutId: "H2",
        fromCreatedAt: "2025-01-01T00:00:00Z",
        toCreatedAt: "",
      );
      branchService.moveHead(
        branchId: branch.id,
        toCheckoutId: "H2",
        diff: diff,
        timestamp: "2025-02-01T00:00:00Z",
      );

      // Set active
      await activeService.writeActive(
        Active(
          schemaVersion: 2,
          checkoutId: "H2",
          activatedAt: "2025-02-01T00:00:00Z",
          serverId: "serenity",
          metadata: meta,
          branchId: branch.id,
        ),
      );

      // Execute revert
      final result = await repoService.revertActiveBranchTo(
        targetCheckoutId: "H1",
        channel: Channel.stable,
      );

      expect(result.isNone(), isTrue);

      // Verify active.json updated
      final active = activeService.readActive().toNullable()!;
      expect(active.checkoutId, "H1");
      expect(active.branchId, branch.id);

      // Verify branch HEAD updated
      final updatedBranch = branchService.readBranch(branch.id).toNullable()!;
      expect(updatedBranch.checkout, "H1");
      // 1 self-ref from create + 1 moveHead + 1 revert = 3 reflog entries
      expect(updatedBranch.reflog.length, 3);
      expect(updatedBranch.reflog[2].from, "H2");
      expect(updatedBranch.reflog[2].to, "H1");

      // Verify index updated
      final h1State = checkoutService.getState("H1").toNullable()!;
      expect(h1State, CheckoutState.installed);
    });
  });
}
