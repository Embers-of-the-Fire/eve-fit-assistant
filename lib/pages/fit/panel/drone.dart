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
    final fit = ref.read(fitRecordNotifierProvider(fitID).notifier);

    final droneName = GlobalStorage().static.typesAbbr[droneID]?.nameZH ?? '未知';
    final droneImage = GlobalStorage().static.icons.getTypeIconFileImageSync(droneID);
    return Slidable(
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.4,
        children: [
          SlidableAction(
            onPressed: (_) => _modifyDrone(
              fit,
              index: index,
              modify: (drone) => drone.copyWith(amount: drone.amount + 1),
            ),
            autoClose: false,
            icon: Icons.add,
            label: '+1',
          ),
          SlidableAction(
            onPressed: (_) => _modifyDrone(
              fit,
              index: index,
              modify: (drone) => drone.copyWith(amount: 5),
            ),
            icon: Icons.close,
            backgroundColor: Colors.green,
            label: 'x5',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.4,
        children: [
          SlidableAction(
            onPressed: (_) => _modifyDrone(
              fit,
              index: index,
              modify: (drone) => drone.copyWith(amount: drone.amount - 1),
            ),
            icon: Icons.remove,
            backgroundColor: Colors.white54,
            label: '-1',
          ),
          SlidableAction(
            onPressed: (_) => _removeDrone(fit, index: index),
            icon: Icons.delete_forever,
            backgroundColor: Colors.red,
            label: '删除',
          )
        ],
      ),
      child: ListTile(
        leading: Ink(
          decoration: const BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(20))),
          child: InkWell(
            borderRadius: const BorderRadius.all(Radius.circular(20)),
            onTap: () => _modifyDrone(
              fit,
              index: index,
              modify: (drone) => drone.copyWith(state: drone.state.nextState()),
            ),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: switch (state) {
                DroneState.passive => Colors.grey.shade800,
                DroneState.active => Colors.green.shade800,
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: Colors.grey.shade800,
                foregroundImage: droneImage,
              ),
            ),
          ),
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
