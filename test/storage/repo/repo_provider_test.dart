import "dart:io";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/storage/repo/models/active.dart";
import "package:eve_fit_assistant/storage/repo/models/branch.dart";
import "package:eve_fit_assistant/storage/repo/models/shared.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/service.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
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

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_repo_prov_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.tempPath = p.join(tempDir, "tmp");
    Directory(p.join(tempDir, "tmp")).createSync(recursive: true);
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("repoServiceProvider", () {
    test("provides a non-null RepoService", () {
      final container = createContainer();
      addTearDown(container.dispose);

      final service = container.read(repoServiceProvider);
      expect(service, isNotNull);
      expect(service, isA<RepoService>());
    });

    test("sub-service providers are accessible from the container", () {
      final container = createContainer();
      addTearDown(container.dispose);

      expect(container.read(activeServiceProvider), isNotNull);
      expect(container.read(assetStoreProvider), isNotNull);
      expect(container.read(diffEngineProvider), isNotNull);
      expect(container.read(checkoutServiceProvider), isNotNull);
      expect(container.read(branchServiceProvider), isNotNull);
      expect(container.read(checkoutResolverProvider), isNotNull);
      expect(container.read(verificationServiceProvider), isNotNull);
      expect(container.read(remoteCatalogServiceProvider), isNotNull);
    });

    test("RepoService delegates to its sub-services correctly", () {
      final container = createContainer();
      addTearDown(container.dispose);

      final service = container.read(repoServiceProvider);

      expect(service.activeService, same(container.read(activeServiceProvider)));
      expect(service.assetStore, same(container.read(assetStoreProvider)));
      expect(service.diffEngine, same(container.read(diffEngineProvider)));
      expect(service.checkoutService, same(container.read(checkoutServiceProvider)));
      expect(service.branchService, same(container.read(branchServiceProvider)));
      expect(service.checkoutResolver, same(container.read(checkoutResolverProvider)));
      expect(service.verificationService, same(container.read(verificationServiceProvider)));
      expect(service.remoteCatalogService, same(container.read(remoteCatalogServiceProvider)));
    });
  });

  group("activeCheckoutProvider", () {
    test("returns None when active.json does not exist", () {
      final container = createContainer();
      addTearDown(container.dispose);

      final result = container.read(activeCheckoutProvider);
      expect(result, const None());
    });

    test("returns Active from active.json when it exists", () async {
      final container = createContainer();
      addTearDown(container.dispose);

      final active = Active(
        schemaVersion: 2,
        branchId: "550e8400-e29b-41d4-a716-446655440000",
        checkoutId: "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef",
        activatedAt: "2024-01-15T10:30:00Z",
        serverId: "serenity",
        metadata: meta,
      );

      final activeService = container.read(activeServiceProvider);
      await activeService.writeActive(active);

      final result = container.read(activeCheckoutProvider);
      expect(result.isSome(), isTrue);
      expect(result.toNullable(), active);
    });
  });

  group("branchesProvider", () {
    test("returns empty list when no branches exist", () {
      final container = createContainer();
      addTearDown(container.dispose);

      final result = container.read(branchesProvider);
      expect(result, const IList<Branch>.empty());
    });

    test("returns discovered branches", () {
      final container = createContainer();
      addTearDown(container.dispose);

      final branch = Branch(
        schemaVersion: 1,
        id: "550e8400-e29b-41d4-a716-446655440000",
        checkout: "checkout_hash_1",
        serverId: "serenity",
        metadata: meta,
        source: BranchSource(channel: "stable"),
        name: IMap({"en": "Test Branch"}),
      );

      final branchService = container.read(branchServiceProvider);
      branchService.createBranch(branch);

      final result = container.read(branchesProvider);
      expect(result.length, 1);
      expect(result.first.id, "550e8400-e29b-41d4-a716-446655440000");
    });
  });

  group("remoteContentOriginUrlProvider", () {
    test("returns originUrl from app settings", () {
      final container = createContainer();
      addTearDown(container.dispose);

      final url = container.read(remoteContentOriginUrlProvider);
      expect(url, "https://example.com");
    });
  });
}
