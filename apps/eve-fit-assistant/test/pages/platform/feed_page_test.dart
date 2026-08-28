@TestOn("vm")
library;

import "dart:convert";
import "dart:typed_data";

import "package:dio/dio.dart";
import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/pages/platform/feed_page.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
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

ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ["application/json"],
  },
);

Map<String, Object?> _postSummaryJson(String postId, String fitName) => {
  "postId": postId,
  "authorId": "u-1",
  "authorDeleted": false,
  "fitHash": "abc123",
  "fitName": fitName,
  "description": "A description",
  "shipName": "Heron",
  "shipTypeId": 605,
  "createdAt": "2026-08-19T00:00:00.000Z",
  "lastModifiedMs": 1755550000000,
  "generator": null,
};

PlatformSession _sessionWith(List<Map<String, Object?>> posts) => PlatformSession(
  origin: "https://test.invalid",
  store: _MemoryStore(),
  dioFactory: () => Dio(BaseOptions())
    ..httpClientAdapter = _FakeAdapter(
      (options) async => _json({"posts": posts, "nextCursor": null}),
    ),
);

Widget _harness(PlatformSession session) => ProviderScope(
  overrides: [
    platformSessionProvider.overrideWith((ref) async => session),
    localeProvider.overrideWithValue(Locale.zh),
  ],
  child: testApp(const PlatformFeedPage()),
);

void main() {
  testWidgets("renders the feed cards", (tester) async {
    await tester.pumpWidget(
      _harness(_sessionWith([_postSummaryJson("p-1", "苍鹭级侦察配置")])),
    );
    await tester.pumpAndSettle();

    expect(find.text("平台社区"), findsWidgets);
    expect(find.text("苍鹭级侦察配置"), findsOneWidget);
    expect(find.text("Heron"), findsOneWidget);
  });

  testWidgets("shows the empty state when the feed has no posts", (tester) async {
    await tester.pumpWidget(_harness(_sessionWith(const [])));
    await tester.pumpAndSettle();

    expect(find.text("暂无分享的配置"), findsOneWidget);
  });
}
