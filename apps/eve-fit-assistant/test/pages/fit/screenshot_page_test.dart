@TestOn("vm")
library;

import "dart:io";
import "dart:typed_data";
import "dart:ui" as ui;

import "package:eve_fit_assistant/config/locale.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/type_list.dart";
import "package:efa_constant/eve.dart";
import "package:eve_fit_assistant/data/l10n/app_localizations.dart";
import "package:efa_proto/collections.pb.dart";
import "package:efa_proto/fit.pb.dart" as proto_fit;
import "package:efa_proto/types.pb.dart" as pb_types;
import "package:efa_proto/utils.pb.dart" as pb_utils;
import "package:eve_fit_assistant/native/api/output.dart" as native;
import "package:eve_fit_assistant/native/api/storage.dart" as native_storage;
import "package:eve_fit_assistant/native/api/validation.dart" as native_validation;
import "package:eve_fit_assistant/pages/fit/page.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/fit/service.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:eve_fit_assistant/storage/repo/localization_db.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

import "../../test_helpers.dart";

const String _fitId = "screenshot-test-fit";
const int _shipTypeId = 587;

proto_fit.Ship _shipProto() => proto_fit.Ship()..typeId = _shipTypeId;

native.Item _item([Map<int, double> attributes = const {}]) => native.Item(
  itemId: const native_storage.ItemID.item(0),
  slot: const native.OutSlot(slotType: native.OutSlotType.high(), index: 0),
  state: native.EffectCategory.active,
  attributes: {
    for (final entry in attributes.entries)
      entry.key: native.Attribute(
        baseValue: entry.value,
        value: entry.value,
        buffs: Int32List(0),
        trackedModifiers: const [],
      ),
  },
  effects: Int32List(0),
);

native.Ship _emulatedShip({required bool overCapacity}) => native.Ship(
  hull: _item({
    EveConstAttrID.cpuOutput: 100,
    EveConstExtendedAttrID.cpuFree: overCapacity ? -20 : 20,
    EveConstAttrID.powerOutput: 50,
    EveConstExtendedAttrID.powerFree: 5,
  }),
  modules: const [],
  skills: const [],
  implants: const [],
  boosters: const [],
  character: _item(),
  damageProfile: const native_storage.DamageProfile(
    em: 0.25,
    explosive: 0.25,
    kinetic: 0.25,
    thermal: 0.25,
  ),
  structure: _item(),
  target: _item(),
  validationIssues: [
    if (overCapacity)
      const native_validation.ValidationIssue(
        slotType: native_validation.ValidationSlotType.ship,
        kind: native_validation.ValidationIssueKind.error(
          native_validation.ValidationErrorKey.cpuExceeded(expected: 100, actual: 120),
        ),
      ),
  ],
);

FitStorage _fitStorage() => FitStorage.empty(
  const FitMetadata(
    fitId: _fitId,
    shipTypeId: _shipTypeId,
    name: "Over Capacity",
    lastModified: 0,
    description: "",
    checkoutRef: CheckoutRef(checkoutId: "test-checkout", serverId: "test-server"),
  ),
  _shipProto(),
);

RepoCollectionService _collection() {
  final collection = Collection();
  collection.ships[_shipTypeId] = _shipProto();
  collection.types[_shipTypeId] = pb_types.Type(
    typeId: _shipTypeId,
    typeName: pb_utils.LocalizationID(id: 1),
  );
  return RepoCollectionService.forTest(collection: collection);
}

Future<void> _pumpScreenshotPage(WidgetTester tester, {required bool overCapacity}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appSettingServiceProvider.overrideWithValue(
          const AppSetting(
            locale: Locale.en,
            enableDebugLog: false,
            shipSelectListDisplayVariant: TypeListDisplayVariant.marketGroup,
            showCheckoutImpactWarnings: true,
            typeListReturnBehavior: TypeListReturnBehavior.previousPage,
            developerMode: false,
            remoteContent: RemoteContentSetting(originUrl: "https://example.com"),
          ),
        ),
        repoCollectionProvider.overrideWithValue(_collection()),
        localizationDbServiceProvider.overrideWith((ref) => null),
        imageAssetServiceProvider.overrideWith((ref) => null),
        fitProvider(_fitId).overrideWithBuild(
          (ref, notifier) => FitServiceState.loaded(
            status: FitServiceStatus.loaded(lastSync: DateTime.fromMillisecondsSinceEpoch(0)),
            fit: _fitStorage(),
          ),
        ),
        fitEmulatorServiceProvider(_fitId).overrideWithBuild(
          (ref, notifier) =>
              FitEmulatorState.emulated(output: _emulatedShip(overCapacity: overCapacity)),
        ),
      ],
      child: testApp(
        // The flutter_test font metrics are much wider than real fonts; scale
        // text down so fixed-width screenshot columns do not overflow.
        const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(0.5)),
          child: FitScreenshotPage(fitId: _fitId),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _errorIssueTrigger() => find.byWidgetPredicate(
  (widget) => widget is WarningTrigger && widget.type == WarningType.error,
);

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_screenshot_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  testWidgets("over-capacity fit surfaces ship issues in the screenshot output", (tester) async {
    await _pumpScreenshotPage(tester, overCapacity: true);

    expect(find.byType(FitScreenshotPage), findsOneWidget);
    expect(_errorIssueTrigger(), findsOneWidget);

    await tester.ensureVisible(_errorIssueTrigger());
    await tester.pumpAndSettle();
    await tester.tap(_errorIssueTrigger());
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const ui.Locale("zh"));
    expect(find.text(l10n.fitIssueCpuExceeded), findsOneWidget);
  });

  testWidgets("clean fit renders no issue trigger in the screenshot output", (tester) async {
    await _pumpScreenshotPage(tester, overCapacity: false);

    expect(find.byType(FitScreenshotPage), findsOneWidget);
    expect(find.byType(WarningTrigger), findsNothing);
  });
}
