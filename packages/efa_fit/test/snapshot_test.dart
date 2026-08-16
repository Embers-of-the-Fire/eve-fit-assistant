import "package:efa_fit/efa_fit.dart";
import "package:flutter_test/flutter_test.dart";

const _ship = SnapshotTypeData(typeId: 634, names: {"en": "Vexor", "zh": "狂怒者级"});

const _layout = SnapshotShipLayoutData(
  highSlots: 5,
  mediumSlots: 3,
  lowSlots: 4,
  rigSlots: 3,
  turretHardpoints: 4,
  launcherHardpoints: 1,
);

FitSnapshotBuilder _builder({DateTime Function()? clock}) => FitSnapshotBuilder(
  fitName: "Brawler Vexor",
  ship: _ship,
  layout: _layout,
  character: const SnapshotCharacterData.builtin(
    SnapshotBuiltinCharacter.all5,
    names: {"en": "All 5", "zh": "全 5"},
  ),
  damageProfile: const SnapshotDamageProfile.uniform(),
  lastModified: DateTime.fromMillisecondsSinceEpoch(1755201600000),
  description: "Dual-rep brawler.",
  generator: "eve-fit-assistant/0.6.0",
  checkoutId: "a1b2c3d4",
  serverId: "tranquility",
  clock: clock ?? () => DateTime.fromMillisecondsSinceEpoch(1755300000000),
);

const _blaster = SnapshotModuleData(
  type: SnapshotTypeData(typeId: 3170, names: {"en": "Heavy Electron Blaster II"}),
  state: Slots_SlotState.ACTIVE,
  charge: SnapshotChargeData(
    type: SnapshotTypeData(typeId: 222, names: {"en": "Void S"}),
    quantity: 8,
  ),
  isTurret: true,
  relatedValues: [SnapshotDisplayValueData(text: "86.4 DPS", attributeId: 64)],
);

void main() {
  group("FitSnapshotBuilder", () {
    test("fills racks to the layout size with indexed empty slots", () {
      final builder = _builder()..setModule(SnapshotRack.high, 0, _blaster);
      final snapshot = builder.build();

      expect(snapshot.version, currentFitSnapshotVersion);
      expect(snapshot.highSlots, hasLength(5));
      expect(snapshot.mediumSlots, hasLength(3));
      expect(snapshot.lowSlots, hasLength(4));
      expect(snapshot.rigSlots, hasLength(3));
      expect(snapshot.serviceSlots, isEmpty);

      for (final (index, slot) in snapshot.highSlots.indexed) {
        expect(slot.index, index);
      }
      expect(snapshot.highSlots[0].hasItem(), isTrue);
      expect(snapshot.highSlots[1].hasItem(), isFalse);
    });

    test("assembles modules with charge, hardpoint flags and related values", () {
      final snapshot = (_builder()..setModule(SnapshotRack.high, 2, _blaster)).build();
      final module = snapshot.highSlots[2].item;

      expect(module.type.typeId, 3170);
      expect(module.type.names["en"], "Heavy Electron Blaster II");
      expect(module.state, Slots_SlotState.ACTIVE);
      expect(module.charge.type.names["en"], "Void S");
      expect(module.charge.quantity, 8);
      expect(module.isTurret, isTrue);
      expect(module.hasIsLauncher(), isFalse);
      expect(module.relatedValues.single.text, "86.4 DPS");
      expect(module.relatedValues.single.attributeId, 64);
    });

    test("emits all ten implant slots, filled or empty", () {
      final builder = _builder()
        ..setImplant(
          7,
          const SnapshotModuleData(
            type: SnapshotTypeData(typeId: 22107, names: {"en": "Zainou 'Deadeye' SH-705"}),
            state: Slots_SlotState.ONLINE,
          ),
        );
      final snapshot = builder.build();

      expect(snapshot.implants, hasLength(implantSlotCount));
      for (final (index, implant) in snapshot.implants.indexed) {
        expect(implant.slotIndex, index + 1);
      }
      expect(snapshot.implants[6].item.type.typeId, 22107);
      expect(snapshot.implants[0].hasItem(), isFalse);
    });

    test("emits subsystems with their subsystem type", () {
      const layout = SnapshotShipLayoutData(highSlots: 3, subsystemSlots: 4);
      final builder =
          FitSnapshotBuilder(
            fitName: "Tengu",
            ship: const SnapshotTypeData(typeId: 29984, names: {"en": "Tengu"}),
            layout: layout,
            character: const SnapshotCharacterData.builtin(SnapshotBuiltinCharacter.all5),
            damageProfile: const SnapshotDamageProfile.uniform(),
            lastModified: DateTime.fromMillisecondsSinceEpoch(0),
            clock: () => DateTime.fromMillisecondsSinceEpoch(0),
          )..setSubsystem(
            1,
            Subsystem_SubsystemType.DEFENSIVE,
            const SnapshotModuleData(
              type: SnapshotTypeData(
                typeId: 30050,
                names: {"en": "Tengu Defensive - Amplification Node"},
              ),
              state: Slots_SlotState.ONLINE,
            ),
          );
      final snapshot = builder.build();

      expect(snapshot.subsystemSlots, hasLength(4));
      expect(snapshot.subsystemSlots[1].subsystemType, Subsystem_SubsystemType.DEFENSIVE);
      expect(snapshot.subsystemSlots[1].item.type.typeId, 30050);
      expect(snapshot.subsystemSlots[0].subsystemType, Subsystem_SubsystemType.UNKNOWN);
      expect(snapshot.subsystemSlots[0].hasItem(), isFalse);
    });

    test("assembles drones, fighters and boosters", () {
      final builder = _builder()
        ..addDrone(
          const SnapshotDroneData(
            type: SnapshotTypeData(typeId: 2188, names: {"en": "Hammerhead II"}),
            state: Slots_SlotState.ACTIVE,
            quantity: 5,
          ),
        )
        ..addFighter(
          const SnapshotFighterData(
            type: SnapshotTypeData(typeId: 40557, names: {"en": "Einherji II"}),
            quantity: 6,
            maxSquadronSize: 9,
            group: SnapshotFighter_SquadronGroup.LIGHT,
            abilities: [SnapshotFighter_Ability.TURRET, SnapshotFighter_Ability.MISSILES],
            relatedValues: [SnapshotDisplayValueData(text: "6 x 90.0 DPS = 540.0 DPS")],
          ),
        )
        ..addBooster(
          const SnapshotBoosterData(
            slotIndex: 2,
            type: SnapshotTypeData(typeId: 28679, names: {"en": "Standard Exile Booster"}),
            state: Slots_SlotState.ONLINE,
          ),
        );
      final snapshot = builder.build();

      expect(snapshot.drones.single.quantity, 5);
      expect(snapshot.drones.single.state, Slots_SlotState.ACTIVE);

      final fighter = snapshot.fighters.single;
      expect(fighter.group, SnapshotFighter_SquadronGroup.LIGHT);
      expect(fighter.maxSquadronSize, 9);
      expect(fighter.abilities, [SnapshotFighter_Ability.TURRET, SnapshotFighter_Ability.MISSILES]);
      expect(fighter.relatedValues.single.text, contains("540.0"));

      expect(snapshot.boosters.single.slotIndex, 2);
      expect(snapshot.boosters.single.state, Slots_SlotState.ONLINE);
    });

    test("maps the character and stamps the header", () {
      final snapshot = _builder().build();

      expect(snapshot.character.builtin, SnapshotCharacter_Builtin.ALL_5);
      expect(snapshot.character.names["zh"], "全 5");

      expect(snapshot.header.fitName, "Brawler Vexor");
      expect(snapshot.header.description, "Dual-rep brawler.");
      expect(snapshot.header.lastModifiedMs.toInt(), 1755201600000);
      expect(snapshot.header.createdAtMs.toInt(), 1755300000000);
      expect(snapshot.header.generator, "eve-fit-assistant/0.6.0");
      expect(snapshot.header.checkoutId, "a1b2c3d4");
    });

    test("supports custom characters", () {
      final builder = FitSnapshotBuilder(
        fitName: "x",
        ship: _ship,
        layout: _layout,
        character: const SnapshotCharacterData.custom(
          characterId: "char-1",
          names: {"en": "Station Alt"},
        ),
        damageProfile: const SnapshotDamageProfile.uniform(),
        lastModified: DateTime.fromMillisecondsSinceEpoch(0),
        clock: () => DateTime.fromMillisecondsSinceEpoch(0),
      );
      final character = builder.build().character;

      expect(character.builtin, SnapshotCharacter_Builtin.NONE);
      expect(character.characterId, "char-1");
      expect(character.names["en"], "Station Alt");
    });

    test("attaches statistics and tactical modes", () {
      final builder = _builder()
        ..setStatistics(
          SnapshotStatistics(
            weapons: SnapshotStatistics_Weapons(
              dpsTotal: 522.7,
              dpsWithReload: 448.1,
              alphaVolley: 1320,
            ),
          ),
        )
        ..setTacticalMode(
          const SnapshotTacticalModeData(
            type: SnapshotTypeData(typeId: 35693, names: {"en": "Confessor Defense Mode"}),
            variant: TacticalMode_TacticalModeVariant.DEFENSE,
          ),
        );
      final snapshot = builder.build();

      expect(snapshot.statistics.weapons.dpsTotal, closeTo(522.7, 1e-9));
      expect(snapshot.tacticalMode.variant, TacticalMode_TacticalModeVariant.DEFENSE);
    });

    test("rejects types without an english name", () {
      final builder = _builder()
        ..setModule(
          SnapshotRack.low,
          0,
          const SnapshotModuleData(type: SnapshotTypeData(typeId: 1, names: {"zh": "仅中文"})),
        );
      expect(builder.build, throwsA(isA<FitSnapshotBuildException>()));
    });

    test("rejects out-of-range and duplicate slot indexes", () {
      expect(
        () => _builder().setModule(SnapshotRack.high, 5, _blaster),
        throwsA(isA<FitSnapshotBuildException>()),
      );
      expect(
        () => _builder().setModule(SnapshotRack.rig, -1, _blaster),
        throwsA(isA<FitSnapshotBuildException>()),
      );

      final builder = _builder()..setModule(SnapshotRack.low, 0, _blaster);
      expect(
        () => builder.setModule(SnapshotRack.low, 0, _blaster),
        throwsA(isA<FitSnapshotBuildException>()),
      );
    });

    test("rejects invalid implant slots and duplicate boosters", () {
      expect(() => _builder().setImplant(0, _blaster), throwsA(isA<FitSnapshotBuildException>()));
      expect(() => _builder().setImplant(11, _blaster), throwsA(isA<FitSnapshotBuildException>()));

      const booster = SnapshotBoosterData(
        slotIndex: 1,
        type: SnapshotTypeData(typeId: 28679, names: {"en": "Standard Exile Booster"}),
      );
      final builder = _builder()..addBooster(booster);
      expect(() => builder.addBooster(booster), throwsA(isA<FitSnapshotBuildException>()));
    });
  });

  group("encode/decode", () {
    test("round-trips a snapshot through the wire format", () {
      final snapshot = (_builder()..setModule(SnapshotRack.high, 0, _blaster)).build();
      final decoded = decodeFitSnapshot(encodeFitSnapshot(snapshot));

      expect(decoded.header.fitName, "Brawler Vexor");
      expect(decoded.ship.type.names["en"], "Vexor");
      expect(decoded.highSlots[0].item.charge.quantity, 8);
    });

    test("rejects snapshots of a different version", () {
      final snapshot = _builder().build()..version = currentFitSnapshotVersion + 1;
      expect(
        () => decodeFitSnapshot(snapshot.writeToBuffer()),
        throwsA(isA<FitSnapshotDecodeException>()),
      );
    });

    test("rejects snapshots without a version field", () {
      expect(
        () => decodeFitSnapshot(FitSnapshot().writeToBuffer()),
        throwsA(isA<FitSnapshotDecodeException>()),
      );
    });

    test("rejects snapshots missing other required fields", () {
      final noHeader = _builder().build()..clearHeader();
      expect(
        () => decodeFitSnapshot(noHeader.writeToBuffer()),
        throwsA(isA<FitSnapshotDecodeException>()),
      );

      final noShip = _builder().build()..clearShip();
      expect(
        () => decodeFitSnapshot(noShip.writeToBuffer()),
        throwsA(isA<FitSnapshotDecodeException>()),
      );

      final incompleteModule = _builder().build()
        ..highSlots.add(SnapshotSlot(index: 0, item: SnapshotModule()));
      expect(
        () => decodeFitSnapshot(incompleteModule.writeToBuffer()),
        throwsA(isA<FitSnapshotDecodeException>()),
      );
    });
  });
}
