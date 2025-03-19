part of 'fit.dart';

class EquipmentTab extends ConsumerStatefulWidget {
  final String fitID;
  final Ship ship;

  const EquipmentTab({
    super.key,
    required this.fitID,
    required this.ship,
  });

  @override
  ConsumerState createState() => _EquipmentTabState();
}

class _EquipmentTabState extends ConsumerState<EquipmentTab> with AutomaticKeepAliveClientMixin {
  final ScrollController _controller = ScrollController();

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final fit = ref.watch(fitRecordNotifierProvider(widget.fitID));
    final fitBody = fit.fit.body;

    return ListView(
      controller: _controller,
      children: <Widget>[
        ...fitBody.tacticalModeID == null
            ? []
            : [
                const ListTile(title: Text('战术模式')),
                TacticalModeSlotRow(
                  fitID: widget.fitID,
                  shipID: fitBody.shipID,
                  modeID: fitBody.tacticalModeID!,
                )
              ],
        ...getEquipmentHeader(fitID: widget.fitID, type: FitItemType.high, ship: widget.ship),
        ...fitBody.high
            .enumerate()
            .map((t) => getSlotRow(widget.fitID, t.$2, type: FitItemType.high, index: t.$1)),
        ...getEquipmentHeader(fitID: widget.fitID, type: FitItemType.med, ship: widget.ship),
        ...fitBody.med
            .enumerate()
            .map((t) => getSlotRow(widget.fitID, t.$2, type: FitItemType.med, index: t.$1)),
        ...getEquipmentHeader(fitID: widget.fitID, type: FitItemType.low, ship: widget.ship),
        ...fitBody.low
            .enumerate()
            .map((t) => getSlotRow(widget.fitID, t.$2, type: FitItemType.low, index: t.$1)),
        ...getEquipmentHeader(fitID: widget.fitID, type: FitItemType.rig, ship: widget.ship),
        ...fitBody.rig
            .enumerate()
            .map((t) => getSlotRow(widget.fitID, t.$2, type: FitItemType.rig, index: t.$1)),
        ...fitBody.subsystem.isNotEmpty
            .then(() => getEquipmentHeader(
                  fitID: widget.fitID,
                  type: FitItemType.subsystem,
                  ship: widget.ship,
                ))
            .unwrapOr([]),
        ...fitBody.subsystem.enumerate().map((t) => getSlotRow(
              widget.fitID,
              t.$2,
              type: FitItemType.subsystem,
              index: t.$1,
            )),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}
