@TestOn("vm")
library;

import "dart:async";
import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:efa_proto/resource_index.pb.dart";
import "package:eve_fit_assistant/features/locale_switch/locale_db_download_controller.dart";
import "package:eve_fit_assistant/features/locale_switch/locale_db_download_state.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/hash.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/remote_catalog.dart";
import "package:eve_fit_assistant/storage/repo/resource_proxy.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

class _MockRemoteCatalogService extends Mock implements RemoteCatalogService {}

class _MockAssetStore extends Mock implements AssetStore {}

final _zhDbBytes = Uint8List.fromList(List.generate(32, (i) => i));
final _zhDbHash = RepoHash.hashContent(_zhDbBytes);
final _zhDbId = localeLocalizationDbResourceId("zh");
final _legacyDbId = kLocalizationDbResourceId;

ResourceIndex_Entry _entry(String resourceId, String contentHash, {int size = 32}) =>
    ResourceIndex_Entry()
      ..resourceId = resourceId
      ..contentHash = contentHash
      ..size = Int64(size);

void main() {
  late _MockRemoteCatalogService mockCatalog;
  late _MockAssetStore mockAssetStore;
  late ProviderContainer container;

  setUpAll(() {
    registerFallbackValue((int received, int total) {});
    registerFallbackValue(Uint8List(0));
    final logDir = Directory.systemTemp.createTempSync("efa_locale_switch_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  late String tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_locale_switch_test_").path;
    PathProvider.documentsPath = tempDir;
    PathProvider.cachesPath = tempDir;
    PathProvider.appSupportPath = tempDir;
    PathProvider.tempPath = tempDir;

    mockCatalog = _MockRemoteCatalogService();
    mockAssetStore = _MockAssetStore();
  });

  tearDown(() {
    container.dispose();
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  ProviderContainer makeContainer({List<String> indexIds = const [], Set<String> present = const {}}) {
    final index = ResourceIndex()
      ..schemaVersion = 1
      ..formatVersion = 2;
    for (final id in indexIds) {
      final hash = id == _zhDbId ? _zhDbHash : RepoHash.hashContent(Uint8List.fromList(id.codeUnits));
      index.entries.add(_entry(id, hash));
    }
    final proxy = ResourceBlobProxy(mockAssetStore, index);

    when(() => mockAssetStore.blobExists(any(), any())).thenAnswer(
      (inv) async => present.contains(inv.positionalArguments.first as String),
    );

    container = ProviderContainer(
      overrides: [
        resourceBlobProxyProvider.overrideWith((ref) async => proxy),
        assetStoreProvider.overrideWithValue(mockAssetStore),
        remoteCatalogServiceProvider.overrideWithValue(mockCatalog),
      ],
    );
    return container;
  }

  group("localizationDbAvailability", () {
    test("available when the per-locale blob is on disk", () async {
      makeContainer(indexIds: [_zhDbId], present: {RepoHash.hashIdent(_zhDbId)});
      expect(
        await container.read(localizationDbAvailabilityProvider("zh").future),
        isA<LocalizationDbAvailable>(),
      );
    });

    test("downloadable with size when the per-locale blob is absent", () async {
      makeContainer(indexIds: [_zhDbId]);
      final availability = await container.read(
        localizationDbAvailabilityProvider("zh").future,
      );
      expect(availability, isA<LocalizationDbDownloadable>());
      expect((availability as LocalizationDbDownloadable).sizeBytes, 32);
    });

    test("old snapshots with the legacy combined db are available, not updateRequired", () async {
      makeContainer(indexIds: [_legacyDbId], present: {RepoHash.hashIdent(_legacyDbId)});
      expect(
        await container.read(localizationDbAvailabilityProvider("zh").future),
        isA<LocalizationDbAvailable>(),
      );
    });

    test("updateRequired when neither database is usable", () async {
      makeContainer(indexIds: [_legacyDbId]); // legacy entry present, blob absent
      expect(
        await container.read(localizationDbAvailabilityProvider("zh").future),
        isA<LocalizationDbUpdateRequired>(),
      );

      makeContainer(); // nothing in the index at all
      expect(
        await container.read(localizationDbAvailabilityProvider("zh").future),
        isA<LocalizationDbUpdateRequired>(),
      );
    });
  });

  group("LocaleDbDownloadController", () {
    test("downloadable → downloading → ready; providers invalidated", () async {
      makeContainer(indexIds: [_zhDbId]);
      when(
        () => mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      ).thenAnswer((inv) async {
        final onProgress =
            inv.namedArguments[#onReceiveProgress] as void Function(int, int)?;
        onProgress?.call(16, 32);
        return Right(_zhDbBytes);
      });
      when(() => mockAssetStore.writeBlobUncheckedAt(any(), any())).thenAnswer((_) async {});

      final states = <LocaleDbDownloadState>[];
      final sub = container.listen(
        localeDbDownloadControllerProvider("zh"),
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      addTearDown(sub.close);

      await container.read(localeDbDownloadControllerProvider("zh").notifier).download();

      expect(container.read(localeDbDownloadControllerProvider("zh")), isA<LocaleDbDownloadReady>());
      expect(states, contains(isA<LocaleDbDownloading>()));
      verify(
        () => mockCatalog.fetchBlob(
          RepoHash.hashIdent(_zhDbId),
          _zhDbHash,
          onReceiveProgress: any(named: "onReceiveProgress"),
        ),
      ).called(1);
      verify(() => mockAssetStore.writeBlobUncheckedAt(any(), any())).called(1);

      // Availability re-derives through the invalidation and still sees the
      // mocked-absent blob → downloadable again (the write is mocked away).
      expect(
        await container.read(localizationDbAvailabilityProvider("zh").future),
        isA<LocalizationDbDownloadable>(),
      );
    });

    test("network failure → failed(network) → retry succeeds", () async {
      makeContainer(indexIds: [_zhDbId]);
      var attempt = 0;
      when(
        () => mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      ).thenAnswer((_) async {
        attempt++;
        return attempt == 1
            ? const Left(CatalogNetworkError(message: "boom"))
            : Right(_zhDbBytes);
      });
      when(() => mockAssetStore.writeBlobUncheckedAt(any(), any())).thenAnswer((_) async {});

      final controller = container.read(localeDbDownloadControllerProvider("zh").notifier);

      await controller.download();
      final first = container.read(localeDbDownloadControllerProvider("zh"));
      expect(first, isA<LocaleDbDownloadFailed>());
      expect((first as LocaleDbDownloadFailed).reason, LocaleDbDownloadFailureReason.network);

      await controller.download();
      final second = container.read(localeDbDownloadControllerProvider("zh"));
      expect(second, isA<LocaleDbDownloadReady>());
    });

    test("content hash mismatch → failed(integrity)", () async {
      makeContainer(indexIds: [_zhDbId]);
      when(
        () => mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      ).thenAnswer((_) async => Right(Uint8List.fromList([1, 2, 3])));

      await container.read(localeDbDownloadControllerProvider("zh").notifier).download();

      final state = container.read(localeDbDownloadControllerProvider("zh"));
      expect(state, isA<LocaleDbDownloadFailed>());
      expect((state as LocaleDbDownloadFailed).reason, LocaleDbDownloadFailureReason.integrity);
      verifyNever(() => mockAssetStore.writeBlobUncheckedAt(any(), any()));
    });

    test("entry absent from the index → failed(unknown)", () async {
      makeContainer(); // no per-locale entry

      await container.read(localeDbDownloadControllerProvider("zh").notifier).download();

      expect(
        container.read(localeDbDownloadControllerProvider("zh")),
        isA<LocaleDbDownloadFailed>(),
      );
      verifyNever(
        () => mockCatalog.fetchBlob(any(), any(), onReceiveProgress: any(named: "onReceiveProgress")),
      );
    });
  });
}
