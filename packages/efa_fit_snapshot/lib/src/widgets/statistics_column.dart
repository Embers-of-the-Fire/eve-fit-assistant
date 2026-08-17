import "package:efa_component/efa_component.dart";
import "package:efa_fit/efa_fit.dart";
import "package:efa_fit_snapshot/src/context.dart";
import "package:efa_fit_snapshot/src/l10n.dart";
import "package:flutter/material.dart";

/// Ship header tile for the attributes column.
class SnapshotShipHeader extends StatelessWidget {
  const SnapshotShipHeader({required this.snapshot, super.key});

  final FitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final resolver = SnapshotDisplay.resolverOf(context);
    final ship = snapshot.ship.type;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minVerticalPadding: 10,
      minTileHeight: 0,
      leading: EfaTypeIcon(typeId: ship.typeId, resolver: resolver, size: 40),
      title: Text(
        resolveSnapshotName(ship.names, locale),
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Attributes column driven solely by [SnapshotStatistics].
class SnapshotStatisticsColumn extends StatelessWidget {
  const SnapshotStatisticsColumn({required this.snapshot, super.key});

  final FitSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    if (!snapshot.hasStatistics()) return const SizedBox.shrink();
    final stats = snapshot.statistics;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SnapshotShipHeader(snapshot: snapshot),
        const Divider(height: 0),
        _CapacitorSection(capacitor: stats.capacitor),
        _WeaponsSection(weapons: stats.weapons),
        _ResourcesSection(resources: stats.resources),
        _DefenseSection(snapshot: snapshot),
        _MobilityTargetingSection(stats: stats),
        _DronesSection(drones: stats.drones),
        _CargoSection(cargo: stats.cargo),
      ],
    );
  }
}

class _CapacitorSection extends StatelessWidget {
  const _CapacitorSection({required this.capacitor});

  final SnapshotStatistics_Capacitor capacitor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.snapshotL10n;
    final stable = capacitor.isStable;
    final percent = stable && capacitor.hasStableFraction()
        ? (capacitor.stableFraction * 100).clamp(0.0, 100.0)
        : 0.0;
    final delta = capacitor.peakRechargeRate - capacitor.peakUseRate;

    return ListTile(
      minTileHeight: 0,
      leading: efaIconImage(EfaAssets.attrCapacitorCharge, height: 28),
      title: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (!stable && capacitor.hasDepletesInS())
                  Text(
                    Duration(seconds: capacitor.depletesInS.round()).format(),
                    style: const TextStyle(color: Colors.red),
                  )
                else if (stable)
                  Text(
                    l10n.capacitorStable(percent: percent.toStringAsFixed(1)),
                    style: const TextStyle(color: Colors.green),
                  )
                else
                  Text(l10n.capacitorUnstable, style: const TextStyle(color: Colors.red)),
                const Text(" | "),
                Text(
                  "${delta.isNegative ? "-" : "+"}${delta.abs().toStringAsMaxDecimals(2)} GJ/s",
                  style: TextStyle(color: delta.isNegative ? Colors.red : Colors.green),
                ),
                const Text(" | "),
                Text("${capacitor.capacityGj.round()} GJ"),
              ],
            ),
            const SizedBox(height: 4),
            ResourceBar(
              used: percent,
              all: 100,
              warning: false,
              trackColor: stable ? null : Colors.red.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeaponsSection extends StatelessWidget {
  const _WeaponsSection({required this.weapons});

  final SnapshotStatistics_Weapons weapons;

  @override
  Widget build(BuildContext context) => ListTile(
    minTileHeight: 0,
    leading: efaIconImage(EfaAssets.attrDamageAlpha, height: 28),
    title: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 16),
      child: Wrap(
        alignment: WrapAlignment.end,
        children: [
          Text("${weapons.dpsTotal.toStringAsFixed(1)}/s"),
          const Text(" | "),
          Text("${weapons.dpsWithReload.toStringAsFixed(1)}/s"),
          const Text(" | "),
          Text(weapons.alphaVolley.toStringAsFixed(1)),
        ],
      ),
    ),
  );
}

class _ResourcesSection extends StatelessWidget {
  const _ResourcesSection({required this.resources});

  final SnapshotStatistics_Resources resources;

  Widget _row(
    ImageProvider<Object> icon,
    double used,
    double all, {
    String? unit,
    bool warning = true,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      efaIconImage(icon, height: 28),
      const SizedBox(width: 12),
      Expanded(
        child: ResourceCompare(
          used: used,
          all: all,
          unit: unit,
          align: TextAlign.end,
          warning: warning,
          bar: true,
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: 20, right: 22, top: 8, bottom: 8),
    child: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 16),
      child: Column(
        spacing: 10,
        children: [
          _row(EfaAssets.attrCpu, resources.cpuUsed, resources.cpuTotal, unit: "tf"),
          _row(EfaAssets.attrPower, resources.powergridUsed, resources.powergridTotal, unit: "MW"),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: _row(
                  EfaAssets.attrRig,
                  resources.calibrationUsed,
                  resources.calibrationTotal,
                  warning: false,
                ),
              ),
              Expanded(
                child: _row(
                  EfaAssets.attrWeaponDrone,
                  resources.droneBandwidthUsed,
                  resources.droneBandwidthTotal,
                  unit: "MB/s",
                  warning: false,
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _DefenseSection extends StatelessWidget {
  const _DefenseSection({required this.snapshot});

  final FitSnapshot snapshot;

  TableRow _layerRow(ImageProvider<Object> icon, SnapshotStatistics_DefenseLayer layer) => TableRow(
    children: [
      efaIconImage(icon, height: 28),
      Text(layer.hp.toStringAsFixed(0)),
      Text(layer.ehp.toStringAsFixed(0)),
      ResonanceBox(ratio: 1 - layer.resistances.em, type: ResonanceType.em),
      ResonanceBox(ratio: 1 - layer.resistances.thermal, type: ResonanceType.thermal),
      ResonanceBox(ratio: 1 - layer.resistances.kinetic, type: ResonanceType.kinetic),
      ResonanceBox(ratio: 1 - layer.resistances.explosive, type: ResonanceType.explosive),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final stats = snapshot.statistics;
    final profile = snapshot.damageProfile;
    final hpTotal = stats.shield.hp + stats.armor.hp + stats.hull.hp;
    final ehpTotal = stats.shield.ehp + stats.armor.ehp + stats.hull.ehp;

    final maxEhpIcon = stats.shield.ehp >= stats.armor.ehp && stats.shield.ehp >= stats.hull.ehp
        ? EfaAssets.attrHpShield
        : stats.armor.ehp >= stats.hull.ehp
        ? EfaAssets.attrHpArmor
        : EfaAssets.attrHpHull;

    return Column(
      children: [
        ListTile(
          minTileHeight: 0,
          leading: efaIconImage(maxEhpIcon, height: 36),
          title: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 16),
            child: Wrap(
              alignment: WrapAlignment.end,
              children: [
                Text("${hpTotal.toStringAsFixed(0)} HP | ${ehpTotal.toStringAsFixed(0)} EHP"),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
            child: Table(
              columnWidths: const {
                0: FixedColumnWidth(28),
                1: FlexColumnWidth(),
                2: FlexColumnWidth(),
                3: FlexColumnWidth(),
                4: FlexColumnWidth(),
                5: FlexColumnWidth(),
                6: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  children: [
                    const SizedBox.shrink(),
                    const Text("HP"),
                    const Text("EHP"),
                    efaIconImage(EfaAssets.attrDmgEmResistance, height: 28),
                    efaIconImage(EfaAssets.attrDmgThermalResistance, height: 28),
                    efaIconImage(EfaAssets.attrDmgKineticResistance, height: 28),
                    efaIconImage(EfaAssets.attrDmgExplosiveResistance, height: 28),
                  ],
                ),
                _layerRow(EfaAssets.attrHpShield, stats.shield),
                _layerRow(EfaAssets.attrHpArmor, stats.armor),
                _layerRow(EfaAssets.attrHpHull, stats.hull),
                TableRow(
                  children: [
                    efaIconImage(EfaAssets.attrWeaponTurret, height: 28),
                    const SizedBox.shrink(),
                    const SizedBox.shrink(),
                    ResonanceBox(ratio: 1 - profile.em, type: ResonanceType.em),
                    ResonanceBox(ratio: 1 - profile.thermal, type: ResonanceType.thermal),
                    ResonanceBox(ratio: 1 - profile.kinetic, type: ResonanceType.kinetic),
                    ResonanceBox(ratio: 1 - profile.explosive, type: ResonanceType.explosive),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MobilityTargetingSection extends StatelessWidget {
  const _MobilityTargetingSection({required this.stats});

  final SnapshotStatistics stats;

  (ImageProvider<Object>, double) _maxSensor() {
    final targeting = stats.targeting;
    final radar = targeting.radarStrength;
    final ladar = targeting.ladarStrength;
    final magnetometric = targeting.magnetometricStrength;
    final gravimetric = targeting.gravimetricStrength;
    if (radar >= ladar && radar >= magnetometric && radar >= gravimetric) {
      return (EfaAssets.attrScanRadar, radar);
    } else if (ladar >= magnetometric && ladar >= gravimetric) {
      return (EfaAssets.attrScanLadar, ladar);
    } else if (magnetometric >= gravimetric) {
      return (EfaAssets.attrScanMagnetometric, magnetometric);
    }
    return (EfaAssets.attrScanGravimetric, gravimetric);
  }

  @override
  Widget build(BuildContext context) {
    final mobility = stats.mobility;
    final targeting = stats.targeting;
    final sensor = _maxSensor();

    return Container(
      padding: const EdgeInsets.only(left: 14, right: 22, top: 8, bottom: 8),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.end,
        child: Table(
          columnWidths: const {
            0: FixedColumnWidth(28),
            1: FlexColumnWidth(),
            2: FixedColumnWidth(10),
            3: FixedColumnWidth(28),
            4: FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            TableRow(
              children: [
                efaIconImage(EfaAssets.attrSpeed, height: 28),
                Text("${mobility.maxVelocityMs.toStringAsMaxDecimals(1)} m/s"),
                const SizedBox.shrink(),
                efaIconImage(EfaAssets.attrWarpSpeed, height: 28),
                Text("${mobility.warpSpeedAuS.toStringAsMaxDecimals(1)} AU/s"),
              ],
            ),
            TableRow(
              children: [
                efaIconImage(EfaAssets.attrTargetRange, height: 28),
                Text("${(targeting.maxTargetRangeM / 1000).toStringAsFixed(0)} km"),
                const SizedBox.shrink(),
                efaIconImage(EfaAssets.attrScanResolution, height: 28),
                Text("${targeting.scanResolutionMm.toStringAsFixed(0)} mm"),
              ],
            ),
            TableRow(
              children: [
                efaIconImage(EfaAssets.attrLockNum, height: 28),
                Text("${targeting.maxLockedTargets}"),
                const SizedBox.shrink(),
                efaIconImage(sensor.$1, height: 28),
                Text(sensor.$2.toStringAsMaxDecimals(1)),
              ],
            ),
            TableRow(
              children: [
                efaIconImage(EfaAssets.attrAlignTime, height: 28),
                Text("${mobility.alignTimeS.toStringAsMaxDecimals(2)} s"),
                const SizedBox.shrink(),
                efaIconImage(EfaAssets.attrSignatureRadius, height: 28),
                Text("${mobility.signatureRadiusM.toStringAsMaxDecimals(0)} m"),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DronesSection extends StatelessWidget {
  const _DronesSection({required this.drones});

  final SnapshotStatistics_Drones drones;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: 14, right: 22, top: 8, bottom: 8),
    child: DefaultTextStyle.merge(
      style: const TextStyle(fontSize: 16),
      textAlign: TextAlign.end,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(28),
          1: FlexColumnWidth(),
          2: FixedColumnWidth(10),
          3: FixedColumnWidth(28),
          4: FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              efaIconImage(EfaAssets.attrDrone, height: 28),
              Text("${drones.maxActiveDrones}"),
              const SizedBox.shrink(),
              efaIconImage(EfaAssets.attrDroneRange, height: 28),
              Text("${(drones.controlRangeM / 1000).toStringAsMaxDecimals(1)} km"),
            ],
          ),
        ],
      ),
    ),
  );
}

class _CargoSection extends StatelessWidget {
  const _CargoSection({required this.cargo});

  final SnapshotStatistics_Cargo cargo;

  ImageProvider<Object> _holdIcon(SnapshotStatistics_Cargo_HoldKind kind) => switch (kind) {
    SnapshotStatistics_Cargo_HoldKind.FLEET_HANGAR => EfaAssets.cargoFleet,
    SnapshotStatistics_Cargo_HoldKind.SHIP_MAINTENANCE_BAY => EfaAssets.cargoShip,
    SnapshotStatistics_Cargo_HoldKind.FIGHTER_BAY => EfaAssets.attrWeaponDrone,
    SnapshotStatistics_Cargo_HoldKind.MINING_HOLD => EfaAssets.cargoOre,
    SnapshotStatistics_Cargo_HoldKind.GAS_HOLD => EfaAssets.cargoGas,
    SnapshotStatistics_Cargo_HoldKind.MINERAL_HOLD => EfaAssets.cargoMineral,
    SnapshotStatistics_Cargo_HoldKind.ICE_HOLD => EfaAssets.cargoIce,
    SnapshotStatistics_Cargo_HoldKind.COMMAND_CENTER_HOLD => EfaAssets.cargoCommandCenter,
    SnapshotStatistics_Cargo_HoldKind.PLANETARY_COMMODITIES_HOLD =>
      EfaAssets.cargoPlanetaryMaterials,
    SnapshotStatistics_Cargo_HoldKind.FUEL_BAY => EfaAssets.cargoFuel,
    SnapshotStatistics_Cargo_HoldKind.AMMO_HOLD => EfaAssets.attrDamageAlpha,
    _ => EfaAssets.attrCargoCapacity,
  };

  Widget _tile(ImageProvider<Object> icon, String value, {ImageProvider<Object>? secondIcon}) =>
      ListTile(
        minTileHeight: 0,
        minVerticalPadding: 0,
        leading: secondIcon == null
            ? efaIconImage(icon, height: 28)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  efaIconImage(icon, height: 28),
                  const SizedBox(width: 6),
                  efaIconImage(secondIcon, height: 28),
                ],
              ),
        title: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.end,
          child: Text(value),
        ),
      );

  @override
  Widget build(BuildContext context) => Column(
    spacing: 10,
    children: [
      _tile(EfaAssets.attrMass, "${cargo.massKg.round().commaSeparated} kg"),
      _tile(EfaAssets.attrCargoCapacity, "${cargo.capacityM3.round().commaSeparated} m³"),
      for (final hold in cargo.holds)
        _tile(
          EfaAssets.attrCargoCapacity,
          "${hold.capacityM3.round().commaSeparated} m³",
          secondIcon: _holdIcon(hold.kind),
        ),
    ],
  );
}
