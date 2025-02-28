part of 'info_component.dart';

class ShipInfo extends ConsumerWidget {
  final String fitID;

  const ShipInfo({super.key, required this.fitID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.watch(fitRecordNotifierProvider(fitID));
    final ship = GlobalStorage().static.ships[fit.fit.brief.shipID]!;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minVerticalPadding: 10,
      minTileHeight: 0,
      onLongPress: () => showItemInfoPage(
        context,
        typeID: fit.fit.brief.shipID,
        item: fit.output.ship.hull,
        dynamicItem: null,
        onDynamicAttributeChanged: null,
      ),
      leading: GlobalStorage().static.icons.getTypeIconSync(fit.fit.brief.shipID),
      title: Text(ship.nameZH, textAlign: TextAlign.center),
    );
  }
}
