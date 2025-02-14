part of 'fit.dart';

class EquipmentTab extends StatelessWidget {
  final String fitID;
  final Ship ship;
  final List<SlotItem?> high;
  final List<SlotItem?> med;
  final List<SlotItem?> low;
  final List<SlotItem?> rig;
  final List<SlotItem?> subsystem;

  final ScrollController _controller = ScrollController();

  EquipmentTab({
    super.key,
    required this.fitID,
    required this.ship,
    required this.high,
    required this.med,
    required this.low,
    required this.rig,
    required this.subsystem,
  });

  @override
  Widget build(BuildContext context) {
    final sumTurret = high
        .filterMap((item) => item)
        .filterMap((item) => GlobalStorage().static.typeSlot.high[item.itemID])
        .filter((item) => item.isTurret)
        .count();
    final sumLauncher = high
        .filterMap((item) => item)
        .filterMap((item) => GlobalStorage().static.typeSlot.high[item.itemID])
        .filter((item) => item.isLauncher)
        .count();

    return ListView(
      controller: _controller,
      children: <Widget>[
        ListTile(
          title: const Text('高能量槽'),
          trailing: Text(
            '炮塔 $sumTurret/${ship.turretSlotNum}'
            ' | 发射器 $sumLauncher/${ship.launcherSlotNum}',
            style: const TextStyle(fontSize: 14),
          ),
        ),
        ...high.enumerate().map((t) => getSlotRow(fitID, t.$2,
            type: FitItemType.high, index: t.$1, slotType: FitItemType.high)),
        const ListTile(title: Text('中能量槽')),
        ...med.enumerate().map((t) =>
            getSlotRow(fitID, t.$2, type: FitItemType.med, index: t.$1, slotType: FitItemType.med)),
        const ListTile(title: Text('低能量槽')),
        ...low.enumerate().map((t) =>
            getSlotRow(fitID, t.$2, type: FitItemType.low, index: t.$1, slotType: FitItemType.low)),
        const ListTile(title: Text('改装件')),
        ...rig.enumerate().map((t) =>
            getSlotRow(fitID, t.$2, type: FitItemType.rig, index: t.$1, slotType: FitItemType.rig)),
        ...subsystem.isNotEmpty.then(() => [const ListTile(title: Text('子系统'))]).unwrapOr([]),
        ...subsystem.enumerate().map((t) => getSlotRow(fitID, t.$2,
            type: FitItemType.subsystem, index: t.$1, slotType: FitItemType.subsystem)),
      ],
    );
  }
}
