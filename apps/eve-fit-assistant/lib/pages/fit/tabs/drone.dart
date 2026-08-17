part of "../page.dart";

class _DroneTab extends ConsumerWidget {
  const _DroneTab({
    required this.fitContext,
    this.interactionOptions = const FitInteractionOptions(),
  });

  final FitContext fitContext;
  final FitInteractionOptions interactionOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = fitContext.fit;
    final fitWrapper = fitContext.fitWrapper;

    // The drone row widget manages per-row quantity controls, while this
    // tab keeps the top-level add and clear actions.
    const slotIdent = SlotIdentifier.drone(index: 0);

    final drones = fit.body.drones.toList();

    final bayUsed =
        fitContext.emulated?.hull.getAttribute(EveConstExtendedAttrID.droneCapacityLoad).round() ??
        0;
    final bayCapacity =
        fitContext.emulated?.hull.getAttribute(EveConstAttrID.droneCapacity).round() ?? 0;

    return Column(
      children: [
        _EquipmentTitleRow(
          issues: _collectFitIssuesForSection(context, ref, fitContext, _FitIssueSection.drone),
          rightInfo: [
            if (bayCapacity > 0 || bayUsed > 0)
              CapacityCounter(suffix: "m³", count: bayUsed, total: bayCapacity),
          ],
          leftActions: <Widget>[
            InkWell(
              onTap: interactionOptions.allowMutations
                  ? () async {
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
                          state: FitItemState.active,
                          quantity: 1,
                        );
                        return storage.copyWith(
                          body: storage.body.copyWith(drones: storage.body.drones.add(newDrone)),
                        );
                      });
                    }
                  : null,
              child: const Icon(Icons.add),
            ),
            InkWell(
              onTap: interactionOptions.allowMutations
                  ? () async {
                      await fitWrapper.update(
                        (storage) => storage.copyWith(
                          body: storage.body.copyWith(drones: IList<FitDroneItem>()),
                        ),
                      );
                    }
                  : null,
              child: const Icon(Icons.clear_all),
            ),
          ],
        ),
        const Divider(),
        Expanded(
          child: ListView(
            children: [
              for (int index = 0; index < drones.length; index++)
                _AnySlotRow(
                  fitContext: fitContext,
                  slotIdent: SlotIdentifier.drone(index: index),
                  slotInfo: SlotInfo.item(
                    state: drones[index].state,
                    type: native.OutSlotType.droneBay(groupId: index),
                    index: index,
                    slot: FitModuleItem(
                      charge: const Option.none(),
                      state: drones[index].state,
                      itemId: drones[index].itemId,
                    ),
                  ),
                  interactionOptions: interactionOptions,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
