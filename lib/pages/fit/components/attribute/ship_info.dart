part of "../../page.dart";

class ShipInfo extends ConsumerWidget {
  const ShipInfo({
    required this.fitContext,
    this.interactionOptions = const FitInteractionOptions(),
    super.key,
  });

  final FitContext fitContext;
  final FitInteractionOptions interactionOptions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ship = fitContext.ship;
    final shipInfo = ref.watch(repoCollectionProvider.select((c) => c?.getType(ship.typeId)));
    if (shipInfo == null) {
      return ListTile(title: Text(context.l10n.fitUnknownShip(typeId: ship.typeId)));
    }
    return ListTile(
      contentPadding: const .symmetric(horizontal: 16, vertical: 8),
      minVerticalPadding: 10,
      minTileHeight: 0,
      leading: shipInfo.icon.map((t) => EveIcon(icon: t)),
      title: TypeNameText(typeId: shipInfo.typeId, textAlign: TextAlign.center),
      onLongPress: interactionOptions.allowInspect
          ? () => showItemDetailPage(
              context,
              typeId: shipInfo.typeId,
              fitReference: ItemDetailFitReference.hull(fitId: fitContext.fitId),
            )
          : null,
    );
  }
}
