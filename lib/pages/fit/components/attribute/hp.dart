part of "../../page.dart";

class Hp extends StatefulWidget {
  const Hp({required this.ship, super.key});
  final native.Ship ship;

  @override
  State<Hp> createState() => _HpState();
}

class _HpState extends State<Hp> {
  bool displayEhp = false;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        minTileHeight: 0,
        leading: _getMaxEhpIcon(widget.ship.hull),
        title: DefaultTextStyle(
          style: const TextStyle(fontSize: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [_getEhpText(widget.ship.hull, displayEhp)],
          ),
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 20),
        child: _HpTable(
          onToggle: () => setState(() {
            displayEhp = !displayEhp;
          }),
          hull: widget.ship.hull,
          displayEhp: displayEhp,
          damageProfile: widget.ship.damageProfile,
        ),
      ),
      Container(
        padding: const EdgeInsets.only(right: 20, left: 20, bottom: 8),
        child: _RepairTable(hull: widget.ship.hull, displayEhp: displayEhp),
      ),
    ],
  );
}

Image _getMaxEhpIcon(native.Item hull) {
  final shieldHp = hull.getAttribute(EveConstExtendedAttrID.shieldEhp);
  final armorHp = hull.getAttribute(EveConstExtendedAttrID.armorEhp);
  final hullHp = hull.getAttribute(EveConstExtendedAttrID.hullEhp);

  if (shieldHp >= armorHp && shieldHp >= hullHp) {
    return const Image(image: ImageAssets.attrHpShield, height: 36);
  } else if (armorHp >= shieldHp && armorHp >= hullHp) {
    return const Image(image: ImageAssets.attrHpArmor, height: 36);
  } else {
    return const Image(image: ImageAssets.attrHpHull, height: 36);
  }
}

Text _getEhpText(native.Item hull, bool expFirst) {
  final ehpNum = hull.getAttribute(EveConstExtendedAttrID.ehp);
  final hpNum =
      hull.getAttribute(EveConstAttrID.hp) +
      hull.getAttribute(EveConstAttrID.armorHP) +
      hull.getAttribute(EveConstAttrID.shieldCapacity);
  if (expFirst) {
    return Text("${ehpNum.toStringAsFixed(0)} EHP | ${hpNum.toStringAsFixed(0)} HP");
  } else {
    return Text("${hpNum.toStringAsFixed(0)} HP | ${ehpNum.toStringAsFixed(0)} EHP");
  }
}

class _HpTable extends ConsumerWidget {
  const _HpTable({
    required this.hull,
    required this.displayEhp,
    required this.damageProfile,
    required this.onToggle,
  });
  final native.Item hull;
  final bool displayEhp;
  final native_storage.DamageProfile damageProfile;

  final void Function() onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) => DefaultTextStyle(
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
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: <TableRow>[
        TableRow(
          children: [
            InkWell(onTap: onToggle, child: const Icon(Icons.compare_arrows)),
            Text(displayEhp ? "EHP" : "HP"),
            const Image(image: ImageAssets.attrDmgEmResistance, height: 28),
            const Image(image: ImageAssets.attrDmgThermalResistance, height: 28),
            const Image(image: ImageAssets.attrDmgKineticResistance, height: 28),
            const Image(image: ImageAssets.attrDmgExplosiveResistance, height: 28),
          ],
        ),
        TableRow(
          children: [
            const Image(image: ImageAssets.attrHpShield, height: 28),
            Text(
              displayEhp
                  ? hull.getAttribute(EveConstExtendedAttrID.shieldEhp).toStringAsFixed(0)
                  : hull.getAttribute(EveConstAttrID.shieldCapacity).toStringAsFixed(0),
            ),
            ResonanceBox(
              ratio: hull.getAttribute(EveConstAttrID.shieldEmDamageResonance),
              type: ResonanceType.em,
            ),
            ResonanceBox(
              ratio: hull.getAttribute(EveConstAttrID.shieldThermalDamageResonance),
              type: ResonanceType.thermal,
            ),
            ResonanceBox(
              ratio: hull.getAttribute(EveConstAttrID.shieldKineticDamageResonance),
              type: ResonanceType.kinetic,
            ),
            ResonanceBox(
              ratio: hull.getAttribute(EveConstAttrID.shieldExplosiveDamageResonance),
              type: ResonanceType.explosive,
            ),
          ],
        ),
        TableRow(
          children: [
            const Image(image: ImageAssets.attrHpArmor, height: 28),
            Text(
              displayEhp
                  ? hull.getAttribute(EveConstExtendedAttrID.armorEhp).toStringAsFixed(0)
                  : hull.getAttribute(EveConstAttrID.armorHP).toStringAsFixed(0),
            ),
            ResonanceBox(
              ratio: hull.getAttribute(EveConstAttrID.armorEmDamageResonance),
              type: ResonanceType.em,
            ),
            ResonanceBox(
              ratio: hull.getAttribute(EveConstAttrID.armorThermalDamageResonance),
              type: ResonanceType.thermal,
            ),
            ResonanceBox(
              ratio: hull.getAttribute(EveConstAttrID.armorKineticDamageResonance),
              type: ResonanceType.kinetic,
            ),
            ResonanceBox(
              ratio: hull.getAttribute(EveConstAttrID.armorExplosiveDamageResonance),
              type: ResonanceType.explosive,
            ),
          ],
        ),
        TableRow(
          children: [
            const Image(image: ImageAssets.attrHpHull, height: 28),
            Text(
              displayEhp
                  ? hull.getAttribute(EveConstExtendedAttrID.hullEhp).toStringAsFixed(0)
                  : hull.getAttribute(EveConstAttrID.hp).toStringAsFixed(0),
            ),
            ResonanceBox(
              ratio: hull.getAttribute(EveConstAttrID.emDamageResonance),
              type: ResonanceType.em,
            ),
            ResonanceBox(
              ratio: hull.getAttribute(EveConstAttrID.thermalDamageResonance),
              type: ResonanceType.thermal,
            ),
            ResonanceBox(
              ratio: hull.getAttribute(EveConstAttrID.kineticDamageResonance),
              type: ResonanceType.kinetic,
            ),
            ResonanceBox(
              ratio: hull.getAttribute(EveConstAttrID.explosiveDamageResonance),
              type: ResonanceType.explosive,
            ),
          ],
        ),
        TableRow(
          children: [
            const Image(image: ImageAssets.attrWeaponTurret, height: 28),
            const Icon(Icons.settings),
            ResonanceBox(ratio: 1 - damageProfile.em, type: ResonanceType.em),
            ResonanceBox(ratio: 1 - damageProfile.thermal, type: ResonanceType.thermal),
            ResonanceBox(ratio: 1 - damageProfile.kinetic, type: ResonanceType.kinetic),
            ResonanceBox(ratio: 1 - damageProfile.explosive, type: ResonanceType.explosive),
          ],
        ),
      ],
    ),
  );
}

class _RepairTable extends StatelessWidget {
  const _RepairTable({required this.hull, required this.displayEhp});
  final native.Item hull;
  final bool displayEhp;

  @override
  Widget build(BuildContext context) {
    final double shieldAutoRepair;
    final double shieldRepair;
    final double armorRepair;
    final double hullRepair;

    if (displayEhp) {
      shieldAutoRepair = hull.getAttribute(
        EveConstExtendedAttrID.passiveShieldEffectiveRechargeRate,
      );
      shieldRepair = hull.getAttribute(EveConstExtendedAttrID.shieldEffectiveBoostRate);
      armorRepair = hull.getAttribute(EveConstExtendedAttrID.armorEffectiveRepairRate);
      hullRepair = hull.getAttribute(EveConstExtendedAttrID.hullEffectiveRepairRate);
    } else {
      shieldAutoRepair = hull.getAttribute(EveConstExtendedAttrID.passiveShieldRechargeRate);
      shieldRepair = hull.getAttribute(EveConstExtendedAttrID.shieldBoostRate);
      armorRepair = hull.getAttribute(EveConstExtendedAttrID.armorRepairRate);
      hullRepair = hull.getAttribute(EveConstExtendedAttrID.hullRepairRate);
    }

    final double remoteCapacitor = hull.getAttribute(
      EveConstExtendedAttrID.remoteCapacitorTransmitterRate,
    );
    final double remoteShield = hull.getAttribute(EveConstExtendedAttrID.shieldRemoteBoostRate);
    final double remoteArmor = hull.getAttribute(EveConstExtendedAttrID.armorRemoteRepairRate);
    final double remoteHull = hull.getAttribute(EveConstExtendedAttrID.hullRemoteRepairRate);

    return DefaultTextStyle(
      style: const TextStyle(fontSize: 16),
      textAlign: TextAlign.center,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: <TableRow>[
          const TableRow(
            children: [
              Image(image: ImageAssets.attrRepairShieldAuto, height: 32),
              Image(image: ImageAssets.attrRepairShield, height: 32),
              Image(image: ImageAssets.attrRepairArmor, height: 32),
              Image(image: ImageAssets.attrRepairHull, height: 32),
            ],
          ),
          TableRow(
            children: [
              Text("${shieldAutoRepair.toStringAsFixed(1)} /s"),
              Text("${shieldRepair.toStringAsFixed(1)} /s"),
              Text("${armorRepair.toStringAsFixed(1)} /s"),
              Text("${hullRepair.toStringAsFixed(1)} /s"),
            ],
          ),
          const TableRow(
            children: [
              Image(image: ImageAssets.attrRemoteCapacitor, height: 32),
              Image(image: ImageAssets.attrRemoteShield, height: 32),
              Image(image: ImageAssets.attrRemoteArmor, height: 32),
              Image(image: ImageAssets.attrRemoteHull, height: 32),
            ],
          ),
          TableRow(
            children: [
              Text("${remoteCapacitor.toStringAsFixed(1)} GJ/s"),
              Text("${remoteShield.toStringAsFixed(1)} /s"),
              Text("${remoteArmor.toStringAsFixed(1)} /s"),
              Text("${remoteHull.toStringAsFixed(1)} /s"),
            ],
          ),
        ],
      ),
    );
  }
}
