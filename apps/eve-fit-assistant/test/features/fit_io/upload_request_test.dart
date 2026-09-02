@TestOn("vm")
library;

import "dart:io";

import "package:efa_proto/fit.pb.dart" show Slots_SlotState;
import "package:efa_proto/fit_request.pb.dart" hide FitDynamicItem;
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/fit_io/upload_request.dart";
import "package:eve_fit_assistant/storage/character/schema.dart";
import "package:eve_fit_assistant/storage/fit/schema.dart";
import "package:eve_fit_assistant/storage/repo/models/checkout_ref.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

FitStorage _makeFit({
  String name = "Test Fit",
  String description = "A test fit",
  String characterId = "char-1",
}) => FitStorage(
  metadata: FitMetadata(
    fitId: "test-fit-1",
    shipTypeId: 12017,
    name: name,
    lastModified: 1234567890,
    description: description,
    checkoutRef: const CheckoutRef(checkoutId: "checkout-abc", serverId: "Serenity"),
  ),
  body: FitStorageBody(
    shipTypeId: 12017,
    characterId: characterId,
    damageProfile: const FitDamageProfile(em: 0.5, explosive: 0.1, kinetic: 0.2, thermal: 0.2),
    slots: FitStorageSlots(
      high: IList([
        Some(
          const FitModuleItem(
            itemId: FitStorageItemId.item(id: 8101),
            state: FitItemState.active,
            charge: Some(FitChargeItem(typeId: 230)),
          ),
        ),
        const None(),
      ]),
      medium: IList([const None()]),
      low: IList(const []),
      rig: IList([
        Some(
          const FitModuleItem(
            itemId: FitStorageItemId.dynamic(dynamicId: 0),
            state: FitItemState.passive,
            charge: None(),
          ),
        ),
      ]),
      subsystem: IList([
        Some(
          const FitModuleItem(
            itemId: FitStorageItemId.item(id: 45678),
            state: FitItemState.online,
            charge: None(),
          ),
        ),
      ]),
      service: IList(const []),
      tacticalMode: const Some(1000),
    ),
    drones: IList([
      const FitDroneItem(
        itemId: FitStorageItemId.item(id: 2456),
        state: FitItemState.active,
        quantity: 5,
      ),
      const FitDroneItem(
        itemId: FitStorageItemId.dynamic(dynamicId: 7),
        state: FitItemState.active,
        quantity: 2,
      ),
    ]),
    fighters: IList(const []),
    implants: IList(const []),
    boosters: IList(const []),
  ),
  dynamicRegistry: FitDynamicRegistry(
    dynamicItems: IMap({
      0: FitDynamicItem(
        dynamicItemId: 0,
        originTypeId: 31000,
        typeId: 31001,
        modifierTypeId: 0,
        dynamicAttributes: IMap({1372: 1.5}),
      ),
      1: FitDynamicItem(
        dynamicItemId: 1,
        originTypeId: 32000,
        typeId: 32001,
        modifierTypeId: 0,
        dynamicAttributes: IMap({}),
      ),
    }),
  ),
);

FitUploadRequest _build(FitStorage fit) => buildFitUploadRequest(
  fit: fit,
  snapshotHash: "snapshot-hash-1",
  generator: "eve-fit-assistant/1.2.3",
  skills: const {3300: 5, 3301: 4},
  characterName: "Char Name",
);

void main() {
  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_upload_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  group("request header", () {
    test("maps metadata fields", () {
      final request = _build(_makeFit());
      expect(request.serverId, "Serenity");
      expect(request.snapshotHash, "snapshot-hash-1");
      expect(request.fitName, "Test Fit");
      expect(request.description, "A test fit");
      expect(request.lastModifiedMs.toInt(), 1234567890);
      expect(request.generator, "eve-fit-assistant/1.2.3");
    });

    test("omits an empty description", () {
      final request = _build(_makeFit(description: ""));
      expect(request.hasDescription(), isFalse);
    });

    test("omits the latest-snapshot fallback consent unless consented", () {
      expect(_build(_makeFit()).hasAllowLatestSnapshotFallback(), isFalse);

      final consented = buildFitUploadRequest(
        fit: _makeFit(),
        snapshotHash: "snapshot-hash-1",
        generator: "eve-fit-assistant/1.2.3",
        skills: const {3300: 5, 3301: 4},
        characterName: "Char Name",
        allowLatestSnapshotFallback: true,
      );
      expect(consented.hasAllowLatestSnapshotFallback(), isTrue);
      expect(consented.allowLatestSnapshotFallback, isTrue);
    });
  });

  group("fit state", () {
    test("layout falls back to slot list lengths without a collection", () {
      final fit = _build(_makeFit()).fit;
      expect(fit.shipTypeId, 12017);
      expect(fit.layout.highSlots, 2);
      expect(fit.layout.mediumSlots, 1);
      expect(fit.layout.lowSlots, 0);
      expect(fit.layout.rigSlots, 1);
      expect(fit.layout.turretHardpoints, 0);
      expect(fit.layout.fighterTubes, 0);
    });

    test("layout subsystem slots cover only fitted subsystems without a collection", () {
      // The stored subsystem list is always `subsystemSize` long, so its raw
      // length must not leak into the exported layout.
      expect(_build(_makeFit()).fit.layout.subsystemSlots, 1);

      final fit = _makeFit();
      final emptySubsystem = fit.copyWith(
        body: fit.body.copyWith(
          slots: fit.body.slots.copyWith(
            subsystem: IList(List<Option<FitModuleItem>>.filled(4, const None())),
          ),
        ),
      );
      expect(_build(emptySubsystem).fit.layout.subsystemSlots, 0);
    });

    test("maps rack modules with charges and dynamic ids", () {
      final modules = _build(_makeFit()).fit.modules;
      expect(modules, hasLength(2));

      final high = modules[0];
      expect(high.slotType, SlotType.HIGH);
      expect(high.index, 0);
      expect(high.typeId, 8101);
      expect(high.state, Slots_SlotState.ACTIVE);
      expect(high.chargeTypeId, 230);

      final rig = modules[1];
      expect(rig.slotType, SlotType.RIG);
      expect(rig.index, 0);
      expect(rig.dynamicId, 0);
      expect(rig.state, Slots_SlotState.PASSIVE);
      expect(rig.hasChargeTypeId(), isFalse);
    });

    test("skips subsystem modules when the subsystem type cannot be resolved", () {
      final modules = _build(_makeFit()).fit.modules;
      expect(modules.where((module) => module.slotType == SlotType.SUBSYSTEM), isEmpty);
    });

    test("drops the tactical mode when the ship definition is unavailable", () {
      final fit = _build(_makeFit()).fit;
      expect(fit.hasTacticalModeTypeId(), isFalse);
      expect(fit.availableTacticalModes, isEmpty);
    });

    test("maps drones and skips unresolvable dynamic drones", () {
      final drones = _build(_makeFit()).fit.drones;
      expect(drones, hasLength(1));
      expect(drones.single.typeId, 2456);
      expect(drones.single.quantity, 5);
      expect(drones.single.state, Slots_SlotState.ACTIVE);
    });

    test("maps the damage profile", () {
      final profile = _build(_makeFit()).fit.damageProfile;
      expect(profile.em, 0.5);
      expect(profile.thermal, 0.2);
      expect(profile.kinetic, 0.2);
      expect(profile.explosive, 0.1);
    });

    test("includes only referenced dynamic items", () {
      final dynamicItems = _build(_makeFit()).fit.dynamicItems;
      expect(dynamicItems, hasLength(1));
      final item = dynamicItems.single;
      expect(item.dynamicId, 0);
      expect(item.baseTypeId, 31000);
      expect(item.typeId, 31001);
      expect(item.attributes, hasLength(1));
      expect(item.attributes.single.attributeId, 1372);
      expect(item.attributes.single.value, 1.5);
    });

    test("maps skills", () {
      final skills = _build(_makeFit()).fit.skills;
      expect(skills, hasLength(2));
      final byType = {for (final skill in skills) skill.typeId: skill.level};
      expect(byType, {3300: 5, 3301: 4});
    });
  });

  group("character", () {
    test("custom character carries id and english name", () {
      final character = _build(_makeFit()).fit.character;
      expect(character.characterId, "char-1");
      expect(character.names["en"], "Char Name");
    });

    test("built-in character carries only a display name", () {
      final character = _build(_makeFit(characterId: predefinedMaxCharacterId)).fit.character;
      expect(character.hasCharacterId(), isFalse);
      expect(character.names["en"], "All 5");
    });
  });

  test("serializes with every proto2 required field set", () {
    final request = _build(_makeFit());
    final roundTripped = FitUploadRequest.fromBuffer(request.writeToBuffer());
    expect(roundTripped.serverId, request.serverId);
    expect(roundTripped.fit.modules, hasLength(request.fit.modules.length));
  });
}
