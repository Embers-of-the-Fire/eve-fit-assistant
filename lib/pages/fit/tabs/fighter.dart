part of "../page.dart";

class _FighterTab extends ConsumerWidget {
  const _FighterTab({required this.fitContext});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fighters = fitContext.fit.body.fighters;
    final lightLimit =
        fitContext.emulated?.hull.getAttribute(EveConstAttrID.fighterLightSlots).round() ?? 0;
    final supportLimit =
        fitContext.emulated?.hull.getAttribute(EveConstAttrID.fighterSupportSlots).round() ?? 0;
    final heavyLimit =
        fitContext.emulated?.hull.getAttribute(EveConstAttrID.fighterHeavySlots).round() ?? 0;

    var lightCount = 0;
    var supportCount = 0;
    var heavyCount = 0;

    for (final fighter in fighters) {
      final typeId = fitContext.resolveOriginTypeId(fighter.itemId);
      if (typeId == null) continue;

      final type = ref.watch(bundleCollectionGetTypeProvider(typeId));
      if (type == null) continue;

      switch (_fighterCategoryFromGroupId(type.groupId)) {
        case _FighterCategory.light:
          lightCount += 1;
        case _FighterCategory.support:
          supportCount += 1;
        case _FighterCategory.heavy:
          heavyCount += 1;
        case null:
          break;
      }
    }

    return Column(
      children: [
        _EquipmentTitleRow(
          leftActions: [
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
            InkWell(onTap: fitContext.fitWrapper.clearFighters, child: const Icon(Icons.clear_all)),
          ],
          rightInfo: [
            if (lightLimit > 0) Text("L $lightCount/$lightLimit"),
            if (supportLimit > 0) Text("S $supportCount/$supportLimit"),
            if (heavyLimit > 0) Text("H $heavyCount/$heavyLimit"),
            Text(
              context.l10n.fitFighterTabTubeCounter(
                count: fighters.length,
                total: fitContext.ship.fighterTubes,
              ),
            ),
          ],
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
