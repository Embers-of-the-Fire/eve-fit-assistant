part of 'fit.dart';

class EquipmentTab extends ConsumerWidget {
  final String fitID;
  final Ship ship;

  final ScrollController _controller = ScrollController();

  EquipmentTab({
    super.key,
    required this.fitID,
    required this.ship,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.watch(fitRecordNotifierProvider(fitID));
    final fitBody = fit.fit.body;

    final sumTurret = fitBody.high
        .filterMap((item) => item)
        .filterMap((item) => GlobalStorage().static.typeSlot.high[item.itemID])
        .filter((item) => item.isTurret)
        .count();
    final sumLauncher = fitBody.high
        .filterMap((item) => item)
        .filterMap((item) => GlobalStorage().static.typeSlot.high[item.itemID])
        .filter((item) => item.isLauncher)
        .count();

    final allTurret = ship.turretSlotNum +
        fitBody.subsystem
            .filterMap((u) => u?.itemID)
            .filterMap((item) => GlobalStorage().static.subsystems.items[item]?.turret)
            .sum();

    final allLauncher = ship.launcherSlotNum +
        fitBody.subsystem
            .filterMap((u) => u?.itemID)
            .filterMap((item) => GlobalStorage().static.subsystems.items[item]?.launcher)
            .sum();

    return ListView(
      controller: _controller,
      children: <Widget>[
        const ListTile(title: Text('战术模式')),
        ...fitBody.tacticalModeID == null
            ? []
            : [
                TacticalModeSlotRow(
                  fitID: fitID,
                  shipID: fitBody.shipID,
                  modeID: fitBody.tacticalModeID!,
                )
              ],
        ListTile(
          title: const Text('高能量槽'),
          trailing: Text(
            '炮塔 $sumTurret/$allTurret'
            ' | 发射器 $sumLauncher/$allLauncher',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        ...fitBody.high
            .enumerate()
            .map((t) => getSlotRow(fitID, t.$2, type: FitItemType.high, index: t.$1)),
        const ListTile(title: Text('中能量槽')),
        ...fitBody.med
            .enumerate()
            .map((t) => getSlotRow(fitID, t.$2, type: FitItemType.med, index: t.$1)),
        const ListTile(title: Text('低能量槽')),
        ...fitBody.low
            .enumerate()
            .map((t) => getSlotRow(fitID, t.$2, type: FitItemType.low, index: t.$1)),
        const ListTile(title: Text('改装件')),
        ...fitBody.rig
            .enumerate()
            .map((t) => getSlotRow(fitID, t.$2, type: FitItemType.rig, index: t.$1)),
        ...fitBody.subsystem.isNotEmpty
            .then(() => [const ListTile(title: Text('子系统'))])
            .unwrapOr([]),
        ...fitBody.subsystem.enumerate().map((t) => getSlotRow(
              fitID,
              t.$2,
              type: FitItemType.subsystem,
              index: t.$1,
            )),
      ],
    );
  }
}
