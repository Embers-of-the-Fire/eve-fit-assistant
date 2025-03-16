part of 'fit.dart';

class FighterTab extends ConsumerWidget {
  final String fitID;

  const FighterTab({super.key, required this.fitID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.read(fitRecordNotifierProvider(fitID));

    return Column(
      children: [
        _FighterHeading(fitID: fitID),
        const Divider(),
        Expanded(
            child: ListView(
          children: fit.fit.body.fighter.enumerate().map((el) {
            final index = el.$1;
            final fighter = el.$2;
            return _FighterSlot(
              fitID: fitID,
              index: index,
              fighterID: fighter.itemID,
              amount: fighter.amount,
              state: fighter.state,
              ability: fighter.ability,
            );
          }).toList(),
        )),
      ],
    );
  }
}

class _FighterHeading extends ConsumerWidget {
  final String fitID;

  const _FighterHeading({required this.fitID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitNotifier = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fit = ref.read(fitRecordNotifierProvider(fitID));

    final fighterLightLimit = fit.output.ship.hull.attributes[fighterLightSlots] ?? 0;
    final fighterSupportLimit = fit.output.ship.hull.attributes[fighterSupportSlots] ?? 0;
    final fighterHeavyLimit = fit.output.ship.hull.attributes[fighterHeavySlots] ?? 0;

    final (fighterLightActive, fighterSupportActive, fighterHeavyActive) = countFighter(fit.fit);

    final fighterLimit = fit.output.ship.hull.attributes[fighterTubes] ?? 0;
    final fighterActive = fighterLightActive + fighterSupportActive + fighterHeavyActive;

    return Padding(
      padding: const EdgeInsets.only(left: 10, right: 10, top: 8, bottom: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Row(spacing: 10, children: <InkWell>[
          InkWell(
            onTap: () => _addFighter(fitNotifier, context),
            child: const Icon(Icons.add),
          ),
          InkWell(
            onTap: () => _clearFighter(fitNotifier),
            child: const Icon(Icons.clear_all),
          )
        ]),
        Row(spacing: 10, children: <Text>[
          Text('轻型 ${fighterLightActive.toStringAsFixed(0)}'
              '/${fighterLightLimit.toStringAsFixed(0)}'),
          Text('后勤 ${fighterSupportActive.toStringAsFixed(0)}'
              '/${fighterSupportLimit.toStringAsFixed(0)}'),
          Text('重型 ${fighterHeavyActive.toStringAsFixed(0)}'
              '/${fighterHeavyLimit.toStringAsFixed(0)}'),
          Text('发射管 ${fighterActive.toStringAsFixed(0)}'
              '/${fighterLimit.toStringAsFixed(0)}'),
        ])
      ]),
    );
  }
}

class _FighterSlot extends ConsumerWidget {
  final String fitID;
  final int index;
  final int fighterID;
  final int amount;
  final DroneState state;
  final int ability;

  const _FighterSlot({
    required this.fitID,
    required this.index,
    required this.fighterID,
    required this.amount,
    required this.state,
    required this.ability,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitNotifier = ref.read(fitRecordNotifierProvider(fitID).notifier);
    final fit = ref.watch(fitRecordNotifierProvider(fitID));

    final itemList =
        fit.output.ship.modules.fighters.find((u) => u.groupIndex == index)?.fighters ?? [];
    final itemCount = itemList.length;
    final item = itemList.firstOrNull;

    final fighterItem = GlobalStorage().static.fighters[fighterID]!;

    final droneName = GlobalStorage().static.types[fighterID]?.nameZH ?? '未知';
    final droneImage = GlobalStorage().static.icons.getTypeIconFileImageSync(fighterID);
    return Slidable(
      startActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (_) => _modifyFighter(
              fitNotifier,
              index: index,
              modify: (fighter) => fighter.copyWith(amount: fighter.amount + 1),
            ),
            autoClose: false,
            padding: EdgeInsets.zero,
            icon: Icons.add,
            label: '+1',
          ),
          SlidableAction(
            onPressed: (_) => _modifyFighter(
              fitNotifier,
              index: index,
              modify: (fighter) => fighter.copyWith(amount: fighterItem.amount),
            ),
            padding: EdgeInsets.zero,
            icon: Icons.close,
            backgroundColor: Colors.green,
            label: '填满',
          ),
        ],
      ),
      endActionPane: ActionPane(
        motion: const StretchMotion(),
        extentRatio: 0.3,
        children: [
          SlidableAction(
            onPressed: (_) => _modifyFighter(
              fitNotifier,
              index: index,
              modify: (fighter) => fighter.copyWith(amount: fighter.amount - 1),
            ),
            padding: EdgeInsets.zero,
            icon: Icons.remove,
            backgroundColor: Colors.white54,
            label: '-1',
          ),
          SlidableAction(
            onPressed: (_) => _removeFighter(fitNotifier, index: index),
            padding: EdgeInsets.zero,
            icon: Icons.delete_forever,
            backgroundColor: Colors.red,
            label: '删除',
          )
        ],
      ),
      child: Column(children: [
        ListTile(
          onLongPress: () => item.mapOrElse(
              map: (i) => showItemInfoPage(context,
                  typeID: fighterID,
                  item: i,
                  dynamicItem: i.isDynamic.thenWith(() => fit.fit.body.dynamicItems[i.itemId]),
                  onDynamicAttributeChanged: (id, value) => fitNotifier.modify((record) {
                        final dynamicItem = record.body.dynamicItems[i.itemId]!;
                        record.body.dynamicItems[i.itemId] =
                            dynamicItem.copyWith(dynamicAttributes: {
                          ...dynamicItem.dynamicAttributes,
                          id: value,
                        });
                        return record;
                      }),
                  onDynamicAttributeReset: () => fitNotifier.modify((record) {
                        final dynamicItem = record.body.dynamicItems[i.itemId]!;
                        record.body.dynamicItems[i.itemId] = dynamicItem.copyWith(
                            dynamicAttributes:
                                dynamicItem.dynamicAttributes.map((key, _) => MapEntry(key, 1.0)));
                        return record;
                      }),
                  onDynamicAttributeRandom: () => fitNotifier.modify((record) {
                        final dynamicItem = record.body.dynamicItems[i.itemId]!;
                        final data =
                            GlobalStorage().static.dynamicItems[dynamicItem.mutaplasmidID]!;
                        record.body.dynamicItems[i.itemId] = dynamicItem.copyWith(
                            dynamicAttributes: data.data.attributes.map((key, data) =>
                                MapEntry(key, Random().nextDoubleRange(data.min, data.max))));
                        return record;
                      }),
                  fitID: fitID),
              orElse: () => showTypeInfoPage(context, typeID: fighterID)),
          leading: StateIcon(
            onTap: () => _modifyFighter(
              fitNotifier,
              index: index,
              modify: (drone) => drone.copyWith(state: drone.state.nextState()),
            ),
            state: switch (state) {
              DroneState.passive => ItemState.passive,
              DroneState.active => ItemState.active,
            },
            foregroundImage: droneImage,
          ),
          title: Text('$droneName × $amount'),
        ),
        ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              child: Text(fighterItem.type.text),
            ),
            title: Row(
                spacing: 10,
                children: _getAbilityIcon(
                  fighterItem.ability,
                  ability,
                  index: index,
                  fitNotifier: fitNotifier,
                )),
            trailing: item.map((u) => _getFighterDpsText(u, itemCount))),
      ]),
    );
  }
}

Future<void> _modifyFighter(
  FitRecordNotifier fitNotifier, {
  required int index,
  required FighterItem Function(FighterItem) modify,
}) async {
  await fitNotifier.modify((record) {
    record.modifyFighter(index, modify);
    return record;
  });
}

Future<void> _removeFighter(FitRecordNotifier fitNotifier, {required int index}) async {
  await fitNotifier.modify((record) {
    record.removeFighter(index);
    return record;
  });
}

Future<void> _addFighter(FitRecordNotifier fitNotifier, BuildContext context) async {
  final fighterID = await showAddFighterDialog(context);
  if (fighterID != null) {
    await fitNotifier.modify((record) {
      record.addFighter(fighterID);
      return record;
    });
  }
}

Future<void> _clearFighter(FitRecordNotifier fitNotifier) async {
  await fitNotifier.modify((record) {
    record.clearFighter();
    return record;
  });
}

List<StateIcon> _getAbilityIcon(int ability, int enabledAbility,
    {required int index, required FitRecordNotifier fitNotifier}) {
  final icons = <StateIcon>[];

  if (ability.flagContains(fighterAbilityAttackMissile)) {
    icons.add(StateIcon(
      onTap: () => fitNotifier.modify((record) {
        record.modifyFighter(
            index,
            (fighter) =>
                fighter.copyWith(ability: fighter.ability.toggleFlag(fighterAbilityAttackMissile)));
        return record;
      }),
      state: enabledAbility.flagContains(fighterAbilityAttackMissile)
          ? ItemState.active
          : ItemState.online,
      foregroundImage: typeLaserImage,
    ));
  }

  if (ability.flagContains(fighterAbilityMissiles)) {
    icons.add(StateIcon(
      onTap: () => fitNotifier.modify((record) {
        record.modifyFighter(
            index,
            (fighter) =>
                fighter.copyWith(ability: fighter.ability.toggleFlag(fighterAbilityMissiles)));
        return record;
      }),
      state:
          enabledAbility.flagContains(fighterAbilityMissiles) ? ItemState.active : ItemState.online,
      foregroundImage: typeTorpedoImage,
    ));
  }

  return icons;
}

Text _getFighterDpsText(ItemProxy fighter, int num) {
  final dps = fighter.attributes[fighterDamagePerSecond] ?? 0.0;

  return Text('$num × ${dps.toStringAsFixed(1)}/s  =  ${(dps * num).toStringAsFixed(1)}/s',
      style: const TextStyle(fontSize: 14));
}
