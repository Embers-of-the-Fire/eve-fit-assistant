part of 'slot.dart';

class SubsystemSlotRow extends ConsumerWidget {
  final String fitID;
  final int typeID;
  final SubsystemType type;

  const SubsystemSlotRow({
    super.key,
    required this.fitID,
    required this.typeID,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitNotifier = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fit = ref.watch(fitRecordNotifierProvider(fitID));

    return Slidable(
      startActionPane: ActionPane(
        extentRatio: 0.2,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) async {
              final subID =
                  await showAddSubsystemDialog(context, shipID: fit.fit.brief.shipID, type: type);
              if (subID != null) {
                await fitNotifier.modify((record) {
                  record.addSubsystem(type, subID);
                  return record;
                });
              }
            },
            icon: Icons.change_circle_outlined,
            label: '更换',
          )
        ],
      ),
      endActionPane: ActionPane(
        extentRatio: 0.2,
        motion: const StretchMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => fitNotifier.modify((record) {
              record.removeSubsystem(type);
              return record;
            }),
            icon: Icons.delete_forever,
            backgroundColor: Colors.red,
            label: '删除',
          )
        ],
      ),
      child: ListTile(
        leading: StateIcon(
          state: ItemState.online,
          child: Image(image: GlobalStorage().static.icons.getTypeIconFileImageSync(typeID)!),
        ),
        title: Text(GlobalStorage().static.types[typeID]?.nameZH ?? '未知'),
      ),
    );
  }
}

class SubsystemSlotRowPlaceholder extends ConsumerWidget {
  final String fitID;
  final SubsystemType type;

  const SubsystemSlotRowPlaceholder({
    super.key,
    required this.fitID,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitNotifier = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fit = ref.watch(fitRecordNotifierProvider(fitID));

    return ListTile(
      leading: StateIcon(
          state: ItemState.online,
          child: Image(
            image: switch (type) {
              SubsystemType.offensive => subsystemOffensivePlaceholderImage,
              SubsystemType.defensive => subsystemDefensivePlaceholderImage,
              SubsystemType.core => subsystemCorePlaceholderImage,
              SubsystemType.propulsion => subsystemPropulsionPlaceholderImage,
            },
            width: 30,
            height: 30,
          )),
      title: const Text('子系统'),
      onTap: () async {
        final subID = await showAddSubsystemDialog(
          context,
          type: type,
          shipID: fit.fit.brief.shipID,
        );
        if (subID != null) {
          await fitNotifier.modify((record) {
            record.addSubsystem(type, subID);
            return record;
          });
        }
      },
    );
  }
}
