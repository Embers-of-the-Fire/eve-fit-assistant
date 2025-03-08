part of 'slot.dart';

class TacticalModeSlotRow extends ConsumerWidget {
  final String fitID;
  final int shipID;
  final int modeID;

  const TacticalModeSlotRow({
    super.key,
    required this.fitID,
    required this.shipID,
    required this.modeID,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitNotifier = ref.read(fitRecordNotifierProvider(fitID).notifier);

    final modeInfo = GlobalStorage().static.tacticalModes[shipID]?.tacticalModes[modeID];
    final modeImage =
        modeInfo.andThen((info) => GlobalStorage().static.icons.getIconFileImageSync(info.iconID));
    final typeName = modeInfo?.nameZH ?? '未知模式';

    return ListTile(
      leading: StateIcon(
        state: ItemState.active,
        foregroundImage: modeImage,
      ),
      title: Text(typeName),
      onTap: () => fitNotifier.modify((record) {
        record.changeTacticalMode();
        return record;
      }),
      onLongPress: () => showTypeInfoPage(context, typeID: modeID),
    );
  }
}
