part of "../../page.dart";

class ShipInfo extends ConsumerWidget {
  const ShipInfo({required this.fitContext, super.key});

  final FitContext fitContext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ship = fitContext.ship;
    final shipInfo = ref.watch(bundleCollectionGetTypeProvider(ship.typeId));
    if (shipInfo == null) {
      return ListTile(title: Text("Unknown Ship ${ship.typeId}"));
    }
    return ListTile(
      contentPadding: const .symmetric(horizontal: 16, vertical: 8),
      minVerticalPadding: 10,
      minTileHeight: 0,
      leading: shipInfo.icon.map((t) => EveIcon(icon: t)),
      title: TypeNameText(typeId: shipInfo.typeId, textAlign: TextAlign.center),
    );
  }
}
