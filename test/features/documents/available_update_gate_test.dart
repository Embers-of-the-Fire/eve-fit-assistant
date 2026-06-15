import "dart:io";

import "package:dio/dio.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:eve_fit_assistant/features/documents/available_update_gate.dart";
import "package:eve_fit_assistant/features/documents/models.dart";
import "package:eve_fit_assistant/features/documents/repository.dart";
import "package:eve_fit_assistant/features/documents/remote_sync.dart";
import "package:eve_fit_assistant/features/documents/storage.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

class _FakeAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromString(
      r'{"schemaVersion":999,"channel":"mismatch"}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AppSetting _testAppSetting({bool remoteEnabled = true}) => AppSetting(
  locale: Locale.en,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  remoteContent: RemoteContentSetting(enabled: remoteEnabled),
);

DocumentRecord _versionRecord({required String id, required String appVer}) => DocumentRecord(
  id: id,
  kind: DocumentEntryKind.version,
  source: DocumentEntrySource.remote,
  title: "Version $appVer",
  summary: "Summary for $appVer",
  markdown: "# $appVer",
  publishedAt: DateTime(2025, 1, 1),
  localeCode: "en",
  appVer: appVer,
);

class _ThrowingSyncService extends RemoteDocumentSyncService {
  _ThrowingSyncService(Ref ref)
    : super(ref: ref, dio: Dio(BaseOptions())..httpClientAdapter = _FakeAdapter());

  @override
  Future<bool> sync() async => throw Exception("transient sync failure");
}

void main() {
  setUpAll(() async {
    final tempDir = await Directory.systemTemp.createTemp("efa_test_");
    PathProvider.documentsPath = tempDir.path;
    PathProvider.tempPath = tempDir.path;
    PathProvider.appSupportPath = tempDir.path;
    PathProvider.cachesPath = tempDir.path;
    GlobalLogger.init(tempDir.path, enableDebugLog: false);
    EtagCache.init();
  });

  setUp(() {
    DocumentStorage.init();
  });

  group("startupAvailableUpdateProvider", () {
    test("returns null when remote content is disabled", () async {
      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting(remoteEnabled: false)),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(startupAvailableUpdateProvider.future);
      expect(result, isNull);
    });

    test("returns null when no newer version exists", () async {
      final dio = Dio(BaseOptions())..httpClientAdapter = _FakeAdapter();
      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          remoteDocumentSyncServiceProvider.overrideWith(
            (ref) => RemoteDocumentSyncService(ref: ref, dio: dio),
          ),
          appVersionProvider.overrideWith((_) async => "1.0.0"),
          documentFeedProvider(DocumentFeedKind.version).overrideWith(
            (_) async => [
              _versionRecord(id: "v1", appVer: "1.0.0"),
              _versionRecord(id: "v0", appVer: "0.9.0"),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(startupAvailableUpdateProvider.future);
      expect(result, isNull);
    });

    test("falls back to cached data when sync throws a non-timeout exception", () async {
      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          remoteDocumentSyncServiceProvider.overrideWith((ref) => _ThrowingSyncService(ref)),
          appVersionProvider.overrideWith((_) async => "1.0.0"),
          documentFeedProvider(DocumentFeedKind.version).overrideWith(
            (_) async => [
              _versionRecord(id: "v1", appVer: "1.0.0"),
              _versionRecord(id: "v2", appVer: "2.0.0"),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(startupAvailableUpdateProvider.future);
      expect(result, isNotNull);
      expect(result!.appVer, "2.0.0");
    });

    test("returns latest newer version record when one exists", () async {
      final dio = Dio(BaseOptions())..httpClientAdapter = _FakeAdapter();
      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          remoteDocumentSyncServiceProvider.overrideWith(
            (ref) => RemoteDocumentSyncService(ref: ref, dio: dio),
          ),
          appVersionProvider.overrideWith((_) async => "1.0.0"),
          documentFeedProvider(DocumentFeedKind.version).overrideWith(
            (_) async => [
              _versionRecord(id: "v1", appVer: "1.0.0"),
              _versionRecord(id: "v2", appVer: "2.0.0"),
              _versionRecord(id: "v3", appVer: "1.5.0"),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(startupAvailableUpdateProvider.future);
      expect(result, isNotNull);
      expect(result!.appVer, "2.0.0");
    });

    test("returns null when already notified about the latest version", () async {
      final dio = Dio(BaseOptions())..httpClientAdapter = _FakeAdapter();
      DocumentStorage.setNotifiedAvailableVersion("2.0.0");
      final container = ProviderContainer(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          remoteDocumentSyncServiceProvider.overrideWith(
            (ref) => RemoteDocumentSyncService(ref: ref, dio: dio),
          ),
          appVersionProvider.overrideWith((_) async => "1.0.0"),
          documentFeedProvider(DocumentFeedKind.version).overrideWith(
            (_) async => [
              _versionRecord(id: "v1", appVer: "1.0.0"),
              _versionRecord(id: "v2", appVer: "2.0.0"),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(startupAvailableUpdateProvider.future);
      expect(result, isNull);
    });
  });

  group("AvailableUpdateGate", () {
    testWidgets("renders child widget and shows no dialog when disabled", (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appSettingServiceProvider.overrideWithValue(_testAppSetting(remoteEnabled: false)),
          ],
          child: MaterialApp(
            navigatorKey: navigatorKey,
            home: AvailableUpdateGate(
              appRouter: AppRouter(),
              navigatorKey: navigatorKey,
              child: const Scaffold(body: Center(child: Text("Hello"))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("Hello"), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });
  });
}
