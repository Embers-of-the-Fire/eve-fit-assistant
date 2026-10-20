@TestOn("vm")
library;

import "package:eve_fit_assistant/config/locale.dart" as app_locale;
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/features/remote_content/channel_switch.dart";
import "package:eve_fit_assistant/storage/repo/data_update_service.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/repo/service.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";
import "package:mocktail/mocktail.dart";

class MockRepoService extends Mock implements RepoService {}

class MockDataUpdateService extends Mock implements DataUpdateService {}

class _TestAppSettingService extends AppSettingService {
  _TestAppSettingService(this._initial);

  final AppSetting _initial;

  @override
  AppSetting build() => _initial;

  @override
  void update(AppSetting Function(AppSetting) updater) => state = updater(state);
}

class _FakeRepoStateNotifier extends RepoStateNotifier {
  int initializeCalls = 0;

  @override
  Future<void> initialize() async {
    initializeCalls++;
  }
}

AppSetting _setting({String channel = "stable"}) => AppSetting(
  locale: app_locale.Locale.en,
  enableDebugLog: false,
  shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
  showCheckoutImpactWarnings: true,
  typeListReturnBehavior: TypeListReturnBehavior.previousPage,
  developerMode: false,
  remoteContent: RemoteContentSetting(channel: channel),
);

void main() {
  late MockRepoService mockRepoService;
  late MockDataUpdateService mockUpdateService;
  late _FakeRepoStateNotifier repoStateNotifier;

  setUpAll(() {
    registerFallbackValue("");
  });

  setUp(() {
    mockRepoService = MockRepoService();
    mockUpdateService = MockDataUpdateService();
    repoStateNotifier = _FakeRepoStateNotifier();

    when(() => mockRepoService.discoverChannels()).thenAnswer((_) async => const Right(unit));
    when(
      () => mockRepoService.syncChannelGeneration(any()),
    ).thenAnswer((_) async => const Right(unit));
    when(() => mockUpdateService.rebindCheckoutsToChannel(any())).thenAnswer((_) async {});
  });

  ProviderContainer makeContainer({String channel = "stable"}) {
    final container = ProviderContainer(
      overrides: [
        repoServiceProvider.overrideWith((_) => mockRepoService),
        dataUpdateServiceProvider.overrideWith((_) => mockUpdateService),
        appSettingServiceProvider.overrideWith(
          () => _TestAppSettingService(_setting(channel: channel)),
        ),
        installedCheckoutIdsProvider.overrideWith((_) => const IList<String>.empty()),
        repoStateProvider.overrideWith(() => repoStateNotifier),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test("commits the new channel on success", () async {
    final container = makeContainer();

    final failure = await container.read(channelSwitchActionProvider)("testing");

    expect(failure, isNull);
    expect(container.read(appSettingServiceProvider).remoteContent.channel, "testing");
    verify(() => mockUpdateService.rebindCheckoutsToChannel("testing")).called(1);
    expect(repoStateNotifier.initializeCalls, 1);
  });

  test("keeps the stored channel when discovery fails", () async {
    when(() => mockRepoService.discoverChannels()).thenAnswer((_) async => const Left("boom"));
    final container = makeContainer();

    final failure = await container.read(channelSwitchActionProvider)("testing");

    expect(failure, "boom");
    expect(container.read(appSettingServiceProvider).remoteContent.channel, "stable");
    verifyNever(() => mockUpdateService.rebindCheckoutsToChannel(any()));
    expect(repoStateNotifier.initializeCalls, 0);
  });

  test("keeps the stored channel when generation sync fails", () async {
    when(
      () => mockRepoService.syncChannelGeneration(any()),
    ).thenAnswer((_) async => const Left("sync failed"));
    final container = makeContainer();

    final failure = await container.read(channelSwitchActionProvider)("testing");

    expect(failure, "sync failed");
    expect(container.read(appSettingServiceProvider).remoteContent.channel, "stable");
    verifyNever(() => mockUpdateService.rebindCheckoutsToChannel(any()));
    expect(repoStateNotifier.initializeCalls, 0);
  });
}
