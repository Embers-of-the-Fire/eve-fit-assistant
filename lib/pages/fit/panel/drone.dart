part of 'fit.dart';

class DroneTab extends ConsumerWidget {
  final String fitID;

  const DroneTab({super.key, required this.fitID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitNotifier = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fit = ref.read(fitRecordNotifierProvider(fitID));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 4),
          child: Row(spacing: 10, children: <InkWell>[
            InkWell(
              onTap: () async {
                final droneID = await showAddDroneDialog(context);
                if (droneID != null) {
                  await fitNotifier.modify((record) {
                    record.addDrone(droneID);
                    return record;
                  });
                }
              },
              child: const Icon(Icons.add),
            ),
            InkWell(
              onTap: () => _clearDrone(fitNotifier),
              child: const Icon(Icons.clear_all),
            )
          ]),
        ),
        const Divider(),
        Expanded(
            child: ListView(
          children: fit.fit.body.drone.enumerate().map((el) {
            final index = el.$1;
            final drone = el.$2;
            return _DroneSlot(
              fitID: fitID,
              index: index,
              droneID: drone.itemID,
              amount: drone.amount,
              state: drone.state,
            );
          }).toList(),
        )),
      ],
    );
  }
}

class _DroneSlot extends ConsumerWidget {
  final String fitID;
  final int index;
  final int droneID;
  final int amount;
  final DroneState state;

  const _DroneSlot({
    required this.fitID,
    required this.index,
    required this.droneID,
    required this.amount,
    required this.state,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitNotifier = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fit = ref.watch(fitRecordNotifierProvider(fitID));

    final item =
        fit.output.ship.modules.drones.find((u) => u.groupIndex == index)?.drones.firstOrNull;

    final droneName = GlobalStorage().static.types[droneID]?.nameZH ?? '未知';
    final droneImage = GlobalStorage().static.icons.getTypeIconFileImageSync(droneID);
    return Slidable(
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (_) => _modifyDrone(
              fitNotifier,
              index: index,
              modify: (drone) => drone.copyWith(amount: drone.amount + 1),
            ),
            autoClose: false,
            padding: EdgeInsets.zero,
            icon: Icons.add,
            label: '+1',
          ),
          SlidableAction(
            onPressed: (_) => _modifyDrone(
              fitNotifier,
              index: index,
              modify: (drone) => drone.copyWith(amount: 5),
            ),
            padding: EdgeInsets.zero,
            icon: Icons.close,
            backgroundColor: Colors.green,
            label: 'x5',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (_) => _modifyDrone(
              fitNotifier,
              index: index,
              modify: (drone) => drone.copyWith(amount: drone.amount - 1),
            ),
            padding: EdgeInsets.zero,
            icon: Icons.remove,
            backgroundColor: Colors.white54,
            label: '-1',
          ),
          SlidableAction(
            onPressed: (_) => _removeDrone(fitNotifier, index: index),
            padding: EdgeInsets.zero,
            icon: Icons.delete_forever,
            backgroundColor: Colors.red,
            label: '删除',
          )
        ],
      ),
      child: ListTile(
        onLongPress: () => item.mapOrElse(
            map: (i) => showItemInfoPage(context,
                typeID: droneID,
                item: i,
                dynamicItem: i.isDynamic.thenWith(() => fit.fit.body.dynamicItems[i.itemId]),
                onDynamicAttributeChanged: (id, value) => fitNotifier.modify((record) {
                      final dynamicItem = record.body.dynamicItems[i.itemId]!;
                      dynamicItem.dynamicAttributes[id] = value;
                      return record;
                    })),
            orElse: () => showTypeInfoPage(context, typeID: droneID)),
        leading: StateIcon(
          state: switch (state) {
            DroneState.passive => ItemState.passive,
            DroneState.active => ItemState.active,
          },
          onTap: () => _modifyDrone(
            fitNotifier,
            index: index,
            modify: (drone) => drone.copyWith(state: drone.state.nextState()),
          ),
          foregroundImage: droneImage,
        ),
        title: Text('$droneName × $amount'),
      ),
    );
  }
}

Future<void> _modifyDrone(
  FitRecordNotifier fitNotifier, {
  required int index,
  required DroneItem Function(DroneItem) modify,
}) async {
  await fitNotifier.modify((record) {
    record.modifyDrone(index, modify);
    return record;
  });
}

Future<void> _removeDrone(FitRecordNotifier fitNotifier, {required int index}) async {
  await fitNotifier.modify((record) {
    record.removeDrone(index);
    return record;
  });
}

Future<void> _clearDrone(FitRecordNotifier fitNotifier) async {
  await fitNotifier.modify((record) {
    record.clearDrone();
    return record;
  });
}
