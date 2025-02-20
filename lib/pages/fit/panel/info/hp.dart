part of 'info_component.dart';

class Hp extends StatefulWidget {
  final ShipProxy ship;

  const Hp({super.key, required this.ship});

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
          )
        ],
      );
}

Image _getMaxEhpIcon(ItemProxy hull) {
  final shieldHp = hull.attributes[shieldEhp] ?? 0.0;
  final armorHp = hull.attributes[armorEhp] ?? 0.0;
  final hullHp = hull.attributes[hullEhp] ?? 0.0;

  if (shieldHp >= armorHp && shieldHp >= hullHp) {
    return const Image(image: hpShieldImage, height: 36);
  } else if (armorHp >= shieldHp && armorHp >= hullHp) {
    return const Image(image: hpArmorImage, height: 36);
  } else {
    return const Image(image: hpHullImage, height: 36);
  }
}

Text _getEhpText(ItemProxy hull, bool expFirst) {
  final ehpNum = hull.attributes[ehp] ?? 0.0;
  final hpNum = (hull.attributes[hp] ?? 0.0) +
      (hull.attributes[armorHP] ?? 0.0) +
      (hull.attributes[shieldCapacity] ?? 0.0);
  if (expFirst) {
    return Text('${ehpNum.toStringAsFixed(0)} EHP | ${hpNum.toStringAsFixed(0)} HP');
  } else {
    return Text('${hpNum.toStringAsFixed(0)} HP | ${ehpNum.toStringAsFixed(0)} EHP');
  }
}

class _HpTable extends StatelessWidget {
  final ItemProxy hull;
  final bool displayEhp;
  final DamageProfile damageProfile;

  final void Function() onToggle;

  const _HpTable({
    required this.hull,
    required this.displayEhp,
    required this.damageProfile,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => DefaultTextStyle(
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
            TableRow(children: [
              InkWell(onTap: onToggle, child: const Icon(Icons.compare_arrows)),
              Text(displayEhp ? 'EHP' : 'HP'),
              const Image(image: dmgEmResistanceImage, height: 28),
              const Image(image: dmgThermalResistanceImage, height: 28),
              const Image(image: dmgKineticResistanceImage, height: 28),
              const Image(image: dmgExplosiveResistanceImage, height: 28),
            ]),
            TableRow(children: [
              const Image(image: hpShieldImage, height: 28),
              Text(displayEhp
                  ? (hull.attributes[shieldEhp] ?? 0.0).toStringAsFixed(0)
                  : (hull.attributes[shieldCapacity] ?? 0.0).toStringAsFixed(0)),
              ResonanceBox(
                ratio: hull.attributes[shieldEmDamageResonance] ?? 0.0,
                type: ResonanceType.em,
              ),
              ResonanceBox(
                ratio: hull.attributes[shieldThermalDamageResonance] ?? 0.0,
                type: ResonanceType.thermal,
              ),
              ResonanceBox(
                ratio: hull.attributes[shieldKineticDamageResonance] ?? 0.0,
                type: ResonanceType.kinetic,
              ),
              ResonanceBox(
                ratio: hull.attributes[shieldExplosiveDamageResonance] ?? 0.0,
                type: ResonanceType.explosive,
              ),
            ]),
            TableRow(children: [
              const Image(image: hpArmorImage, height: 28),
              Text(displayEhp
                  ? (hull.attributes[armorEhp] ?? 0.0).toStringAsFixed(0)
                  : (hull.attributes[armorHP] ?? 0.0).toStringAsFixed(0)),
              ResonanceBox(
                ratio: hull.attributes[armorEmDamageResonance] ?? 0.0,
                type: ResonanceType.em,
              ),
              ResonanceBox(
                ratio: hull.attributes[armorThermalDamageResonance] ?? 0.0,
                type: ResonanceType.thermal,
              ),
              ResonanceBox(
                ratio: hull.attributes[armorKineticDamageResonance] ?? 0.0,
                type: ResonanceType.kinetic,
              ),
              ResonanceBox(
                ratio: hull.attributes[armorExplosiveDamageResonance] ?? 0.0,
                type: ResonanceType.explosive,
              ),
            ]),
            TableRow(children: [
              const Image(image: hpHullImage, height: 28),
              Text(displayEhp
                  ? (hull.attributes[hullEhp] ?? 0.0).toStringAsFixed(0)
                  : (hull.attributes[hp] ?? 0.0).toStringAsFixed(0)),
              ResonanceBox(
                ratio: hull.attributes[emDamageResonance] ?? 0.0,
                type: ResonanceType.em,
              ),
              ResonanceBox(
                ratio: hull.attributes[thermalDamageResonance] ?? 0.0,
                type: ResonanceType.thermal,
              ),
              ResonanceBox(
                ratio: hull.attributes[kineticDamageResonance] ?? 0.0,
                type: ResonanceType.kinetic,
              ),
              ResonanceBox(
                ratio: hull.attributes[explosiveDamageResonance] ?? 0.0,
                type: ResonanceType.explosive,
              ),
            ]),
            TableRow(children: [
              const Image(image: weaponImage, height: 28),
              const Icon(Icons.settings),
              ResonanceBox(
                ratio: 1 - damageProfile.em,
                type: ResonanceType.em,
              ),
              ResonanceBox(
                ratio: 1 - damageProfile.thermal,
                type: ResonanceType.thermal,
              ),
              ResonanceBox(
                ratio: 1 - damageProfile.kinetic,
                type: ResonanceType.kinetic,
              ),
              ResonanceBox(
                ratio: 1 - damageProfile.explosive,
                type: ResonanceType.explosive,
              ),
            ]),
          ],
        ),
      );
}

class _RepairTable extends StatelessWidget {
  final ItemProxy hull;
  final bool displayEhp;

  const _RepairTable({required this.hull, required this.displayEhp});

  @override
  Widget build(BuildContext context) {
    final double shieldAutoRepair;
    final double shieldRepair;
    final double armorRepair;
    final double hullRepair;

    if (displayEhp) {
      shieldAutoRepair = hull.attributes[passiveShieldEffectiveRechargeRate] ?? 0.0;
      shieldRepair = hull.attributes[shieldEffectiveBoostRate] ?? 0.0;
      armorRepair = hull.attributes[armorEffectiveRepairRate] ?? 0.0;
      hullRepair = hull.attributes[hullEffectiveRepairRate] ?? 0.0;
    } else {
      shieldAutoRepair = hull.attributes[passiveShieldRechargeRate] ?? 0.0;
      shieldRepair = hull.attributes[shieldBoostRate] ?? 0.0;
      armorRepair = hull.attributes[armorRepairRate] ?? 0.0;
      hullRepair = hull.attributes[hullRepairRate] ?? 0.0;
    }

    return DefaultTextStyle(
      style: const TextStyle(fontSize: 16),
      textAlign: TextAlign.center,
      child: Table(
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: <TableRow>[
          const TableRow(children: [
            Image(image: repairShieldAutoImage, height: 32),
            Image(image: repairShieldImage, height: 32),
            Image(image: repairArmorImage, height: 32),
            Image(image: repairHullImage, height: 32),
          ]),
          TableRow(children: [
            Text('${(shieldAutoRepair).toStringAsFixed(1)} /s'),
            Text('${(shieldRepair).toStringAsFixed(1)} /s'),
            Text('${(armorRepair).toStringAsFixed(1)} /s'),
            Text('${(hullRepair).toStringAsFixed(1)} /s'),
          ]),
        ],
      ),
    );
  }
}
