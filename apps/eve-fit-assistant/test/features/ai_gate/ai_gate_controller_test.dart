@TestOn("vm")
library;

import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:efa_proto/resource_index.pb.dart";
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

final _blobWrittenProvider = NotifierProvider<_BlobWritten, bool>(_BlobWritten.new);

class _BlobWritten extends Notifier<bool> {
  @override
  bool build() => false;

  void markWritten() => state = true;
}

class _TestAppSettingService extends AppSettingService {
  _TestAppSettingService(this._initial);

  final AppSetting _initial;

  @override
  AppSetting build() => _initial;

  @override
  void update(AppSetting Function(AppSetting) updater) => state = updater(state);
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
        appSettingServiceProvider.overrideWith(() => _TestAppSettingService(_setting())),
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
          // checkout that started the download ("checkout-a"). The blob flag
          // lives in a notifier so flipping it re-derives availability through
          // Riverpod's dependency tracking instead of a hidden invalidation.
          (ref) async =>
              ref.watch(_blobWrittenProvider) && ref.watch(_checkoutIdProvider) == "checkout-a"
              ? AgentDbAvailability.available
              : AgentDbAvailability.downloadable,
        ),
        remoteCatalogServiceProvider.overrideWithValue(mockCatalog),
        assetStoreProvider.overrideWithValue(mockAssetStore),
      ],
    );

    when(() => mockAssetStore.writeBlobUncheckedAt(any(), any())).thenAnswer((_) async {
      container.read(_blobWrittenProvider.notifier).markWritten();
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

  group("AiGateController.acknowledgeDisclaimer", () {
    test("moves the gate past the disclaimer once acknowledged", () async {
      final sub = container.listen(aiGateControllerProvider, (_, _) {}, fireImmediately: true);
      addTearDown(sub.close);

      container
          .read(appSettingServiceProvider.notifier)
          .update((s) => s.copyWith(aiAssistantDisclaimerAcked: false));
      await pumpEventQueue();
      expect(container.read(aiGateControllerProvider), isA<AiGateDisclaimer>());

      container.read(aiGateControllerProvider.notifier).acknowledgeDisclaimer();
      await container.read(agentDbAvailabilityProvider.future);
      await pumpEventQueue();

      expect(container.read(aiGateControllerProvider), isA<AiGateDataRequiredDownload>());
      verifyNever(
        () =>
            mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      );
    });
  });

  group("AiGateController.enableAssistant", () {
    test("enabling with a downloadable agent database downloads it and opens the gate", () async {
      when(
        () =>
            mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      ).thenAnswer((_) async => Right(blobBytes));

      final sub = container.listen(aiGateControllerProvider, (_, _) {}, fireImmediately: true);
      addTearDown(sub.close);

      container
          .read(appSettingServiceProvider.notifier)
          .update((s) => s.copyWith(aiAssistantDisclaimerAcked: false, aiAssistantEnabled: false));
      await pumpEventQueue();
      expect(container.read(aiGateControllerProvider), isA<AiGateDisclaimer>());

      await container.read(aiGateControllerProvider.notifier).enableAssistant();
      await container.read(agentDbAvailabilityProvider.future);
      await pumpEventQueue();

      expect(container.read(aiGateControllerProvider), isA<AiGateReady>());
      verify(
        () =>
            mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      ).called(1);
    });

    test("enabling without an active checkout does not fetch the agent database", () async {
      final sub = container.listen(aiGateControllerProvider, (_, _) {}, fireImmediately: true);
      addTearDown(sub.close);

      container.read(_checkoutIdProvider.notifier).set(null);
      container
          .read(appSettingServiceProvider.notifier)
          .update((s) => s.copyWith(aiAssistantDisclaimerAcked: false, aiAssistantEnabled: false));
      await pumpEventQueue();
      expect(container.read(aiGateControllerProvider), isA<AiGateDisclaimer>());

      await container.read(aiGateControllerProvider.notifier).enableAssistant();
      await pumpEventQueue();

      expect(container.read(aiGateControllerProvider), isA<AiGateDataRequiredNoCheckout>());
      verifyNever(
        () =>
            mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      );
    });
  });

  group("AiGateController.disableAssistant", () {
    test("disabling from the ready state falls back to the enable state", () async {
      final sub = container.listen(aiGateControllerProvider, (_, _) {}, fireImmediately: true);
      addTearDown(sub.close);

      container.read(_blobWrittenProvider.notifier).markWritten();
      await container.read(agentDbAvailabilityProvider.future);
      await pumpEventQueue();
      expect(container.read(aiGateControllerProvider), isA<AiGateReady>());

      container.read(aiGateControllerProvider.notifier).disableAssistant();
      await pumpEventQueue();

      expect(container.read(aiGateControllerProvider), isA<AiGateEnable>());
    });
  });

  group("AiGateController.refreshAgentDb", () {
    test("refresh without an active checkout does not fetch the agent database", () async {
      final sub = container.listen(aiGateControllerProvider, (_, _) {}, fireImmediately: true);
      addTearDown(sub.close);

      container.read(_checkoutIdProvider.notifier).set(null);
      await pumpEventQueue();
      expect(container.read(aiGateControllerProvider), isA<AiGateDataRequiredNoCheckout>());

      await container.read(aiGateControllerProvider.notifier).refreshAgentDb();
      await pumpEventQueue();

      expect(container.read(aiGateControllerProvider), isA<AiGateDataRequiredNoCheckout>());
      verifyNever(
        () =>
            mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      );
      verifyNever(() => mockAssetStore.writeBlobUncheckedAt(any(), any()));
    });

    test(
      "a concurrent refresh while a download is in flight does not start a second fetch",
      () async {
        final completer = Completer<Either<CatalogError, Uint8List>>();
        when(
          () => mockCatalog.fetchBlob(
            any(),
            any(),
            onReceiveProgress: any(named: "onReceiveProgress"),
          ),
        ).thenAnswer((_) => completer.future);

        final sub = container.listen(aiGateControllerProvider, (_, _) {}, fireImmediately: true);
        addTearDown(sub.close);

        await container.read(agentDbAvailabilityProvider.future);
        await pumpEventQueue();

        final first = container.read(aiGateControllerProvider.notifier).refreshAgentDb();
        await pumpEventQueue();
        expect(container.read(aiGateControllerProvider), isA<AiGateDownloading>());

        final second = container.read(aiGateControllerProvider.notifier).refreshAgentDb();
        await pumpEventQueue();
        expect(container.read(aiGateControllerProvider), isA<AiGateDownloading>());

        completer.complete(Right(blobBytes));
        await Future.wait([first, second]);
        await container.read(agentDbAvailabilityProvider.future);
        await pumpEventQueue();

        verify(
          () => mockCatalog.fetchBlob(
            any(),
            any(),
            onReceiveProgress: any(named: "onReceiveProgress"),
          ),
        ).called(1);
        expect(container.read(aiGateControllerProvider), isA<AiGateReady>());
      },
    );

    test("re-downloads the agent database even when it is already available", () async {
      when(
        () =>
            mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      ).thenAnswer((_) async => Right(blobBytes));

      final sub = container.listen(aiGateControllerProvider, (_, _) {}, fireImmediately: true);
      addTearDown(sub.close);

      container.read(_blobWrittenProvider.notifier).markWritten();
      await container.read(agentDbAvailabilityProvider.future);
      await pumpEventQueue();
      expect(container.read(aiGateControllerProvider), isA<AiGateReady>());

      await container.read(aiGateControllerProvider.notifier).refreshAgentDb();
      await pumpEventQueue();

      verify(
        () =>
            mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      ).called(1);
      expect(container.read(aiGateControllerProvider), isA<AiGateReady>());
    });
  });
}
