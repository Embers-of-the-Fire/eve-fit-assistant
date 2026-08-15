import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/proto/generation_pointer.pb.dart";
import "package:eve_fit_assistant/data/proto/generation_resources.pb.dart";
import "package:eve_fit_assistant/data/proto/server_index.pb.dart";
import "package:eve_fit_assistant/pages/setting/data/channel_metadata.dart";
import "package:eve_fit_assistant/storage/repo/channel_service.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_head_meta.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_registry.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

import "../../../test_helpers.dart";

class MockChannelService extends Mock implements ChannelService {}

AppSetting _testAppSetting({RemoteContentSetting? remoteContent}) => AppSetting(
  locale: Locale.zh,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
  remoteContent: remoteContent ?? const RemoteContentSetting(exposed: true),
);

void main() {
  late MockChannelService mockChannelService;

  setUp(() {
    registerFallbackValue("");
    mockChannelService = MockChannelService();

    when(() => mockChannelService.readLocalChannelRegistry()).thenAnswer((_) async => 
      Some(
        ChannelRegistry(
          schemaVersion: 1,
          active: "testing",
          channels: IMap(const {"testing": ChannelEntry(), "stable": ChannelEntry()}),
        ),
      ),
    );
    when(() => mockChannelService.readHeadMeta(any())).thenAnswer((_) async => const None());
    when(() => mockChannelService.readServerIndex(any())).thenAnswer((_) async => const None());
    when(() => mockChannelService.readGenerationResources(any())).thenAnswer((_) async => const None());
    when(() => mockChannelService.readReleasePointer(any())).thenAnswer((_) async => const None());
  });

  testWidgets("shows no data placeholder when registry is null", (tester) async {
    when(() => mockChannelService.readLocalChannelRegistry()).thenAnswer((_) async => const None());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelServiceProvider.overrideWith((_) => mockChannelService),
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
        ],
        child: testApp(const ChannelMetadataPage()),
      ),
    );

    await tester.pump();

    expect(find.text("无频道数据 — 尚未同步。"), findsOneWidget);
    expect(find.text("频道元数据"), findsOneWidget);
  });

  testWidgets("shows overview tab with channel info", (tester) async {
    when(() => mockChannelService.readHeadMeta(any())).thenAnswer((_) async => 
      Some(
        ChannelHeadMeta(
          schemaVersion: 1,
          generationHash: "abc123def456789",
          label: IMap(const {"zh": "测试频道", "en": "Testing Channel"}),
          updatedAt: "2025-01-01T00:00:00Z",
        ),
      ),
    );
    when(() => mockChannelService.readServerIndex(any())).thenAnswer((_) async => const None());
    when(() => mockChannelService.readGenerationResources(any())).thenAnswer((_) async => const None());
    when(() => mockChannelService.readReleasePointer(any())).thenAnswer((_) async => const None());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelServiceProvider.overrideWith((_) => mockChannelService),
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
        ],
        child: testApp(const ChannelMetadataPage()),
      ),
    );

    await tester.pump();

    expect(find.text("abc123def456..."), findsOneWidget);
    expect(find.text("testing"), findsWidgets);
  });

  testWidgets("shows server tab with server list", (tester) async {
    final serverIndex = ServerIndex(schemaVersion: 1);
    serverIndex.servers.add(
      ServerIndex_Entry(
        serverId: "tq",
        name: [const MapEntry("zh", "宁静"), const MapEntry("en", "Tranquility")],
        gameBuild: "22.01",
        gameVersion: "V22.01",
      ),
    );

    when(() => mockChannelService.readHeadMeta(any())).thenAnswer((_) async => const None());
    when(() => mockChannelService.readServerIndex(any())).thenAnswer((_) async => Some(serverIndex));
    when(() => mockChannelService.readGenerationResources(any())).thenAnswer((_) async => const None());
    when(() => mockChannelService.readReleasePointer(any())).thenAnswer((_) async => const None());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelServiceProvider.overrideWith((_) => mockChannelService),
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
        ],
        child: testApp(const ChannelMetadataPage()),
      ),
    );

    await tester.pump();

    await tester.tap(find.text("服务器"));
    await tester.pumpAndSettle();

    expect(find.textContaining("tq"), findsOneWidget);
    expect(find.textContaining("1 个服务器"), findsOneWidget);
  });

  testWidgets("shows resources tab with entries", (tester) async {
    final genResources = GenerationResources(schemaVersion: 1);
    genResources.entries.addAll([
      GenerationResources_Entry(serverId: "tq", snapshotHash: "hash123"),
      GenerationResources_Entry(serverId: "ser", snapshotHash: "hash456"),
    ]);

    when(() => mockChannelService.readHeadMeta(any())).thenAnswer((_) async => const None());
    when(() => mockChannelService.readServerIndex(any())).thenAnswer((_) async => const None());
    when(() => mockChannelService.readGenerationResources(any())).thenAnswer((_) async => Some(genResources));
    when(() => mockChannelService.readReleasePointer(any())).thenAnswer((_) async => const None());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelServiceProvider.overrideWith((_) => mockChannelService),
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
        ],
        child: testApp(const ChannelMetadataPage()),
      ),
    );

    await tester.pump();

    await tester.tap(find.text("资源"));
    await tester.pumpAndSettle();

    expect(find.textContaining("hash123"), findsOneWidget);
    expect(find.textContaining("hash456"), findsOneWidget);
    expect(find.textContaining("共 2 条记录"), findsOneWidget);
  });

  testWidgets("shows not synced message on overview tab when headMeta is null", (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelServiceProvider.overrideWith((_) => mockChannelService),
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
        ],
        child: testApp(const ChannelMetadataPage()),
      ),
    );

    await tester.pump();

    expect(find.text("未同步"), findsOneWidget);
  });

  testWidgets("shows releases tab no data state when pointer is null", (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelServiceProvider.overrideWith((_) => mockChannelService),
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
        ],
        child: testApp(const ChannelMetadataPage()),
      ),
    );

    await tester.pump();

    await tester.tap(find.text("版本"));
    await tester.pumpAndSettle();

    expect(find.text("无版本数据 — 尚未同步。"), findsOneWidget);
  });

  testWidgets("shows releases tab empty state when pointer hash is empty", (tester) async {
    when(
      () => mockChannelService.readReleasePointer(any()),
    ).thenAnswer((_) async => Some(GenerationPointer(schemaVersion: 1, snapshotHash: "")));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelServiceProvider.overrideWith((_) => mockChannelService),
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
        ],
        child: testApp(const ChannelMetadataPage()),
      ),
    );

    await tester.pump();

    await tester.tap(find.text("版本"));
    await tester.pumpAndSettle();

    expect(find.text("已同步 — 此代数无版本数据。"), findsOneWidget);
  });

  testWidgets("shows channel switcher when multiple channels available", (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelServiceProvider.overrideWith((_) => mockChannelService),
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
        ],
        child: testApp(const ChannelMetadataPage()),
      ),
    );

    await tester.pump();

    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
  });

  testWidgets("switches channel via popup menu", (tester) async {
    when(() => mockChannelService.readHeadMeta(any())).thenAnswer((_) async => const None());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          channelServiceProvider.overrideWith((_) => mockChannelService),
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
        ],
        child: testApp(const ChannelMetadataPage()),
      ),
    );

    await tester.pump();

    // Open channel switcher popup
    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();

    // Select "stable" channel from the popup menu
    // PopupMenuItem renders Text(name) — we need the one inside the popup
    await tester.tap(find.text("stable").last);
    await tester.pumpAndSettle();

    // The active channel field should now show "stable"
    expect(find.text("stable"), findsWidgets);
  });
}
