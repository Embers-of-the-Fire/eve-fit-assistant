part of 'display.dart';

class _StaticDroneSlotDisplay extends StatelessWidget {
  final int droneID;
  final int amount;
  final DroneState state;

  const _StaticDroneSlotDisplay({
    required this.droneID,
    required this.amount,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final droneName = GlobalStorage().static.types[droneID]?.nameZH ?? '未知';
    final droneImage = GlobalStorage().static.icons.getTypeIconFileImageSync(droneID);
    return ListTile(
      leading: StateIcon(
        state: switch (state) {
          DroneState.passive => ItemState.passive,
          DroneState.active => ItemState.active,
        },
        foregroundImage: droneImage,
      ),
      title: Text('$droneName × $amount'),
    );
  }
}

class _StaticFighterSlotDisplay extends StatelessWidget {
  final FitRecordState fit;
  final int index;
  final int fighterID;
  final int amount;
  final DroneState state;
  final int ability;

  const _StaticFighterSlotDisplay({
    required this.fit,
    required this.index,
    required this.fighterID,
    required this.amount,
    required this.state,
    required this.ability,
  });

  @override
  Widget build(BuildContext context) {
    final itemList =
        fit.output.ship.modules.fighters.find((u) => u.groupIndex == index)?.fighters ?? [];
    final itemCount = itemList.length;
    final item = itemList.firstOrNull;

    final fighterItem = GlobalStorage().static.fighters[fighterID]!;

    final droneName = GlobalStorage().static.types[fighterID]?.nameZH ?? '未知';
    final droneImage = GlobalStorage().static.icons.getTypeIconFileImageSync(fighterID);
    return Column(children: [
      ListTile(
        leading: StateIcon(
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
              )),
          trailing: item.map((u) => _getFighterDpsText(u, itemCount))),
    ]);
  }
}

List<StateIcon> _getAbilityIcon(int ability, int enabledAbility) {
  final icons = <StateIcon>[];

  if (ability.flagContains(fighterAbilityAttackMissile)) {
    icons.add(StateIcon(
      state: enabledAbility.flagContains(fighterAbilityAttackMissile)
          ? ItemState.active
          : ItemState.online,
      foregroundImage: typeLaserImage,
    ));
  }

  if (ability.flagContains(fighterAbilityMissiles)) {
    icons.add(StateIcon(
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
