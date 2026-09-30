@TestOn("vm")
library;

import "dart:io";

import "package:efa_proto/collections.pb.dart";
import "package:efa_proto/fit.pb.dart" as proto_fit;
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/killmail_import/importer.dart";
import "package:eve_fit_assistant/storage/fit/manager.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/collection.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";

const _shipTypeId = 11985;

// Trimmed zKillboard response (killID 126861807) with the flags the importer
// consumes: 6 high, 5 med, 2 low, 2 rigs, 5 drones, plus cargo that must be
// dropped.
const _killmailJson = """
{
  "killmail_id": 126861807,
  "killmail_time": "2025-05-05T20:18:06Z",
  "victim": {
    "ship_type_id": $_shipTypeId,
    "items": [
      {"flag": 27, "item_type_id": 8641, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 28, "item_type_id": 16487, "quantity_dropped": 1, "singleton": 0},
      {"flag": 29, "item_type_id": 8641, "quantity_dropped": 1, "singleton": 0},
      {"flag": 30, "item_type_id": 8641, "quantity_dropped": 1, "singleton": 0},
      {"flag": 31, "item_type_id": 16487, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 32, "item_type_id": 8635, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 19, "item_type_id": 35660, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 20, "item_type_id": 3841, "quantity_dropped": 1, "singleton": 0},
      {"flag": 21, "item_type_id": 2301, "quantity_dropped": 1, "singleton": 0},
      {"flag": 22, "item_type_id": 3841, "quantity_dropped": 1, "singleton": 0},
      {"flag": 23, "item_type_id": 2281, "quantity_dropped": 1, "singleton": 0},
      {"flag": 11, "item_type_id": 1355, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 12, "item_type_id": 2048, "quantity_dropped": 1, "singleton": 0},
      {"flag": 92, "item_type_id": 31796, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 93, "item_type_id": 31796, "quantity_destroyed": 1, "singleton": 0},
      {"flag": 87, "item_type_id": 2488, "quantity_destroyed": 5, "singleton": 0},
      {"flag": 5, "item_type_id": 28668, "quantity_destroyed": 100, "singleton": 0}
    ]
  }
}
""";

class _FakeFitManager extends FitManager {
  final List<FitStorage> imported = [];

  @override
  Future<DateTime> build() async => DateTime.fromMillisecondsSinceEpoch(0);

  @override
  Future<FitMetadata> importFit(FitStorage importedFit) async {
    imported.add(importedFit);
    return importedFit.metadata.copyWith(fitId: "imported-id");
  }
}

proto_fit.Ship _testShip() => proto_fit.Ship()
  ..typeId = _shipTypeId
  ..highSlots = 8
  ..mediumSlots = 5
  ..lowSlots = 6
  ..rigSlots = 3
  ..subsystemSlots = 0
  ..serviceSlots = 0;

RepoCollectionService _collection() {
  final collection = Collection();
  collection.ships[_shipTypeId] = _testShip();
  collection.slots = proto_fit.Slots();
  // 8641 is activatable (turret-like), the rest are passive-only.
  collection.slots.highSlots[8641] = proto_fit.Slots_HighSlot(
    typeId: 8641,
    maxState: proto_fit.Slots_SlotState.ACTIVE,
  );
  collection.slots.highSlots[16487] = proto_fit.Slots_HighSlot(
    typeId: 16487,
    maxState: proto_fit.Slots_SlotState.ACTIVE,
  );
  collection.slots.highSlots[8635] = proto_fit.Slots_HighSlot(
    typeId: 8635,
    maxState: proto_fit.Slots_SlotState.ONLINE,
  );
  collection.slots.mediumSlots[35660] = proto_fit.Slots_GeneralSlot(
    typeId: 35660,
    maxState: proto_fit.Slots_SlotState.ACTIVE,
  );
  collection.slots.rigSlots[31796] = proto_fit.Slots_GeneralSlot(
    typeId: 31796,
    maxState: proto_fit.Slots_SlotState.ONLINE,
  );
  collection.slots.lowSlots[1355] = proto_fit.Slots_GeneralSlot(
    typeId: 1355,
    maxState: proto_fit.Slots_SlotState.ONLINE,
  );
  return RepoCollectionService.forTest(collection: collection);
}

Future<WidgetRef> _pumpRef(
  WidgetTester tester, {
  required _FakeFitManager fitManager,
  RepoCollectionService? collection,
}) async {
  late WidgetRef captured;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        fitManagerProvider.overrideWith(() => fitManager),
        repoCollectionProvider.overrideWithValue(collection ?? _collection()),
      ],
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const SizedBox();
          },
        ),
      ),
    ),
  );
  return captured;
}

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_km_import_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  group("KillmailImporter.importFromJson", () {
    testWidgets("reconstructs the victim's fitting", (tester) async {
      final fitManager = _FakeFitManager();
      final ref = await _pumpRef(tester, fitManager: fitManager);

      final metadata = await KillmailImporter(ref).importFromJson(_killmailJson);

      expect(metadata.fitId, "imported-id");
      expect(metadata.name, "KM 126861807");
      expect(metadata.shipTypeId, _shipTypeId);

      final fit = fitManager.imported.single;
      final high = fit.body.slots.high;
      expect(high[0].toNullable()?.itemId.asId, 8641);
      expect(high[1].toNullable()?.itemId.asId, 16487);
      expect(high[5].toNullable()?.itemId.asId, 8635);
      expect(high[6].toNullable(), isNull);
      expect(high[0].toNullable()?.state, FitItemState.active);
      // Passive-only modules import online, even in combat racks.
      expect(high[5].toNullable()?.state, FitItemState.online);

      final medium = fit.body.slots.medium;
      expect(medium[0].toNullable()?.itemId.asId, 35660);
      expect(medium[4].toNullable()?.itemId.asId, 2281);

      final low = fit.body.slots.low;
      expect(low[0].toNullable()?.itemId.asId, 1355);
      expect(low[1].toNullable()?.itemId.asId, 2048);
      expect(low[2].toNullable(), isNull);

      final rig = fit.body.slots.rig;
      expect(rig[0].toNullable()?.itemId.asId, 31796);
      expect(rig[1].toNullable()?.itemId.asId, 31796);
      expect(rig[2].toNullable(), isNull);
      expect(rig[0].toNullable()?.state, FitItemState.online);

      expect(fit.body.drones, hasLength(1));
      expect(fit.body.drones[0].itemId.asId, 2488);
      expect(fit.body.drones[0].quantity, 5);

      // Cargo items are dropped: 17 items in, 16 fitted.
      expect(fit.body.implants, isEmpty);
      expect(fit.body.boosters, isEmpty);
    });

    testWidgets("rejects invalid JSON", (tester) async {
      final ref = await _pumpRef(tester, fitManager: _FakeFitManager());

      expect(
        () => KillmailImporter(ref).importFromJson("not json"),
        throwsA(
          isA<KillmailImportException>().having(
            (e) => e.code,
            "code",
            KillmailImportErrorCode.invalidKillmail,
          ),
        ),
      );
    });

    testWidgets("rejects empty input", (tester) async {
      final ref = await _pumpRef(tester, fitManager: _FakeFitManager());

      expect(
        () => KillmailImporter(ref).importFromJson("  "),
        throwsA(
          isA<KillmailImportException>().having(
            (e) => e.code,
            "code",
            KillmailImportErrorCode.emptyInput,
          ),
        ),
      );
    });

    testWidgets("rejects ships missing from the data store", (tester) async {
      final collection = Collection();
      final ref = await _pumpRef(
        tester,
        fitManager: _FakeFitManager(),
        collection: RepoCollectionService.forTest(collection: collection),
      );

      expect(
        () => KillmailImporter(ref).importFromJson(_killmailJson),
        throwsA(
          isA<KillmailImportException>().having(
            (e) => e.code,
            "code",
            KillmailImportErrorCode.unavailableShip,
          ),
        ),
      );
    });
  });

  group("KillmailImporter.importFromUrl", () {
    testWidgets("rejects unrecognized URLs", (tester) async {
      final ref = await _pumpRef(tester, fitManager: _FakeFitManager());

      expect(
        () => KillmailImporter(ref).importFromUrl("https://example.com/kill/1/"),
        throwsA(
          isA<KillmailImportException>().having(
            (e) => e.code,
            "code",
            KillmailImportErrorCode.invalidUrl,
          ),
        ),
      );
    });
  });
}
