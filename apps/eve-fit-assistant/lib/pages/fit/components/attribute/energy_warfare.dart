part of "../../page.dart";

/// Nominal offensive capacitor-warfare output of the ship's active modules.
class EnergyWarfare extends StatelessWidget {
  const EnergyWarfare({required this.ship, super.key});

  final native.Ship ship;

  @override
  Widget build(BuildContext context) {
    final hull = ship.hull;
    final neutralizerRate = hull.getAttribute(EveConstExtendedAttrID.energyNeutralizerRate);
    final nosferatuRate = hull.getAttribute(EveConstExtendedAttrID.energyNosferatuRate);
    final showNeutralizer = neutralizerRate > 0;
    final showNosferatu = nosferatuRate > 0;
    if (!showNeutralizer && !showNosferatu) return const SizedBox.shrink();

    return ListTile(
      minTileHeight: 0,
      leading: const Image(image: ImageAssets.attrCapacitorCharge, height: 28),
      title: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 16),
        child: Wrap(
          alignment: WrapAlignment.end,
          children: [
            if (showNeutralizer)
              Text(
                context.l10n.fitAttributeTabEnergyWarfareNeutralizer(
                  rate: neutralizerRate.toStringAsMaxDecimals(1),
                ),
              ),
            if (showNeutralizer && showNosferatu) const Text(" | "),
            if (showNosferatu)
              Text(
                context.l10n.fitAttributeTabEnergyWarfareNosferatu(
                  rate: nosferatuRate.toStringAsMaxDecimals(1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
