@TestOn("vm")
library;

import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/proto/resource_index.pb.dart";
import "package:eve_fit_assistant/features/ai_gate/ai_gate_controller.dart";
import "package:eve_fit_assistant/features/ai_gate/ai_gate_state.dart";
import "package:eve_fit_assistant/storage/repo/agent_resource_db.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

class _MockRemoteCatalogService extends Mock implements RemoteCatalogService {}

class _MockAssetStore extends Mock implements AssetStore {}

final _checkoutIdProvider = NotifierProvider<_CheckoutId, String?>(_CheckoutId.new);

class _CheckoutId extends Notifier<String?> {
  @override
  String? build() => "checkout-a";

  void set(String? value) => state = value;
}

CheckoutRegistryEntry _entry(String checkoutId) => CheckoutRegistryEntry(
  channel: "tranquility",
  serverId: "server-$checkoutId",
  resourceSnapshotHash: "snapshot-$checkoutId",
  createdAt: "2026-01-01T00:00:00Z",
);

AppSetting _setting() => const AppSetting(
  locale: Locale.en,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
  aiAssistantEnabled: true,
  aiAssistantDisclaimerAcked: true,
);

void main() {
  late _MockRemoteCatalogService mockCatalog;
  late _MockAssetStore mockAssetStore;
  late ProviderContainer container;
  late bool blobWritten;

  final blobBytes = Uint8List.fromList(List.generate(64, (i) => i));
  final blobHash = RepoHash.hashContent(blobBytes);

  setUpAll(() {
    registerFallbackValue((int received, int total) {});
    registerFallbackValue(Uint8List(0));
    final logDir = Directory.systemTemp.createTempSync("efa_ai_gate_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  late String tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_ai_gate_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.cachesPath = tempDir;
    PathProvider.appSupportPath = tempDir;
    PathProvider.tempPath = tempDir;

    mockCatalog = _MockRemoteCatalogService();
    mockAssetStore = _MockAssetStore();
    blobWritten = false;

    final proxy = ResourceBlobProxy(
      mockAssetStore,
      ResourceIndex(
        schemaVersion: 1,
        entries: [
          ResourceIndex_Entry(resourceId: kAgentResourceDbResourceId, contentHash: blobHash),
        ],
      ),
    );

    container = ProviderContainer(
      overrides: [
        appSettingServiceProvider.overrideWithValue(_setting()),
        activeCheckoutProvider.overrideWith(
          (ref) => switch (ref.watch(_checkoutIdProvider)) {
            final id? => Some(_entry(id)),
            null => const None(),
          },
        ),
        activeCheckoutIdProvider.overrideWith(
          (ref) => Option.fromNullable(ref.watch(_checkoutIdProvider)),
        ),
        resourceBlobProxyProvider.overrideWith((ref) async => proxy),
        agentDbAvailabilityProvider.overrideWith(
          // Availability is per-checkout: the fetched blob belongs to the
          // checkout that started the download ("checkout-a").
          (ref) async => blobWritten && ref.watch(_checkoutIdProvider) == "checkout-a"
              ? AgentDbAvailability.available
              : AgentDbAvailability.downloadable,
        ),
        remoteCatalogServiceProvider.overrideWithValue(mockCatalog),
        assetStoreProvider.overrideWithValue(mockAssetStore),
      ],
    );

    when(() => mockAssetStore.writeBlobUncheckedAt(any(), any())).thenAnswer((_) async {
      blobWritten = true;
    });
  });

  tearDown(() {
    container.dispose();
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("AiGateController.downloadAgentDb", () {
    test("checkout switch during download re-derives state instead of opening the gate", () async {
      final completer = Completer<Either<CatalogError, Uint8List>>();
      when(
        () =>
            mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      ).thenAnswer((_) => completer.future);

      final states = <AiGateState>[];
      final sub = container.listen(
        aiGateControllerProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);

      // Let the initial availability resolution settle.
      await container.read(agentDbAvailabilityProvider.future);
      await pumpEventQueue();
      expect(container.read(aiGateControllerProvider), isA<AiGateDataRequiredDownload>());

      final download = container.read(aiGateControllerProvider.notifier).downloadAgentDb();
      await pumpEventQueue();
      expect(container.read(aiGateControllerProvider), isA<AiGateDownloading>());

      // Switch the active checkout while fetchBlob is still awaiting.
      container.read(_checkoutIdProvider.notifier).set("checkout-b");
      await pumpEventQueue();

      // The in-flight download owns the state while it runs.
      expect(container.read(aiGateControllerProvider), isA<AiGateDownloading>());

      completer.complete(Right(blobBytes));
      await download;
      await container.read(agentDbAvailabilityProvider.future);
      await pumpEventQueue();

      final state = container.read(aiGateControllerProvider);
      expect(state, isNot(isA<AiGateReady>()));
      expect(state, isA<AiGateDataRequiredDownload>());
      expect(states.whereType<AiGateReady>(), isEmpty);
    });

    test("checkout switch before a failed fetch re-derives state instead of failing", () async {
      final completer = Completer<Either<CatalogError, Uint8List>>();
      when(
        () =>
            mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      ).thenAnswer((_) => completer.future);

      final states = <AiGateState>[];
      final sub = container.listen(
        aiGateControllerProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(agentDbAvailabilityProvider.future);
      await pumpEventQueue();
      expect(container.read(aiGateControllerProvider), isA<AiGateDataRequiredDownload>());

      final download = container.read(aiGateControllerProvider.notifier).downloadAgentDb();
      await pumpEventQueue();
      expect(container.read(aiGateControllerProvider), isA<AiGateDownloading>());

      // Switch the active checkout while fetchBlob is still awaiting.
      container.read(_checkoutIdProvider.notifier).set("checkout-b");
      await pumpEventQueue();

      completer.complete(const Left(CatalogNetworkError(message: "boom")));
      await download;
      await pumpEventQueue();

      final state = container.read(aiGateControllerProvider);
      expect(state, isNot(isA<AiGateDownloadFailed>()));
      expect(state, isA<AiGateDataRequiredDownload>());
      expect(states.whereType<AiGateDownloadFailed>(), isEmpty);
    });

    test("download completion without a checkout switch opens the gate", () async {
      when(
        () =>
            mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      ).thenAnswer((_) async => Right(blobBytes));

      await container.read(agentDbAvailabilityProvider.future);
      await pumpEventQueue();

      await container.read(aiGateControllerProvider.notifier).downloadAgentDb();
      await container.read(agentDbAvailabilityProvider.future);
      await pumpEventQueue();

      expect(container.read(aiGateControllerProvider), isA<AiGateReady>());
    });
  });
}
