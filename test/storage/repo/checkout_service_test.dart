import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/branch.dart";
import "package:eve_fit_assistant/storage/repo/checkout.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/asset_manifest.dart";
import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_index.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_refs.dart";
import "package:eve_fit_assistant/storage/repo/models/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;

/// Minimal mock HTTP adapter that serves predefined responses based on URI
/// patterns. Used to test [CheckoutService.applyIncrementalUpdate] without
/// real network calls.
class _MockHttpClientAdapter implements HttpClientAdapter {
  final Map<String, _MockResponse> _responses = {};

  void addJsonResponse(String urlKey, Map<String, dynamic> json) {
    _responses[urlKey] = _MockResponse(statusCode: 200, body: utf8.encode(jsonEncode(json)));
  }

  void addBytesResponse(String urlKey, List<int> bytes) {
    _responses[urlKey] = _MockResponse(statusCode: 200, body: bytes);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final uri = options.uri.toString();
    for (final entry in _responses.entries) {
      if (uri.contains(entry.key)) {
        final resp = entry.value;
        return ResponseBody.fromBytes(
          resp.body,
          resp.statusCode,
          headers: {
            Headers.contentTypeHeader: ["application/json"],
          },
        );
      }
    }
    return ResponseBody.fromString("not found", 404);
  }

  @override
  void close({bool force = false}) {}
}

class _MockResponse {
  final int statusCode;
  final List<int> body;
  const _MockResponse({required this.statusCode, required this.body});
}

void main() {
  late String tempDir;
  late CheckoutService checkoutService;
  late _MockHttpClientAdapter mockAdapter;

  final meta = GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX");
  final source = BranchSource(channel: "stable");
  const channel = Channel.testing;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_checkout_svc_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_checkout_svc_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    EtagCache.init();

    mockAdapter = _MockHttpClientAdapter();
    final dio = Dio()..httpClientAdapter = mockAdapter;
    checkoutService = CheckoutService(
      assetStore: const AssetStore(),
      remoteCatalogService: RemoteCatalogService(dio: dio, originUrl: "https://mock.example.com"),
      diffEngine: const DiffEngine(),
    );
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("CheckoutService.readIndex / writeIndex", () {
    test("returns None when index does not exist", () {
      expect(checkoutService.readIndex(), const None());
    });

    test("writes and reads index back", () {
      final index = CheckoutIndex(
        schemaVersion: 1,
        entries: IMap({
          "hash1": CheckoutEntry(state: CheckoutState.installed),
          "hash2": CheckoutEntry(state: CheckoutState.known),
        }),
      );

      checkoutService.writeIndex(index);
      final restored = checkoutService.readIndex();

      expect(restored.isSome(), isTrue);
      expect(restored.toNullable()!.entries.keys.toSet(), {"hash1", "hash2"});
      expect(restored.toNullable()!.entries["hash1"]!.state, CheckoutState.installed);
      expect(restored.toNullable()!.entries["hash2"]!.state, CheckoutState.known);
    });

    test("index with all three states survives round-trip", () {
      final index = CheckoutIndex(
        schemaVersion: 1,
        entries: IMap({
          "a": CheckoutEntry(state: CheckoutState.installed),
          "b": CheckoutEntry(state: CheckoutState.historical),
          "c": CheckoutEntry(state: CheckoutState.known),
        }),
      );

      checkoutService.writeIndex(index);
      final restored = checkoutService.readIndex().toNullable()!;

      expect(restored.entries["a"]!.state, CheckoutState.installed);
      expect(restored.entries["b"]!.state, CheckoutState.historical);
      expect(restored.entries["c"]!.state, CheckoutState.known);
    });
  });

  group("CheckoutService.getState / setState", () {
    test("getState returns None for unknown checkout", () {
      expect(checkoutService.getState("unknown"), const None());
    });

    test("setState creates a new entry", () {
      checkoutService.setState("hash1", CheckoutState.known);

      final state = checkoutService.getState("hash1");
      expect(state, const Some(CheckoutState.known));
    });

    test("setState transitions between states", () {
      checkoutService.setState("hash1", CheckoutState.known);
      checkoutService.setState("hash1", CheckoutState.installed);

      expect(checkoutService.getState("hash1"), const Some(CheckoutState.installed));
    });

    test("setState is idempotent", () {
      checkoutService.setState("hash1", CheckoutState.installed);
      checkoutService.setState("hash1", CheckoutState.installed);

      final index = checkoutService.readIndex().toNullable()!;
      expect(index.entries.keys.length, 1);
    });

    test("setState to historical via known -> installed -> historical", () {
      checkoutService.setState("hash1", CheckoutState.known);
      checkoutService.setState("hash1", CheckoutState.installed);
      checkoutService.setState("hash1", CheckoutState.historical);

      expect(checkoutService.getState("hash1"), const Some(CheckoutState.historical));
    });
  });

  group("CheckoutService.readRefs / appendRef", () {
    test("returns None when refs do not exist", () {
      expect(checkoutService.readRefs(), const None());
    });

    test("appends a ref and reads it back", () {
      final ref = CheckoutRefRecord(
        id: "checkout_hash_1",
        installedAt: "2024-01-15T10:30:00Z",
        remoteCreatedAt: "2024-01-14T00:00:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
        parentCheckoutId: null,
      );

      checkoutService.appendRef(ref);
      final refs = checkoutService.readRefs();

      expect(refs.isSome(), isTrue);
      expect(refs.toNullable()!.refs.keys, contains("checkout_hash_1"));
      expect(refs.toNullable()!.refs["checkout_hash_1"]!.serverId, "serenity");
    });

    test("appendRef is idempotent", () {
      final ref = CheckoutRefRecord(
        id: "checkout_hash_1",
        installedAt: "2024-01-15T10:30:00Z",
        remoteCreatedAt: "2024-01-14T00:00:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
      );

      checkoutService.appendRef(ref);
      checkoutService.appendRef(ref);

      final refs = checkoutService.readRefs().toNullable()!;
      expect(refs.refs.keys.length, 1);
    });

    test("appending ref preserves previous entries", () {
      final ref1 = CheckoutRefRecord(
        id: "hash1",
        installedAt: "2024-01-01T00:00:00Z",
        remoteCreatedAt: "2024-01-01T00:00:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "S", gameBuild: "B", gameVersion: "V"),
      );
      final ref2 = CheckoutRefRecord(
        id: "hash2",
        installedAt: "2024-01-02T00:00:00Z",
        remoteCreatedAt: "2024-01-02T00:00:00Z",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "S", gameBuild: "B", gameVersion: "V"),
        parentCheckoutId: "hash1",
      );

      checkoutService.appendRef(ref1);
      checkoutService.appendRef(ref2);

      final refs = checkoutService.readRefs().toNullable()!;
      expect(refs.refs.keys.toSet(), {"hash1", "hash2"});
      expect(refs.refs["hash2"]!.parentCheckoutId, "hash1");
    });
  });

  group("CheckoutService.readManifest / writeManifest", () {
    test("returns None when manifest does not exist", () {
      expect(checkoutService.readManifest("unknown_hash"), const None());
    });

    test("writes and reads manifest back", () {
      final manifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "data/file1.txt": AssetFile(pathHash: "ph_1", hash: "h_1", size: 100),
          "data/file2.txt": AssetFile(pathHash: "ph_2", hash: "h_2", size: 200),
        }),
      );

      checkoutService.writeManifest("checkout_hash_1", manifest);
      final restored = checkoutService.readManifest("checkout_hash_1");

      expect(restored.isSome(), isTrue);
      expect(restored.toNullable()!.files.keys.toSet(), {"data/file1.txt", "data/file2.txt"});
      expect(restored.toNullable()!.files["data/file1.txt"]!.hash, "h_1");
    });

    test("manifest with empty files survives round-trip", () {
      final manifest = AssetManifest(assetsVersion: 1);

      checkoutService.writeManifest("empty_manifest", manifest);
      final restored = checkoutService.readManifest("empty_manifest");

      expect(restored.isSome(), isTrue);
      expect(restored.toNullable()!.files.isEmpty, isTrue);
    });

    test("multiple manifests can coexist", () {
      final m1 = AssetManifest(assetsVersion: 1);
      final m2 = AssetManifest(
        assetsVersion: 1,
        files: IMap({"x": AssetFile(pathHash: "ph_x", hash: "h_x", size: 1)}),
      );

      checkoutService.writeManifest("h1", m1);
      checkoutService.writeManifest("h2", m2);

      expect(checkoutService.readManifest("h1").toNullable()!.files.isEmpty, isTrue);
      expect(checkoutService.readManifest("h2").toNullable()!.files.keys, contains("x"));
    });
  });

  group("CheckoutService.lookup", () {
    test("delegates to getState — returns None for unknown checkout", () {
      expect(checkoutService.lookup("unknown"), const None());
    });

    test("delegates to getState — returns Some for known checkout", () {
      checkoutService.setState("hash1", CheckoutState.installed);
      expect(checkoutService.lookup("hash1"), const Some(CheckoutState.installed));
    });

    test("lookup returns historical after transition", () {
      checkoutService.setState("hash1", CheckoutState.installed);
      checkoutService.setState("hash1", CheckoutState.historical);
      expect(checkoutService.lookup("hash1"), const Some(CheckoutState.historical));
    });
  });

  group("CheckoutService.listByState", () {
    test("returns empty list when index is empty", () {
      expect(checkoutService.listByState(CheckoutState.installed).isEmpty, isTrue);
    });

    test("returns empty list when index is missing", () {
      expect(checkoutService.listByState(CheckoutState.known).isEmpty, isTrue);
    });

    test("returns correct checkouts for each state", () {
      checkoutService.setState("a", CheckoutState.installed);
      checkoutService.setState("b", CheckoutState.installed);
      checkoutService.setState("c", CheckoutState.known);
      checkoutService.setState("d", CheckoutState.historical);

      final installed = checkoutService.listByState(CheckoutState.installed);
      expect(installed.toSet(), {"a", "b"});

      final known = checkoutService.listByState(CheckoutState.known);
      expect(known.toSet(), {"c"});

      final historical = checkoutService.listByState(CheckoutState.historical);
      expect(historical.toSet(), {"d"});
    });

    test("state transitions update listByState results", () {
      checkoutService.setState("x", CheckoutState.known);
      expect(checkoutService.listByState(CheckoutState.known).toSet(), {"x"});
      expect(checkoutService.listByState(CheckoutState.installed).isEmpty, isTrue);

      checkoutService.setState("x", CheckoutState.installed);
      expect(checkoutService.listByState(CheckoutState.known).isEmpty, isTrue);
      expect(checkoutService.listByState(CheckoutState.installed).toSet(), {"x"});
    });
  });

  group("CheckoutService.deleteManifest", () {
    test("removes checkout directory with manifest", () {
      final manifest = AssetManifest(assetsVersion: 1);
      checkoutService.writeManifest("h1", manifest);

      final manifestPath = RepoPaths.checkoutManifestPath("h1");
      expect(File(manifestPath).existsSync(), isTrue);

      checkoutService.deleteManifest("h1");

      expect(File(manifestPath).existsSync(), isFalse);
      final dirPath = p.dirname(manifestPath);
      expect(Directory(dirPath).existsSync(), isFalse);
    });

    test("does nothing when checkout directory is absent", () {
      checkoutService.deleteManifest("nonexistent");
    });

    test("deleteManifest removes directory with nested files", () {
      final manifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({"x": AssetFile(pathHash: "ph_x", hash: "h_x", size: 1)}),
      );
      checkoutService.writeManifest("h2", manifest);
      expect(File(RepoPaths.checkoutManifestPath("h2")).existsSync(), isTrue);

      checkoutService.deleteManifest("h2");

      expect(File(RepoPaths.checkoutManifestPath("h2")).existsSync(), isFalse);
      final dirPath = p.dirname(RepoPaths.checkoutManifestPath("h2"));
      expect(Directory(dirPath).existsSync(), isFalse);
    });
  });

  group("CheckoutService.markHistorical", () {
    test("transitions installed to historical", () {
      checkoutService.setState("hash1", CheckoutState.installed);
      checkoutService.markHistorical("hash1");

      expect(checkoutService.getState("hash1"), const Some(CheckoutState.historical));
    });

    test("can transition known directly to historical", () {
      checkoutService.setState("hash1", CheckoutState.known);
      checkoutService.markHistorical("hash1");

      expect(checkoutService.getState("hash1"), const Some(CheckoutState.historical));
    });
  });

  group("CheckoutService.markKnown", () {
    test("adds new entry with known state", () {
      checkoutService.markKnown("new_hash");

      expect(checkoutService.getState("new_hash"), const Some(CheckoutState.known));
    });

    test("is idempotent for existing known entry", () {
      checkoutService.markKnown("hash1");
      checkoutService.markKnown("hash1");

      final index = checkoutService.readIndex().toNullable()!;
      expect(index.entries.keys.length, 1);
      expect(index.entries["hash1"]!.state, CheckoutState.known);
    });
  });

  // ── applyIncrementalUpdate tests ────────────────────────────────────────────────

  group("CheckoutService.applyIncrementalUpdate — preconditions", () {
    test("returns None when branch not found", () async {
      final branchService = BranchService(
        checkoutService: checkoutService,
        diffEngine: const DiffEngine(),
        assetStore: checkoutService.assetStore,
        remoteCatalogService: checkoutService.remoteCatalogService,
      );

      final result = await checkoutService.applyIncrementalUpdate(
        branchId: "nonexistent",
        targetCheckoutId: "target",
        channel: Channel.testing,
        remoteCreatedAt: "2025-06-01T00:00:00Z",
        branchService: branchService,
      );

      expect(result.isNone(), isTrue);
    });

    test("returns None when HEAD manifest is missing", () async {
      final branchService = BranchService(
        checkoutService: checkoutService,
        diffEngine: const DiffEngine(),
        assetStore: checkoutService.assetStore,
        remoteCatalogService: checkoutService.remoteCatalogService,
      );

      final b = Branch(
        schemaVersion: 1,
        id: "br_1",
        checkout: "old_chk",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "S", gameBuild: "B", gameVersion: "V"),
        source: BranchSource(channel: "stable"),
      );
      branchService.createBranch(b);

      final result = await checkoutService.applyIncrementalUpdate(
        branchId: "br_1",
        targetCheckoutId: "target",
        channel: Channel.testing,
        remoteCreatedAt: "2025-06-01T00:00:00Z",
        branchService: branchService,
      );

      expect(result.isNone(), isTrue);
    });
  });

  group("CheckoutService.applyIncrementalUpdate — empty diff", () {
    test("succeeds without downloading assets when manifests are identical", () async {
      final branchService = BranchService(
        checkoutService: checkoutService,
        diffEngine: const DiffEngine(),
        assetStore: checkoutService.assetStore,
        remoteCatalogService: checkoutService.remoteCatalogService,
      );

      branchService.createBranch(
        Branch(
          schemaVersion: 1,
          id: "br_empty",
          checkout: "same_chk",
          serverId: "serenity",
          metadata: meta,
          source: source,
        ),
      );

      final currentManifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "a.dat": AssetFile(pathHash: "ph_a", hash: "h_a", size: 10),
          "b.dat": AssetFile(pathHash: "ph_b", hash: "h_b", size: 20),
        }),
      );
      checkoutService.writeManifest("same_chk", currentManifest);

      mockAdapter.addJsonResponse(
        "same_chk",
        GenerationCheckoutCatalog(
          id: "same_chk",
          createdAt: "2025-06-01T00:00:00Z",
          serverId: "serenity",
          metadata: meta,
          files: IMap({
            "a.dat": AssetFile(pathHash: "ph_a", hash: "h_a", size: 10),
            "b.dat": AssetFile(pathHash: "ph_b", hash: "h_b", size: 20),
          }),
        ).toJson(),
      );

      final result = await checkoutService.applyIncrementalUpdate(
        branchId: "br_empty",
        targetCheckoutId: "same_chk",
        channel: channel,
        remoteCreatedAt: "2025-06-01T00:00:00Z",
        branchService: branchService,
      );

      expect(result.isSome(), isTrue);
      expect(result.toNullable(), "same_chk");

      final branch = branchService.readBranch("br_empty").toNullable()!;
      expect(branch.checkout, "same_chk");

      expect(checkoutService.readManifest("same_chk").isSome(), isTrue);

      expect(checkoutService.getState("same_chk"), const Some(CheckoutState.installed));
    });
  });

  group("CheckoutService.applyIncrementalUpdate — happy path", () {
    test("downloads only changed files (2 added, 1 modified, 1 deleted)", () async {
      final branchService = BranchService(
        checkoutService: checkoutService,
        diffEngine: const DiffEngine(),
        assetStore: checkoutService.assetStore,
        remoteCatalogService: checkoutService.remoteCatalogService,
      );

      branchService.createBranch(
        Branch(
          schemaVersion: 1,
          id: "br_happy",
          checkout: "old_chk",
          serverId: "serenity",
          metadata: meta,
          source: source,
        ),
      );

      final currentManifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "keep.dat": AssetFile(pathHash: "ph_keep", hash: "h_keep", size: 10),
          "modify.dat": AssetFile(pathHash: "ph_mod", hash: "h_mod_old", size: 20),
          "delete.dat": AssetFile(pathHash: "ph_del", hash: "h_del", size: 30),
        }),
      );
      checkoutService.writeManifest("old_chk", currentManifest);

      final catalogJson = GenerationCheckoutCatalog(
        id: "new_chk",
        createdAt: "2025-06-01T00:00:00Z",
        serverId: "serenity",
        metadata: meta,
        files: IMap({
          "keep.dat": AssetFile(pathHash: "ph_keep", hash: "h_keep", size: 10),
          "modify.dat": AssetFile(pathHash: "ph_mod", hash: "h_mod_new", size: 25),
          "add_a.dat": AssetFile(pathHash: "ph_add_a", hash: "h_add_a", size: 40),
          "add_b.dat": AssetFile(pathHash: "ph_add_b", hash: "h_add_b", size: 50),
        }),
      ).toJson();
      mockAdapter.addJsonResponse("new_chk", catalogJson);

      mockAdapter.addBytesResponse("ph_add_a/h_add_a", [1, 2, 3]);
      mockAdapter.addBytesResponse("ph_add_b/h_add_b", [4, 5, 6]);
      mockAdapter.addBytesResponse("ph_mod/h_mod_new", [7, 8, 9]);

      final result = await checkoutService.applyIncrementalUpdate(
        branchId: "br_happy",
        targetCheckoutId: "new_chk",
        channel: channel,
        remoteCreatedAt: "2025-06-01T00:00:00Z",
        branchService: branchService,
      );

      expect(result.isSome(), isTrue);
      expect(result.toNullable(), "new_chk");

      final branch = branchService.readBranch("br_happy").toNullable()!;
      expect(branch.checkout, "new_chk");
      expect(branch.reflog.length, 1);
      expect(branch.reflog.first.from, "old_chk");
      expect(branch.reflog.first.to, "new_chk");

      expect(branch.diffs.length, 1);
      final diff = branch.diffs.values.first;
      expect(diff.from, "old_chk");
      expect(diff.to, "new_chk");
      expect(diff.adds.length, 2);
      expect(diff.modifies.length, 1);
      expect(diff.deletes.length, 1);

      final newManifest = checkoutService.readManifest("new_chk").toNullable()!;
      expect(newManifest.files.keys.toSet(), {"keep.dat", "modify.dat", "add_a.dat", "add_b.dat"});

      expect(checkoutService.getState("new_chk"), const Some(CheckoutState.installed));
      expect(checkoutService.getState("old_chk"), const Some(CheckoutState.historical));

      final refs = checkoutService.readRefs().toNullable()!;
      expect(refs.refs.containsKey("new_chk"), isTrue);
      expect(refs.refs["new_chk"]!.parentCheckoutId, "old_chk");

      expect(checkoutService.assetStore.existsSync("ph_add_a", "h_add_a"), isTrue);
      expect(checkoutService.assetStore.existsSync("ph_add_b", "h_add_b"), isTrue);
      expect(checkoutService.assetStore.existsSync("ph_mod", "h_mod_new"), isTrue);
    });
  });

  group("CheckoutService.applyIncrementalUpdate — interruption recovery", () {
    test("retry skips already-downloaded files and succeeds", () async {
      final branchService = BranchService(
        checkoutService: checkoutService,
        diffEngine: const DiffEngine(),
        assetStore: checkoutService.assetStore,
        remoteCatalogService: checkoutService.remoteCatalogService,
      );

      branchService.createBranch(
        Branch(
          schemaVersion: 1,
          id: "br_retry",
          checkout: "old_chk",
          serverId: "serenity",
          metadata: meta,
          source: source,
        ),
      );

      final currentManifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({"a.dat": AssetFile(pathHash: "ph_a", hash: "h_a_old", size: 10)}),
      );
      checkoutService.writeManifest("old_chk", currentManifest);

      final catalogJson = GenerationCheckoutCatalog(
        id: "retry_chk",
        createdAt: "2025-06-01T00:00:00Z",
        serverId: "serenity",
        metadata: meta,
        files: IMap({
          "a.dat": AssetFile(pathHash: "ph_a", hash: "h_a_new", size: 15),
          "b.dat": AssetFile(pathHash: "ph_b", hash: "h_b", size: 20),
        }),
      ).toJson();
      mockAdapter.addJsonResponse("retry_chk", catalogJson);

      mockAdapter.addBytesResponse("ph_a/h_a_new", [1, 2, 3]);

      var result = await checkoutService.applyIncrementalUpdate(
        branchId: "br_retry",
        targetCheckoutId: "retry_chk",
        channel: channel,
        remoteCreatedAt: "2025-06-01T00:00:00Z",
        branchService: branchService,
      );

      expect(result.isNone(), isTrue);

      mockAdapter.addBytesResponse("ph_b/h_b", [4, 5, 6]);

      result = await checkoutService.applyIncrementalUpdate(
        branchId: "br_retry",
        targetCheckoutId: "retry_chk",
        channel: channel,
        remoteCreatedAt: "2025-06-01T00:00:00Z",
        branchService: branchService,
      );

      expect(result.isSome(), isTrue);
      expect(result.toNullable(), "retry_chk");

      expect(checkoutService.assetStore.existsSync("ph_a", "h_a_new"), isTrue);
      expect(checkoutService.assetStore.existsSync("ph_b", "h_b"), isTrue);

      final branch = branchService.readBranch("br_retry").toNullable()!;
      expect(branch.checkout, "retry_chk");
    });
  });

  group("CheckoutService.applyIncrementalUpdate — historical transition", () {
    test("old checkout stays installed when referenced by another branch", () async {
      final branchService = BranchService(
        checkoutService: checkoutService,
        diffEngine: const DiffEngine(),
        assetStore: checkoutService.assetStore,
        remoteCatalogService: checkoutService.remoteCatalogService,
      );

      branchService.createBranch(
        Branch(
          schemaVersion: 1,
          id: "br_ref_1",
          checkout: "shared_chk",
          serverId: "serenity",
          metadata: meta,
          source: source,
        ),
      );
      branchService.createBranch(
        Branch(
          schemaVersion: 1,
          id: "br_ref_2",
          checkout: "shared_chk",
          serverId: "serenity",
          metadata: meta,
          source: source,
        ),
      );

      final currentManifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({"x.dat": AssetFile(pathHash: "ph_x", hash: "h_x", size: 1)}),
      );
      checkoutService.writeManifest("shared_chk", currentManifest);

      final catalogJson = GenerationCheckoutCatalog(
        id: "new_shared",
        createdAt: "2025-06-02T00:00:00Z",
        serverId: "serenity",
        metadata: meta,
        files: IMap({"x.dat": AssetFile(pathHash: "ph_x", hash: "h_x2", size: 2)}),
      ).toJson();
      mockAdapter.addJsonResponse("new_shared", catalogJson);
      mockAdapter.addBytesResponse("ph_x/h_x2", [9, 9]);

      final result = await checkoutService.applyIncrementalUpdate(
        branchId: "br_ref_1",
        targetCheckoutId: "new_shared",
        channel: channel,
        remoteCreatedAt: "2025-06-02T00:00:00Z",
        branchService: branchService,
      );

      expect(result.isSome(), isTrue);

      expect(checkoutService.getState("shared_chk"), const Some(CheckoutState.installed));

      expect(checkoutService.getState("new_shared"), const Some(CheckoutState.installed));
    });

    test("old checkout transitions to historical when unreferenced", () async {
      final branchService = BranchService(
        checkoutService: checkoutService,
        diffEngine: const DiffEngine(),
        assetStore: checkoutService.assetStore,
        remoteCatalogService: checkoutService.remoteCatalogService,
      );

      branchService.createBranch(
        Branch(
          schemaVersion: 1,
          id: "br_orphan",
          checkout: "lonely_chk",
          serverId: "serenity",
          metadata: meta,
          source: source,
        ),
      );

      final currentManifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({"y.dat": AssetFile(pathHash: "ph_y", hash: "h_y1", size: 3)}),
      );
      checkoutService.writeManifest("lonely_chk", currentManifest);

      final catalogJson = GenerationCheckoutCatalog(
        id: "new_lonely",
        createdAt: "2025-06-03T00:00:00Z",
        serverId: "serenity",
        metadata: meta,
        files: IMap({"y.dat": AssetFile(pathHash: "ph_y", hash: "h_y2", size: 5)}),
      ).toJson();
      mockAdapter.addJsonResponse("new_lonely", catalogJson);
      mockAdapter.addBytesResponse("ph_y/h_y2", [7, 7, 7]);

      checkoutService.setState("lonely_chk", CheckoutState.installed);

      final result = await checkoutService.applyIncrementalUpdate(
        branchId: "br_orphan",
        targetCheckoutId: "new_lonely",
        channel: channel,
        remoteCreatedAt: "2025-06-03T00:00:00Z",
        branchService: branchService,
      );

      expect(result.isSome(), isTrue);

      expect(checkoutService.getState("lonely_chk"), const Some(CheckoutState.historical));
      expect(checkoutService.getState("new_lonely"), const Some(CheckoutState.installed));
    });
  });
}
