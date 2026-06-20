import "dart:async";
import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/pages/setting/data/checkout_management.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/channel_service.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_registry.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

import "../../../test_helpers.dart";

class MockAssetStore extends Mock implements AssetStore {}

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

CheckoutRegistry _testRegistry({String activeId = "checkout-1", int count = 1}) {
  final checkouts = IMap<String, CheckoutRegistryEntry>({
    for (var i = 1; i <= count; i++)
      "checkout-$i": CheckoutRegistryEntry(
        channel: "testing",
        serverId: "tq",
        resourceSnapshotHash: "hash${i}abc123",
        name: IMap(const {"zh": "测试服务器", "en": "Test Server"}),
        createdAt: "2025-01-01T00:00:00Z",
      ),
  });
  return CheckoutRegistry(schemaVersion: 1, activeCheckoutId: activeId, checkouts: checkouts);
}

void _seedRegistry(CheckoutRegistry registry) {
  final file = File(RepoPaths.checkoutRegistryPath);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(registry.toJson()));
}

void main() {
  late MockAssetStore mockAssetStore;
  late MockChannelService mockChannelService;
  late Directory tempDir;

  setUp(() {
    registerFallbackValue("");
    tempDir = Directory.systemTemp.createTempSync("efa_checkout_mgmt_test_");
    PathProvider.documentsPath = tempDir.path;

    mockAssetStore = MockAssetStore();
    when(() => mockAssetStore.readResourceIndexSync(any())).thenReturn(const None());

    mockChannelService = MockChannelService();
    when(() => mockChannelService.readGenerationResources(any())).thenReturn(const None());
    when(() => mockChannelService.readServerIndex(any())).thenReturn(const None());
    when(() => mockChannelService.localGenerationHash(any())).thenReturn(null);
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // best-effort cleanup
    }
  });

  testWidgets("shows empty state when no checkouts", (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          assetStoreProvider.overrideWith((_) => mockAssetStore),
          activeCheckoutWatchProvider.overrideWith((_) => const Stream<CheckoutRegistry>.empty()),
        ],
        child: testApp(const CheckoutManagementPage()),
      ),
    );

    expect(find.text("尚未安装数据版本"), findsOneWidget);
    expect(find.text("创建数据版本"), findsOneWidget);
  });

  testWidgets("shows checkout list with active badge", (tester) async {
    final registry = _testRegistry();
    _seedRegistry(registry);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          assetStoreProvider.overrideWith((_) => mockAssetStore),
          activeCheckoutWatchProvider.overrideWith((_) => Stream.value(registry)),
        ],
        child: testApp(const CheckoutManagementPage()),
      ),
    );
    await tester.pump();

    expect(find.text("当前"), findsOneWidget);
    expect(find.text("测试服务器"), findsOneWidget);
    expect(find.textContaining("hash1abc123"), findsOneWidget);
  });

  testWidgets("shows activate button for inactive checkout", (tester) async {
    final registry = _testRegistry(activeId: "checkout-2", count: 2);
    _seedRegistry(registry);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          assetStoreProvider.overrideWith((_) => mockAssetStore),
          activeCheckoutWatchProvider.overrideWith((_) => Stream.value(registry)),
        ],
        child: testApp(const CheckoutManagementPage()),
      ),
    );
    await tester.pump();

    expect(find.text("激活"), findsOneWidget);
  });

  testWidgets("disables delete for single active checkout", (tester) async {
    final registry = _testRegistry();
    _seedRegistry(registry);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          assetStoreProvider.overrideWith((_) => mockAssetStore),
          activeCheckoutWatchProvider.overrideWith((_) => Stream.value(registry)),
        ],
        child: testApp(const CheckoutManagementPage()),
      ),
    );
    await tester.pump();

    expect(find.text("删除"), findsOneWidget);
  });

  testWidgets("create checkout button opens bottom sheet", (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          assetStoreProvider.overrideWith((_) => mockAssetStore),
          channelServiceProvider.overrideWith((_) => mockChannelService),
          activeCheckoutWatchProvider.overrideWith((_) => const Stream<CheckoutRegistry>.empty()),
        ],
        child: testApp(const CheckoutManagementPage()),
      ),
    );

    await tester.tap(find.text("创建数据版本"));
    await tester.pumpAndSettle();

    expect(find.text("创建数据版本"), findsWidgets);
  });

  testWidgets("shows N/A for file info when asset store returns None", (tester) async {
    final registry = _testRegistry();
    _seedRegistry(registry);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          assetStoreProvider.overrideWith((_) => mockAssetStore),
          activeCheckoutWatchProvider.overrideWith((_) => Stream.value(registry)),
        ],
        child: testApp(const CheckoutManagementPage()),
      ),
    );
    await tester.pump();

    expect(find.text("N/A"), findsOneWidget);
  });

  testWidgets("shows multiple checkout cards with correct badges", (tester) async {
    final registry = _testRegistry(count: 3);
    _seedRegistry(registry);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          assetStoreProvider.overrideWith((_) => mockAssetStore),
          activeCheckoutWatchProvider.overrideWith((_) => Stream.value(registry)),
        ],
        child: testApp(const CheckoutManagementPage()),
      ),
    );
    await tester.pump();

    expect(find.text("测试服务器"), findsNWidgets(3));
    expect(find.text("当前"), findsOneWidget);
    expect(find.text("未激活"), findsNWidgets(2));
  });

  testWidgets("shows activate confirmation dialog", (tester) async {
    final registry = _testRegistry(activeId: "checkout-2", count: 2);
    _seedRegistry(registry);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          assetStoreProvider.overrideWith((_) => mockAssetStore),
          activeCheckoutWatchProvider.overrideWith((_) => Stream.value(registry)),
        ],
        child: testApp(const CheckoutManagementPage()),
      ),
    );
    await tester.pump();

    // Tap activate on the inactive checkout
    await tester.tap(find.text("激活"));
    await tester.pumpAndSettle();

    expect(find.text("激活数据版本"), findsOneWidget);

    // Dismiss via cancel
    await tester.tap(find.text("取消"));
    await tester.pumpAndSettle();

    expect(find.text("激活数据版本"), findsNothing);
  });

  testWidgets("shows delete confirmation dialog", (tester) async {
    final registry = _testRegistry(activeId: "checkout-2", count: 2);
    _seedRegistry(registry);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appSettingServiceProvider.overrideWithValue(_testAppSetting()),
          assetStoreProvider.overrideWith((_) => mockAssetStore),
          activeCheckoutWatchProvider.overrideWith((_) => Stream.value(registry)),
        ],
        child: testApp(const CheckoutManagementPage()),
      ),
    );
    await tester.pump();

    // Tap delete on the first (inactive) checkout
    await tester.tap(find.text("删除").first);
    await tester.pumpAndSettle();

    expect(find.text("删除数据版本"), findsOneWidget);

    // Dismiss via cancel
    await tester.tap(find.text("取消"));
    await tester.pumpAndSettle();

    expect(find.text("删除数据版本"), findsNothing);
  });
}
