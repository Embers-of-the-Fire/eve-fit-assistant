@TestOn("vm")
library;

import "dart:convert";
import "dart:io";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:efa_fit/efa_fit.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:efa_proto/fit_snapshot.pb.dart";
import "package:eve_fit_assistant/components/icon/efa_icon_resolver.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/features/fit_link/importer.dart";
import "package:eve_fit_assistant/features/fit_link/providers.dart";
import "package:eve_fit_assistant/pages/platform/post_page.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fixnum/fixnum.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "../../test_helpers.dart";

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._onFetch);

  final Future<ResponseBody> Function(RequestOptions options) _onFetch;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => _onFetch(options);

  @override
  void close({bool force = false}) {}
}

class _MemoryStore implements PlatformSessionStore {
  @override
  Future<StoredPlatformSession?> read() async => null;

  @override
  Future<void> write(StoredPlatformSession session) async {}

  @override
  Future<void> clear() async {}
}

/// An importer whose registered-fit import always misses, so the open-in-app
/// failure path can be exercised without storage or a router.
class _MissingFitImporter extends FitLinkImporter {
  const _MissingFitImporter(super.ref);

  @override
  Future<FitMetadata> importRegistered(String fitHash) =>
      throw FitLinkNotFoundException(buildFitLinkRegisteredAppUri(fitHash));
}

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ["application/json"],
  },
);

/// Serves the post record, its snapshot, and one comment for post "p-1".
PlatformSession _session() => PlatformSession(
  origin: "https://test.invalid",
  store: _MemoryStore(),
  dioFactory: () => Dio(BaseOptions())
    ..httpClientAdapter = _FakeAdapter((options) async {
      final path = Uri.parse(options.path).path;
      if (path == "/platform/internal/posts/p-1/comments") {
        return _json({
          "comments": [
            {
              "commentId": "c-1",
              "authorId": "u-1",
              "authorDeleted": false,
              "body": "不错的配置",
              "createdAt": "2026-08-19T00:00:00.000Z",
            },
          ],
          "nextCursor": null,
        });
      }
      if (path == "/platform/internal/posts/p-1/snapshot") {
        return ResponseBody.fromBytes(
          FitSnapshot(
            version: 1,
            header: SnapshotHeader(fitName: "测试配置", lastModifiedMs: Int64(1)),
          ).writeToBuffer(),
          200,
          headers: {
            Headers.contentTypeHeader: ["application/x-protobuf"],
          },
        );
      }
      if (path == "/platform/internal/posts/p-1") {
        return _json({
          "postId": "p-1",
          "authorId": "u-1",
          "authorDeleted": false,
          "fitHash": "abc123",
          "createdAt": "2026-08-19T00:00:00.000Z",
          "commentCount": 1,
        });
      }
      throw StateError("unexpected request: ${options.method} ${options.path}");
    }),
);

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_post_page_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  testWidgets("renders the snapshot, the comments, and the sign-in prompt when signed out", (
    tester,
  ) async {
    // The comment section sits below the snapshot view; use a tall surface
    // so the ListView builds it.
    tester.view.physicalSize = const Size(1400, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformSessionProvider.overrideWith((ref) async => _session()),
          localeProvider.overrideWithValue(Locale.zh),
          appEfaIconResolverProvider.overrideWith((ref) => const AppEfaIconResolver(null, null)),
        ],
        child: testApp(const PlatformPostPage(postId: "p-1")),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining("测试配置"), findsOneWidget);
    expect(find.text("在应用中打开"), findsOneWidget);
    expect(find.text("评论（1）"), findsOneWidget);
    expect(find.text("不错的配置"), findsOneWidget);
    expect(find.text("登录后即可参与讨论"), findsOneWidget);
  });

  testWidgets("open-in-app shows an error snackbar when the registered fit is missing", (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          platformSessionProvider.overrideWith((ref) async => _session()),
          localeProvider.overrideWithValue(Locale.zh),
          appEfaIconResolverProvider.overrideWith((ref) => const AppEfaIconResolver(null, null)),
          fitLinkImporterProvider.overrideWith(_MissingFitImporter.new),
        ],
        child: testApp(const PlatformPostPage(postId: "p-1")),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text("在应用中打开"));
    await tester.pumpAndSettle();

    expect(find.text("无法导入该配置。"), findsOneWidget);
  });
}
