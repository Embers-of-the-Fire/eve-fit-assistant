import "package:efa_fit/efa_fit.dart";

FitSnapshot buildFixtureSnapshot({bool withStatistics = true}) {
  final builder = FitSnapshotBuilder(
    fitName: "Test Rokh",
    description: "A snapshot fixture",
    ship: const SnapshotTypeData(typeId: 24688, names: {"en": "Rokh", "zh": "罗克级"}),
    layout: const SnapshotShipLayoutData(
      highSlots: 8,
      mediumSlots: 5,
      lowSlots: 6,
      rigSlots: 3,
      turretHardpoints: 8,
      launcherHardpoints: 0,
    ),
    character: const SnapshotCharacterData.builtin(SnapshotBuiltinCharacter.all5),
    damageProfile: const SnapshotDamageProfile.uniform(),
    lastModified: DateTime.utc(2025),
  );

  builder.setModule(
    SnapshotRack.high,
    0,
    const SnapshotModuleData(
      type: SnapshotTypeData(typeId: 2929, names: {"en": "425mm Railgun II", "zh": "425mm 磁轨炮 II"}),
      state: Slots_SlotState.ACTIVE,
      isTurret: true,
      charge: SnapshotChargeData(
        type: SnapshotTypeData(typeId: 209, names: {"en": "Antimatter Charge L", "zh": "反物质轨道弹 L"}),
        quantity: 80,
      ),
      relatedValues: [SnapshotDisplayValueData(text: "123.4 DPS")],
    ),
  );
  builder.setModule(
    SnapshotRack.medium,
    0,
    const SnapshotModuleData(
      type: SnapshotTypeData(typeId: 2281, names: {"en": "Multispectrum Shield Hardener II"}),
      state: Slots_SlotState.ACTIVE,
    ),
  );

  builder.addDrone(
    const SnapshotDroneData(
      type: SnapshotTypeData(typeId: 2488, names: {"en": "Hammerhead II"}),
      quantity: 5,
      state: Slots_SlotState.ACTIVE,
    ),
  );

  builder.setImplant(
    1,
    const SnapshotModuleData(
      type: SnapshotTypeData(typeId: 13202, names: {"en": "High-grade Halo Alpha"}),
    ),
  );

  builder.addBooster(
    const SnapshotBoosterData(
      slotIndex: 1,
      type: SnapshotTypeData(typeId: 15466, names: {"en": "Standard Blue Pill"}),
      state: Slots_SlotState.ACTIVE,
    ),
  );

  if (withStatistics) {
    builder.setStatistics(
      SnapshotStatistics(
        capacitor: SnapshotStatistics_Capacitor(
          isStable: true,
          stableFraction: 0.35,
          peakUseRate: 10.0,
          peakRechargeRate: 15.5,
          capacityGj: 5312.0,
          rechargeTimeS: 250.0,
        ),
        weapons: SnapshotStatistics_Weapons(
          dpsTotal: 456.7,
          dpsWithReload: 430.1,
          alphaVolley: 3800.0,
        ),
        resources: SnapshotStatistics_Resources(
          cpuUsed: 400.0,
          cpuTotal: 550.0,
          powergridUsed: 9000.0,
          powergridTotal: 13750.0,
          calibrationUsed: 150.0,
          calibrationTotal: 400.0,
          droneBandwidthUsed: 25.0,
          droneBandwidthTotal: 50.0,
        ),
        shield: SnapshotStatistics_DefenseLayer(
          hp: 9000.0,
          ehp: 45000.0,
          resistances: DamageProfile(em: 0.2, thermal: 0.4, kinetic: 0.6, explosive: 0.75),
        ),
        armor: SnapshotStatistics_DefenseLayer(
          hp: 6600.0,
          ehp: 20000.0,
          resistances: DamageProfile(em: 0.5, thermal: 0.65, kinetic: 0.75, explosive: 0.9),
        ),
        hull: SnapshotStatistics_DefenseLayer(
          hp: 7000.0,
          ehp: 9000.0,
          resistances: DamageProfile(em: 0.67, thermal: 0.67, kinetic: 0.67, explosive: 0.67),
        ),
        mobility: SnapshotStatistics_Mobility(
          maxVelocityMs: 120.5,
          warpSpeedAuS: 3.0,
          alignTimeS: 12.34,
          signatureRadiusM: 465.0,
        ),
        targeting: SnapshotStatistics_Targeting(
          maxTargetRangeM: 108000.0,
          scanResolutionMm: 120.0,
          maxLockedTargets: 8,
          radarStrength: 0.0,
          ladarStrength: 0.0,
          magnetometricStrength: 0.0,
          gravimetricStrength: 24.5,
        ),
        drones: SnapshotStatistics_Drones(
          maxActiveDrones: 5,
          controlRangeM: 60000.0,
          bayCapacityM3: 125.0,
          bayUsedM3: 50.0,
        ),
        cargo: SnapshotStatistics_Cargo(
          massKg: 99500000.0,
          capacityM3: 665.0,
          holds: [
            SnapshotStatistics_Cargo_Hold(
              kind: SnapshotStatistics_Cargo_HoldKind.FLEET_HANGAR,
              capacityM3: 5000.0,
            ),
          ],
        ),
      ),
    );
  }

  return builder.build();
}
