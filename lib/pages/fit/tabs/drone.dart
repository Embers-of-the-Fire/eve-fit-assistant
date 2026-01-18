part of "../page.dart";

class _DroneTab extends ConsumerWidget {
  const _DroneTab({required this.fitContext, super.key});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = fitContext.fit;
    final fitWrapper = fitContext.fitWrapper;

    const slotIdent = SlotIdentifier.drone(groupId: 0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 4),
          child: Row(
            spacing: 10,
            children: <InkWell>[
              InkWell(
                onTap: () async {
                  final typeId = await showAddItemDialog(
                    context: context,
                    title: context.l10n.fitDroneTabAddDroneTitle,
                    initialMarketGroupId: slotIdent.baseMarketGroupId,
                    validator: slotIdent.validator(ref),
                  );
                  if (typeId == null) return;
                  await fitWrapper.update((storage) {
                    final newDrone = FitDroneItem(
                      itemId: FitStorageItemId.item(id: typeId),
                      groupId: storage.body.drones.length + 1,
                      state: FitItemState.active,
                    );
                    return storage.copyWith(
                      body: storage.body.copyWith(drones: storage.body.drones.add(newDrone)),
                    );
                  });
                },
                child: const Icon(Icons.add),
              ),
              InkWell(
                onTap: () async {
                  await fitWrapper.update(
                    (storage) => storage.copyWith(
                      body: storage.body.copyWith(drones: IList<FitDroneItem>()),
                    ),
                  );
                },
                child: const Icon(Icons.clear_all),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView(
            children: fit.body.drones
                .map(
                  (item) => _AnySlotRow(
                    fitContext: fitContext,
                    slotIdent: SlotIdentifier.drone(groupId: item.groupId),
                    slotInfo: SlotInfo.item(
                      state: item.state,
                      type: native.OutSlotType.droneBay(groupId: item.groupId),
                      index: item.groupId,
                      slot: FitModuleItem(
                        charge: const Option.none(),
                        state: item.state,
                        itemId: item.itemId,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
