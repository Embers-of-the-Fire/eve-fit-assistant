import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/storage/repo/active.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/checkout.dart";
import "package:eve_fit_assistant/storage/repo/checkout_resolution.dart";
import "package:eve_fit_assistant/storage/repo/compatibility.dart";
import "package:eve_fit_assistant/storage/repo/diff.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_index.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/models/compatibility.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

class _MockHttpAdapter implements HttpClientAdapter {
  const _MockHttpAdapter(this._responses);
  final Map<String, ({int statusCode, String data})> _responses;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    final response = _responses[url];
    if (response == null) {
      throw DioException(requestOptions: options, message: "No mock for $url");
    }
    return ResponseBody.fromString(
      response.data,
      response.statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late String tempDir;
  late CheckoutResolver resolver;
  late CheckoutService checkoutService;
  late ActiveService activeService;
  late CompatibilityService compatibilityService;

  const meta = GameMetadata(gameServer: "Serenity", gameBuild: "21.06", gameVersion: "EQUINOX");

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_resolver_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    EtagCache.init();

    final dio = Dio()
      ..httpClientAdapter = const _MockHttpAdapter({})
      ..options.validateStatus = (status) => true;
    final svc = RemoteCatalogService(dio: dio, originUrl: "https://example.com");

    checkoutService = CheckoutService(
      assetStore: const AssetStore(),
      remoteCatalogService: svc,
      diffEngine: const DiffEngine(),
    );
    activeService = ActiveService();
    compatibilityService = const CompatibilityService();
    resolver = CheckoutResolver(
      checkoutService: checkoutService,
      remoteCatalogService: RemoteCatalogService(dio: dio, originUrl: "https://example.com"),
      activeService: activeService,
      compatibilityService: compatibilityService,
    );
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  CheckoutRef makeRef(String checkoutId) =>
      CheckoutRef(checkoutId: checkoutId, serverId: "serenity", metadata: meta);

  group("CheckoutResolver.resolve (sync local-only)", () {
    test("returns Approximate for empty checkoutId sentinel", () {
      final result = resolver.resolve(makeRef(""));
      expect(result, isA<CheckoutResolutionApproximate>());
    });

    test("returns Compatible when checkout is installed", () {
      checkoutService.setState("hash_1", CheckoutState.installed);

      final result = resolver.resolve(makeRef("hash_1"));
      expect(result, isA<CheckoutResolutionCompatible>());
    });

    test("returns OfferReSync when checkout is historical", () {
      checkoutService.setState("hash_2", CheckoutState.historical);

      final result = resolver.resolve(makeRef("hash_2"));
      expect(result, isA<CheckoutResolutionOfferReSync>());
      final sync = result as CheckoutResolutionOfferReSync;
      expect(sync.checkoutId, "hash_2");
    });

    test("returns OfferDownload when checkout is known", () {
      checkoutService.setState("hash_3", CheckoutState.known);

      final result = resolver.resolve(makeRef("hash_3"));
      expect(result, isA<CheckoutResolutionOfferDownload>());
      final download = result as CheckoutResolutionOfferDownload;
      expect(download.checkoutId, "hash_3");
    });

    test("returns Approximate when checkout is not in index (no remote fallback)", () {
      final result = resolver.resolve(makeRef("unknown_hash"));
      expect(result, isA<CheckoutResolutionApproximate>());
      final approx = result as CheckoutResolutionApproximate;
      expect(approx.checkoutId, "unknown_hash");
    });
  });

  group("CheckoutResolver.resolveAsync", () {
    test("returns Approximate for empty checkoutId sentinel", () async {
      final result = await resolver.resolveAsync(makeRef(""), channel: Channel.stable);
      expect(result, isA<CheckoutResolutionApproximate>());
    });

    test("returns Compatible when checkout is installed", () async {
      checkoutService.setState("hash_1", CheckoutState.installed);

      final result = await resolver.resolveAsync(makeRef("hash_1"), channel: Channel.stable);
      expect(result, isA<CheckoutResolutionCompatible>());
    });

    test("returns OfferReSync when checkout is historical", () async {
      checkoutService.setState("hash_2", CheckoutState.historical);

      final result = await resolver.resolveAsync(makeRef("hash_2"), channel: Channel.stable);
      expect(result, isA<CheckoutResolutionOfferReSync>());
      final sync = result as CheckoutResolutionOfferReSync;
      expect(sync.checkoutId, "hash_2");
    });

    test("returns OfferDownload when checkout is known", () async {
      checkoutService.setState("hash_3", CheckoutState.known);

      final result = await resolver.resolveAsync(makeRef("hash_3"), channel: Channel.stable);
      expect(result, isA<CheckoutResolutionOfferDownload>());
      final download = result as CheckoutResolutionOfferDownload;
      expect(download.checkoutId, "hash_3");
    });

    test("returns Approximate when checkout is not in index and remote fails", () async {
      final result = await resolver.resolveAsync(makeRef("unknown_hash"), channel: Channel.stable);
      expect(result, isA<CheckoutResolutionApproximate>());
      final approx = result as CheckoutResolutionApproximate;
      expect(approx.checkoutId, "unknown_hash");
    });
  });

  group("CheckoutResolver.checkActiveCompatibility", () {
    test("returns incompatible when no active record exists", () {
      final ref = makeRef("hash_1");
      final check = resolver.checkActiveCompatibility(ref);
      expect(check.result, CompatibilityResult.incompatible);
    });

    test("returns compatible when serverId and checkoutId match", () async {
      await activeService.writeActive(
        const Active(
          schemaVersion: 2,
          checkoutId: "hash_1",
          activatedAt: "2024-01-15T10:30:00Z",
          serverId: "serenity",
          metadata: meta,
        ),
      );

      final ref = makeRef("hash_1");
      final check = resolver.checkActiveCompatibility(ref);
      expect(check.result, CompatibilityResult.compatible);
    });

    test("returns outdated when serverId matches but checkoutId differs", () async {
      await activeService.writeActive(
        const Active(
          schemaVersion: 2,
          checkoutId: "hash_2",
          activatedAt: "2024-01-15T10:30:00Z",
          serverId: "serenity",
          metadata: meta,
        ),
      );

      final ref = makeRef("hash_1");
      final check = resolver.checkActiveCompatibility(ref);
      expect(check.result, CompatibilityResult.outdated);
    });

    test("returns incompatible when serverId mismatches", () async {
      await activeService.writeActive(
        const Active(
          schemaVersion: 2,
          checkoutId: "hash_1",
          activatedAt: "2024-01-15T10:30:00Z",
          serverId: "tranquility",
          metadata: meta,
        ),
      );

      final ref = makeRef("hash_1");
      final check = resolver.checkActiveCompatibility(ref);
      expect(check.result, CompatibilityResult.incompatible);
    });
  });
}
