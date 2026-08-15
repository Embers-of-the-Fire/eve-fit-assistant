import "package:efa_component/efa_component.dart";
import "package:efa_fit/efa_fit.dart";
import "package:efa_fit_snapshot/src/l10n.dart";
import "package:efa_fit_snapshot/src/widgets/slot_rows.dart";
import "package:flutter/material.dart";

/// Equipment column: ship tile, tactical mode, racks, drones and fighters.
class SnapshotEquipmentColumn extends StatelessWidget {
  const SnapshotEquipmentColumn({required this.snapshot, super.key});

  final FitSnapshot snapshot;

  ImageProvider _subsystemPlaceholder(Subsystem_SubsystemType type) => switch (type) {
    Subsystem_SubsystemType.CORE => EfaAssets.slotSubsystemCore,
    Subsystem_SubsystemType.DEFENSIVE => EfaAssets.slotSubsystemDefensive,
    Subsystem_SubsystemType.OFFENSIVE => EfaAssets.slotSubsystemOffensive,
    Subsystem_SubsystemType.PROPULSION => EfaAssets.slotSubsystemPropulsion,
    _ => EfaAssets.slotSubsystem,
  };

  List<Widget> _rack(
    BuildContext context, {
    required String title,
    required List<SnapshotSlot> slots,
    required ImageProvider placeholder,
    List<Widget> trailing = const [],
  }) {
    final l10n = context.snapshotL10n;
    return [
      EfaSectionHeader(title: title, trailing: trailing),
      for (final slot in slots)
        slot.hasItem()
            ? SnapshotModuleRow(module: slot.item)
            : SnapshotEmptySlotRow(index: slot.index, slotName: title, placeholder: placeholder),
      // satisfy l10n usage when title builders differ
      if (slots.isEmpty) ListTile(title: Text(l10n.slotEmpty(slotName: title))),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.snapshotL10n;
    final ship = snapshot.ship;
    final layout = ship.layout;

    var usedTurret = 0;
    var usedLauncher = 0;
    for (final slot in snapshot.highSlots) {
      if (!slot.hasItem()) continue;
      if (slot.item.hasIsTurret() && slot.item.isTurret) usedTurret += 1;
      if (slot.item.hasIsLauncher() && slot.item.isLauncher) usedLauncher += 1;
    }

    final stats = snapshot.hasStatistics() ? snapshot.statistics : null;

    final fighters = snapshot.fighters;
    var light = 0;
    var heavy = 0;
    var support = 0;
    for (final fighter in fighters) {
      switch (fighter.group) {
        case SnapshotFighter_SquadronGroup.LIGHT:
          light += 1;
        case SnapshotFighter_SquadronGroup.HEAVY:
          heavy += 1;
        case SnapshotFighter_SquadronGroup.SUPPORT:
          support += 1;
        default:
          break;
      }
    }
    final fighterBay = stats?.cargo.holds
        .where((h) => h.kind == SnapshotStatistics_Cargo_HoldKind.FIGHTER_BAY)
        .firstOrNull;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (snapshot.hasTacticalMode()) ...[
          EfaSectionHeader(title: l10n.tacticalMode),
          SnapshotTacticalModeRow(mode: snapshot.tacticalMode),
        ],
        ..._rack(
          context,
          title: l10n.highSlot,
          slots: snapshot.highSlots,
          placeholder: EfaAssets.slotHigh,
          trailing: [
            if (layout.turretHardpoints > 0 || usedTurret > 0)
              HeaderIconCounter(
                icon: EfaAssets.weaponTurretNum,
                count: usedTurret,
                total: layout.turretHardpoints,
              ),
            if (layout.launcherHardpoints > 0 || usedLauncher > 0)
              HeaderIconCounter(
                icon: EfaAssets.weaponLauncherNum,
                count: usedLauncher,
                total: layout.launcherHardpoints,
              ),
          ],
        ),
        ..._rack(
          context,
          title: l10n.midSlot,
          slots: snapshot.mediumSlots,
          placeholder: EfaAssets.slotMedium,
        ),
        ..._rack(
          context,
          title: l10n.lowSlot,
          slots: snapshot.lowSlots,
          placeholder: EfaAssets.slotLow,
        ),
        ..._rack(
          context,
          title: l10n.rigSlot,
          slots: snapshot.rigSlots,
          placeholder: EfaAssets.slotRig,
        ),
        if (snapshot.subsystemSlots.isNotEmpty) ...[
          EfaSectionHeader(title: l10n.subsystemSlot),
          for (final slot in snapshot.subsystemSlots)
            slot.hasItem()
                ? SnapshotModuleRow(module: slot.item)
                : SnapshotEmptySlotRow(
                    index: slot.index,
                    slotName: l10n.subsystemSlot,
                    placeholder: _subsystemPlaceholder(slot.subsystemType),
                  ),
        ],
        if (snapshot.serviceSlots.isNotEmpty)
          ..._rack(
            context,
            title: l10n.serviceSlot,
            slots: snapshot.serviceSlots,
            placeholder: EfaAssets.slotService,
          ),
        EfaSectionHeader(
          title: l10n.drone,
          trailing: [
            if (stats != null && (stats.drones.bayCapacityM3 > 0 || stats.drones.bayUsedM3 > 0))
              CapacityCounter(
                count: stats.drones.bayUsedM3.round(),
                total: stats.drones.bayCapacityM3.round(),
                suffix: "m³",
              ),
          ],
        ),
        if (snapshot.drones.isEmpty) ListTile(title: Text(l10n.slotEmpty(slotName: l10n.drone))),
        for (final drone in snapshot.drones) SnapshotDroneRow(drone: drone),
        if (layout.fighterTubes > 0) ...[
          EfaSectionHeader(title: l10n.fighter),
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              spacing: 10,
              children: [
                if (heavy > 0) Text("H $heavy"),
                if (light > 0) Text("L $light"),
                if (support > 0) Text("S $support"),
                CapacityCounter(count: fighters.length, total: layout.fighterTubes, suffix: "x"),
                if (fighterBay != null) Text("${fighterBay.capacityM3.round().commaSeparated} m³"),
              ],
            ),
          ),
          const Divider(),
          if (fighters.isEmpty) ListTile(title: Text(l10n.slotEmpty(slotName: l10n.fighter))),
          for (final fighter in fighters) SnapshotFighterRow(fighter: fighter),
        ],
      ],
    );
  }
}
