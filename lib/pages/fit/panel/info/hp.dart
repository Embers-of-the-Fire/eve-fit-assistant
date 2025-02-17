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
  final shieldHp = hull.attributes.getById(key: shieldEhp) ?? 0.0;
  final armorHp = hull.attributes.getById(key: armorEhp) ?? 0.0;
  final hullHp = hull.attributes.getById(key: hullEhp) ?? 0.0;

  if (shieldHp >= armorHp && shieldHp >= hullHp) {
    return const Image(image: hpShieldImage, height: 36);
  } else if (armorHp >= shieldHp && armorHp >= hullHp) {
    return const Image(image: hpArmorImage, height: 36);
  } else {
    return const Image(image: hpHullImage, height: 36);
  }
}

Text _getEhpText(ItemProxy hull, bool expFirst) {
  final ehpNum = hull.attributes.getById(key: ehp) ?? 0.0;
  final hpNum = (hull.attributes.getById(key: hp) ?? 0.0) +
      (hull.attributes.getById(key: armorHP) ?? 0.0) +
      (hull.attributes.getById(key: shieldCapacity) ?? 0.0);
  if (expFirst) {
    return Text('${ehpNum.toStringAsFixed(0)} EHP | ${hpNum.toStringAsFixed(0)} HP');
  } else {
    return Text('${hpNum.toStringAsFixed(0)} HP | ${ehpNum.toStringAsFixed(0)} EHP');
  }
}

class _HpTable extends StatelessWidget {
  final ItemProxy hull;
  final bool displayEhp;
  final void Function() onToggle;

  const _HpTable({
    required this.hull,
    required this.displayEhp,
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
                  ? (hull.attributes.getById(key: shieldEhp) ?? 0.0).toStringAsFixed(0)
                  : (hull.attributes.getById(key: shieldCapacity) ?? 0.0).toStringAsFixed(0)),
              ResonanceBox(
                ratio: hull.attributes.getById(key: shieldEmDamageResonance) ?? 0.0,
                type: ResonanceType.em,
              ),
              ResonanceBox(
                ratio: hull.attributes.getById(key: shieldThermalDamageResonance) ?? 0.0,
                type: ResonanceType.thermal,
              ),
              ResonanceBox(
                ratio: hull.attributes.getById(key: shieldKineticDamageResonance) ?? 0.0,
                type: ResonanceType.kinetic,
              ),
              ResonanceBox(
                ratio: hull.attributes.getById(key: shieldExplosiveDamageResonance) ?? 0.0,
                type: ResonanceType.explosive,
              ),
            ]),
            TableRow(children: [
              const Image(image: hpArmorImage, height: 28),
              Text(displayEhp
                  ? (hull.attributes.getById(key: armorEhp) ?? 0.0).toStringAsFixed(0)
                  : (hull.attributes.getById(key: armorHP) ?? 0.0).toStringAsFixed(0)),
              ResonanceBox(
                ratio: hull.attributes.getById(key: armorEmDamageResonance) ?? 0.0,
                type: ResonanceType.em,
              ),
              ResonanceBox(
                ratio: hull.attributes.getById(key: armorThermalDamageResonance) ?? 0.0,
                type: ResonanceType.thermal,
              ),
              ResonanceBox(
                ratio: hull.attributes.getById(key: armorKineticDamageResonance) ?? 0.0,
                type: ResonanceType.kinetic,
              ),
              ResonanceBox(
                ratio: hull.attributes.getById(key: armorExplosiveDamageResonance) ?? 0.0,
                type: ResonanceType.explosive,
              ),
            ]),
            TableRow(children: [
              const Image(image: hpHullImage, height: 28),
              Text(displayEhp
                  ? (hull.attributes.getById(key: hullEhp) ?? 0.0).toStringAsFixed(0)
                  : (hull.attributes.getById(key: hp) ?? 0.0).toStringAsFixed(0)),
              ResonanceBox(
                ratio: hull.attributes.getById(key: emDamageResonance) ?? 0.0,
                type: ResonanceType.em,
              ),
              ResonanceBox(
                ratio: hull.attributes.getById(key: thermalDamageResonance) ?? 0.0,
                type: ResonanceType.thermal,
              ),
              ResonanceBox(
                ratio: hull.attributes.getById(key: kineticDamageResonance) ?? 0.0,
                type: ResonanceType.kinetic,
              ),
              ResonanceBox(
                ratio: hull.attributes.getById(key: explosiveDamageResonance) ?? 0.0,
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
      shieldAutoRepair = hull.attributes.getById(key: passiveShieldEffectiveRechargeRate) ?? 0.0;
      shieldRepair = hull.attributes.getById(key: shieldEffectiveBoostRate) ?? 0.0;
      armorRepair = hull.attributes.getById(key: armorEffectiveRepairRate) ?? 0.0;
      hullRepair = hull.attributes.getById(key: hullEffectiveRepairRate) ?? 0.0;
    } else {
      shieldAutoRepair = hull.attributes.getById(key: passiveShieldRechargeRate) ?? 0.0;
      shieldRepair = hull.attributes.getById(key: shieldBoostRate) ?? 0.0;
      armorRepair = hull.attributes.getById(key: armorRepairRate) ?? 0.0;
      hullRepair = hull.attributes.getById(key: hullRepairRate) ?? 0.0;
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
