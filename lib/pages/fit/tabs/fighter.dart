part of "../page.dart";

class _FighterTab extends ConsumerWidget {
  const _FighterTab({required this.fitContext});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fighters = fitContext.fit.body.fighters;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 4),
          child: Row(
            spacing: 10,
            children: <Widget>[
              InkWell(
                onTap: () async {
                  if (fighters.length >= fitContext.ship.fighterTubes) return;
                  final typeId = await showAddItemDialog(
                    context: context,
                    title: context.l10n.fitAddItemDialogTitle(slotName: context.l10n.fighter),
                    initialMarketGroupId: SlotIdentifier.fighter(
                      index: fighters.length,
                    ).baseMarketGroupId,
                    validator: SlotIdentifier.fighter(index: fighters.length).validator(ref),
                  );
                  if (typeId == null) return;
                  await fitContext.fitWrapper.addFighter(typeId);
                },
                child: const Icon(Icons.add),
              ),
              InkWell(
                onTap: fitContext.fitWrapper.clearFighters,
                child: const Icon(Icons.clear_all),
              ),
              const Spacer(),
              Text("${fighters.length}/${fitContext.ship.fighterTubes} tubes"),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: fighters.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(context.l10n.fitSlotEmpty(slotName: context.l10n.fighter)),
                  ),
                )
              : ListView(
                  children: fighters
                      .mapWithIndex(
                        (fighter, index) => _AnySlotRow(
                          fitContext: fitContext,
                          slotIdent: SlotIdentifier.fighter(index: index),
                          slotInfo: SlotInfo.item(
                            state: FitItemState.active,
                            type: native.OutSlotType.fighter(
                              groupId: fighter.groupId,
                              ability: fighter.fighterAbility,
                            ),
                            index: index,
                            slot: FitModuleItem(
                              itemId: fighter.itemId,
                              charge: const Option.none(),
                              state: FitItemState.active,
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
