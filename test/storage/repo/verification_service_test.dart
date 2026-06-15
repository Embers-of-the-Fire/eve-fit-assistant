import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
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
import "package:eve_fit_assistant/storage/repo/models/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/verification.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:path/path.dart" as p;

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
  late AssetStore assetStore;
  late CheckoutService checkoutService;
  late BranchService branchService;
  late VerificationService verificationService;
  late _MockHttpClientAdapter mockAdapter;

  const checkoutId = "hash_abc123";
  const testPath = "data/test.txt";

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_verify_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    EtagCache.init();

    assetStore = const AssetStore();
    mockAdapter = _MockHttpClientAdapter();
    final dio = Dio()..httpClientAdapter = mockAdapter;
    final remoteCatalog = RemoteCatalogService(dio: dio, originUrl: "https://mock.example.com");

    checkoutService = CheckoutService(
      assetStore: assetStore,
      remoteCatalogService: remoteCatalog,
      diffEngine: const DiffEngine(),
    );
    branchService = BranchService(
      checkoutService: checkoutService,
      diffEngine: const DiffEngine(),
      assetStore: assetStore,
      remoteCatalogService: remoteCatalog,
    );
    verificationService = VerificationService(
      checkoutService: checkoutService,
      assetStore: assetStore,
      branchService: branchService,
      remoteCatalogService: remoteCatalog,
    );
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  AssetManifest _writeFileAndManifest(String cid) {
    final content = Uint8List.fromList([1, 2, 3]);
    final hashes = assetStore.writeFileSync(testPath, content);

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
    checkoutService.writeManifest(cid, manifest);
    return manifest;
  }

  group("verify()", () {
    test("returns empty list when no checkouts exist", () {
      final issues = verificationService.verify();
      expect(issues.isEmpty, isTrue);
    });

    test("returns empty list when installed checkout is intact", () {
      checkoutService.setState(checkoutId, CheckoutState.installed);
      _writeFileAndManifest(checkoutId);

      final issues = verificationService.verify();
      expect(issues.isEmpty, isTrue);
    });

    test("reports missing manifest for installed checkout", () {
      checkoutService.setState(checkoutId, CheckoutState.installed);
      // No manifest written

      final issues = verificationService.verify();
      expect(issues.length, 1);
      expect(issues.first, isA<VerificationNoManifest>());
      expect(issues.first.checkoutId, checkoutId);
    });

    test("reports missing files for installed checkout", () {
      checkoutService.setState(checkoutId, CheckoutState.installed);
      // Write manifest referencing a file that doesn't exist
      final manifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "data/missing.txt": AssetFile(pathHash: "ph_missing", hash: "ch_missing", size: 100),
        }),
      );
      checkoutService.writeManifest(checkoutId, manifest);

      final issues = verificationService.verify();
      expect(issues.length, 1);
      expect(issues.first, isA<VerificationMissingFiles>());
      final mf = issues.first as VerificationMissingFiles;
      expect(mf.checkoutId, checkoutId);
      expect(mf.missingFiles.missing.isNotEmpty, isTrue);
    });

    test("skips non-installed checkouts", () {
      checkoutService.setState("hash_historical", CheckoutState.historical);
      checkoutService.setState("hash_known", CheckoutState.known);

      final issues = verificationService.verify();
      expect(issues.isEmpty, isTrue);
    });

    test("reports issues for multiple installed checkouts", () {
      checkoutService.setState("hash_a", CheckoutState.installed);
      checkoutService.setState("hash_b", CheckoutState.installed);
      // No manifests for either

      final issues = verificationService.verify();
      expect(issues.length, 2);
      expect(issues.whereType<VerificationNoManifest>().length, 2);
    });
  });

  group("repairInterruptedDownload()", () {
    test("returns Right for non-existent checkoutId", () {
      final result = verificationService.repairInterruptedDownload("unknown");
      expect(result.isRight(), isTrue);
    });

    test("returns Right for known checkout (not installed)", () {
      checkoutService.setState(checkoutId, CheckoutState.known);
      final result = verificationService.repairInterruptedDownload(checkoutId);
      expect(result.isRight(), isTrue);
    });

    test("rolls back to known when installed but no manifest", () {
      checkoutService.setState(checkoutId, CheckoutState.installed);

      final result = verificationService.repairInterruptedDownload(checkoutId);
      expect(result.isRight(), isTrue);

      expect(checkoutService.getState(checkoutId), const Some(CheckoutState.known));
    });

    test("rolls back to known when installed but files missing", () {
      checkoutService.setState(checkoutId, CheckoutState.installed);
      final manifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          "data/missing.txt": AssetFile(pathHash: "ph_missing", hash: "ch_missing", size: 100),
        }),
      );
      checkoutService.writeManifest(checkoutId, manifest);

      final result = verificationService.repairInterruptedDownload(checkoutId);
      expect(result.isRight(), isTrue);
      expect(checkoutService.getState(checkoutId), const Some(CheckoutState.known));
    });

    test("returns Right with no action when checkout is fully intact", () {
      checkoutService.setState(checkoutId, CheckoutState.installed);
      _writeFileAndManifest(checkoutId);

      final result = verificationService.repairInterruptedDownload(checkoutId);
      expect(result.isRight(), isTrue);
      expect(checkoutService.getState(checkoutId), const Some(CheckoutState.installed));
    });
  });

  group("prune()", () {
    test("prunes unreferenced assets", () {
      // Write an installed checkout with a file
      checkoutService.setState(checkoutId, CheckoutState.installed);
      _writeFileAndManifest(checkoutId);

      // Write an orphan file not referenced by any manifest
      final orphanContent = Uint8List.fromList([9, 9, 9]);
      assetStore.writeFileSync("data/orphan.txt", orphanContent);
      final orphanHashes = assetStore.writeFileSync("data/orphan2.txt", orphanContent);

      // Verify orphans exist before pruning
      expect(assetStore.existsSync(orphanHashes.pathHash, orphanHashes.contentHash), isTrue);

      verificationService.prune();

      // The orphan should be gone
      expect(assetStore.existsSync(orphanHashes.pathHash, orphanHashes.contentHash), isFalse);
    });

    test("cleans up orphaned historical checkouts", () {
      checkoutService.setState("hash_hist", CheckoutState.historical);
      checkoutService.setState(checkoutId, CheckoutState.installed);

      // No branch references hash_hist
      verificationService.prune();

      final index = checkoutService.readIndex().toNullable()!;
      expect(index.entries.containsKey("hash_hist"), isFalse);
    });

    test("preserves historical checkouts referenced by branch reflog", () {
      final now = "2024-01-01T00:00:00Z";
      checkoutService.setState("hash_old", CheckoutState.historical);
      checkoutService.setState("hash_cur", CheckoutState.installed);

      final branch = Branch(
        schemaVersion: 1,
        id: "test-branch",
        checkout: "hash_cur",
        serverId: "serenity",
        metadata: GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX"),
        source: BranchSource(channel: "stable"),
        name: IMap({"en": "Test"}),
        reflog: IList([ReflogEntry(id: "r1", timestamp: now, from: "hash_old", to: "hash_cur")]),
      );
      branchService.createBranch(branch);

      verificationService.prune();

      final index = checkoutService.readIndex().toNullable()!;
      // hash_old is referenced by the reflog, should be preserved
      expect(index.entries.containsKey("hash_old"), isTrue);
      expect(index.entries.containsKey("hash_cur"), isTrue);
    });
  });

  group("repairAll()", () {
    test("re-downloads missing files successfully", () async {
      checkoutService.setState(checkoutId, CheckoutState.installed);

      // Write a file to get real hashes, then delete it to simulate missing file
      final content = Uint8List.fromList([1, 2, 3]);
      final hashes = assetStore.writeFileSync("data/repair.txt", content);
      assetStore.deleteFileSync(hashes.pathHash, hashes.contentHash);

      // Manifest references the real hashes of the now-deleted file
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

      // Mock the asset fetch to provide the original bytes
      mockAdapter.addBytesResponse("resources/assets", content);

      final unresolved = await verificationService.repairAll(channel: Channel.testing);

      expect(unresolved.isEmpty, isTrue);
      expect(assetStore.existsSync(hashes.pathHash, hashes.contentHash), isTrue);
    });

    test("re-downloads hash-mismatched files successfully", () async {
      checkoutService.setState(checkoutId, CheckoutState.installed);

      // Write correct content and get its real hash
      final correctContent = Uint8List.fromList([9, 8, 7]);
      final hashes = assetStore.writeFileSync("data/mismatch.txt", correctContent);

      // Overwrite the file with wrong content (different bytes, same pathHash)
      final wrongContent = Uint8List.fromList([1, 1]);
      assetStore.deleteFileSync(hashes.pathHash, hashes.contentHash);
      // Write wrong content at the correct content hash location to cause mismatch
      assetStore.writeFileByHashesSync(hashes.pathHash, hashes.contentHash, wrongContent);

      // Manifest references the correct hash
      final manifest = AssetManifest(
        assetsVersion: 1,
        files: IMap({
          hashes.pathHash: AssetFile(
            pathHash: hashes.pathHash,
            hash: hashes.contentHash,
            size: correctContent.length,
          ),
        }),
      );
      checkoutService.writeManifest(checkoutId, manifest);

      // Mock the asset fetch to provide corrected bytes
      mockAdapter.addBytesResponse("resources/assets", correctContent);

      final unresolved = await verificationService.repairAll(channel: Channel.testing);

      expect(unresolved.isEmpty, isTrue);
    });

    test("returns unresolved issues on network failure", () async {
      checkoutService.setState(checkoutId, CheckoutState.installed);

      final content = Uint8List.fromList([4, 5, 6]);
      final hashes = assetStore.writeFileSync("data/network_fail.txt", content);
      assetStore.deleteFileSync(hashes.pathHash, hashes.contentHash);

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
      // No mock response — 404 will be returned

      final unresolved = await verificationService.repairAll(channel: Channel.testing);

      expect(unresolved.length, 1);
      expect(unresolved.first, isA<VerificationMissingFiles>());
      expect(assetStore.existsSync(hashes.pathHash, hashes.contentHash), isFalse);
    });

    test("transitions state to known for VerificationNoManifest", () async {
      checkoutService.setState(checkoutId, CheckoutState.installed);
      // No manifest written

      final unresolved = await verificationService.repairAll(channel: Channel.testing);

      expect(unresolved.isEmpty, isTrue);
      expect(checkoutService.getState(checkoutId), const Some(CheckoutState.known));
    });
  });
}
