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

    return ListView(
      controller: _controller,
      children: <Widget>[
        ...fitBody.tacticalModeID == null
            ? []
            : [
                const ListTile(title: Text('战术模式')),
                TacticalModeSlotRow(
                  fitID: fitID,
                  shipID: fitBody.shipID,
                  modeID: fitBody.tacticalModeID!,
                )
              ],
        EquipmentHeader(fitID: fitID, type: FitItemType.high, ship: ship),
        ...fitBody.high
            .enumerate()
            .map((t) => getSlotRow(fitID, t.$2, type: FitItemType.high, index: t.$1)),
        EquipmentHeader(fitID: fitID, type: FitItemType.med, ship: ship),
        ...fitBody.med
            .enumerate()
            .map((t) => getSlotRow(fitID, t.$2, type: FitItemType.med, index: t.$1)),
        EquipmentHeader(fitID: fitID, type: FitItemType.low, ship: ship),
        ...fitBody.low
            .enumerate()
            .map((t) => getSlotRow(fitID, t.$2, type: FitItemType.low, index: t.$1)),
        EquipmentHeader(fitID: fitID, type: FitItemType.rig, ship: ship),
        ...fitBody.rig
            .enumerate()
            .map((t) => getSlotRow(fitID, t.$2, type: FitItemType.rig, index: t.$1)),
        ...fitBody.subsystem.isNotEmpty
            .then(() => [EquipmentHeader(fitID: fitID, type: FitItemType.subsystem, ship: ship)])
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
