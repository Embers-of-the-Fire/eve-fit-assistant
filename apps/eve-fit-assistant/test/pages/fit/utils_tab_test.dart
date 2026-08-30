@TestOn("vm")
library;

import "dart:convert";
import "dart:io";
import "dart:ui" as ui;

import "package:efa_proto/collections.pb.dart";
import "package:efa_proto/fit.pb.dart" as proto_fit;
import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:eve_fit_assistant/features/fit_io/share_dialog.dart";
import "package:eve_fit_assistant/features/fit_io/share_operation.dart";
import "package:eve_fit_assistant/pages/fit/page.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/persistence.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/fs/doc_store.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

import "../../test_helpers.dart";

const String _fitId = "utils-tab-test-fit";
const int _shipTypeId = 587;

proto_fit.Ship _ship() => proto_fit.Ship()..typeId = _shipTypeId;

FitStorage _fitStorage() => FitStorage.empty(
  const FitMetadata(
    fitId: _fitId,
    shipTypeId: _shipTypeId,
    name: "Test Fit",
    lastModified: 0,
    description: "Original description",
    // An empty checkout ref keeps the fit editable regardless of the (absent)
    // active checkout in tests.
    checkoutRef: CheckoutRef(checkoutId: "", serverId: ""),
  ),
  _ship(),
);

class _InMemoryDocStore implements DocStore {
  final Map<String, String> docs = {};

  @override
  Future<void> init() async {}

  @override
  Future<String?> read(String key) async => docs[key];

  @override
  Future<bool> exists(String key) async => docs.containsKey(key);

  @override
  Future<void> write(String key, String value) async {
    docs[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    docs.remove(key);
  }

  @override
  Future<List<String>> keys() async => docs.keys.toList();
}

/// Registry manager without disk access: keeps the registry in memory only.
class _FakeFitRegistryManager extends FitRegistryManager {
  _FakeFitRegistryManager(this._initial);

  final FitRegistry _initial;

  @override
  FitRegistry build() => _initial;

  @override
  void updateFit(FitMetadata metadata) {
    state = state.copyWith(fits: state.fits.add(metadata.fitId, metadata));
  }
}

/// Mounts [FitDisplayColumns] (the public entry point containing the utils
/// tab) the same way `_FitPage` wires it up.
class _Subject extends ConsumerWidget {
  const _Subject({required this.fit});

  final FitStorage fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitState = ref.watch(fitProvider(fit.metadata.fitId));
    final fitWrapper = FitWrapper(
      wrapped: ref.read(fitProvider(fit.metadata.fitId).notifier),
      fitId: fit.metadata.fitId,
      ref: ref,
    );
    // A narrow surface forces the single-column layout, so only one tab bar
    // (and therefore at most one of each button label) exists in the tree.
    return MediaQuery(
      data: const MediaQueryData(size: Size(500, 800)),
      child: Scaffold(
        body: FitDisplayColumns(
          fitContext: FitContext(
            fitId: fit.metadata.fitId,
            fit: fitState.fit,
            fitWrapper: fitWrapper,
            emulated: null,
            ship: _ship(),
          ),
        ),
      ),
    );
  }
}

void main() {
  setUpAll(() {
    GlobalLogger.init(
      Directory.systemTemp.createTempSync("efa-utils-tab-test").path,
      enableDebugLog: false,
    );
  });

  final l10n = lookupAppLocalizations(const ui.Locale("zh"));

  late _InMemoryDocStore fitStore;

  setUp(() {
    fitStore = _InMemoryDocStore();
  });

  Widget buildSubject(FitStorage fit) => ProviderScope(
    overrides: [
      appSettingServiceProvider.overrideWithValue(
        const AppSetting(
          locale: Locale.zh,
          enableDebugLog: false,
          shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
          showCheckoutImpactWarnings: true,
          typeListReturnBehavior: TypeListReturnBehavior.previousPage,
          developerMode: false,
        ),
      ),
      activeCheckoutProvider.overrideWithValue(const None()),
      activeCheckoutIdProvider.overrideWithValue(const None()),
      repoCollectionProvider.overrideWithValue(
        RepoCollectionService.forTest(collection: Collection()..ships[_shipTypeId] = _ship()),
      ),
      fitsDocStoreProvider.overrideWithValue(fitStore),
      fitRegistryManagerProvider.overrideWith(
        () => _FakeFitRegistryManager(FitRegistry(fits: IMap({_fitId: fit.metadata}))),
      ),
      fitProvider(_fitId).overrideWithBuild(
        (ref, notifier) => FitServiceState.loaded(
          status: FitServiceStatus.loaded(lastSync: DateTime.fromMillisecondsSinceEpoch(0)),
          fit: fit,
        ),
      ),
      fitEmulatorServiceProvider(
        _fitId,
      ).overrideWithBuild((ref, notifier) => const FitEmulatorState.notInitialized()),
      fitShareEligibilityProvider.overrideWith((ref) => true),
    ],
    child: testApp(_Subject(fit: fit)),
  );

  Finder shareButton() => find.widgetWithText(OutlinedButton, l10n.fitUtilsShareButton);

  bool shareEnabled(WidgetTester tester) =>
      tester.widget<OutlinedButton>(shareButton()).onPressed != null;

  Future<void> openUtilsTab(WidgetTester tester, FitStorage fit) async {
    await tester.pumpWidget(buildSubject(fit));
    await tester.pump();
    // The single-column layout starts on the equipment tab; switch to utils.
    await tester.tap(find.text(l10n.fitTabsUtils));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(shareButton(), findsOneWidget);
  }

  testWidgets("share is disabled while metadata edits are pending", (tester) async {
    await openUtilsTab(tester, _fitStorage());
    expect(shareEnabled(tester), isTrue);

    await tester.tap(find.widgetWithText(OutlinedButton, l10n.edit));
    await tester.pump();

    // Unsaved name/description edits live only in the controllers; the share
    // dialog would upload the stale persisted fit, so the button is disabled.
    expect(shareEnabled(tester), isFalse);
    await tester.tap(shareButton());
    await tester.pump();
    expect(find.byType(FitShareDialog), findsNothing);

    // Discarding the edits re-enables sharing.
    await tester.tap(find.widgetWithText(OutlinedButton, l10n.cancel));
    await tester.pump();
    expect(shareEnabled(tester), isTrue);
  });

  testWidgets("share is re-enabled once the metadata save completes", (tester) async {
    await openUtilsTab(tester, _fitStorage());

    await tester.tap(find.widgetWithText(OutlinedButton, l10n.edit));
    await tester.pump();
    expect(shareEnabled(tester), isFalse);

    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.fitUtilsNameLabel),
      "Renamed Fit",
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, l10n.fitUtilsDescriptionLabel),
      "Updated description",
    );
    await tester.tap(find.widgetWithText(FilledButton, l10n.confirm));
    await tester.pump();
    await tester.pump();

    expect(shareEnabled(tester), isTrue);

    // The persisted fit now carries the edited metadata, so the share dialog
    // uploads exactly what the user sees in the form.
    final saved = fitStore.docs["$_fitId.json"];
    expect(saved, isNotNull);
    final savedMetadata = decodeFitStorage(jsonDecode(saved!) as Map<String, dynamic>).fit.metadata;
    expect(savedMetadata.name, "Renamed Fit");
    expect(savedMetadata.description, "Updated description");
  });
}
