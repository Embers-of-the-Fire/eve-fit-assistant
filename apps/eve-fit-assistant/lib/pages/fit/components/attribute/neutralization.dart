part of "../../page.dart";

/// Defensive capacitor-warfare statistics: the ship's neutralization
/// resistance and the estimated neutralization pressure needed to defeat the
/// capacitor.
class Neutralization extends StatelessWidget {
  const Neutralization({required this.ship, super.key});

  final native.Ship ship;

  @override
  Widget build(BuildContext context) {
    final hull = ship.hull;
    final resistance = hull.getAttribute(EveConstAttrID.energyWarfareResistance, 1);
    final resistanceRate = neutralizationResistanceRate(resistance);
    final stable = hull.getAttribute(EveConstExtendedAttrID.capacitorDepletesIn) <= 0;

    return ListTile(
      minTileHeight: 0,
      leading: const Image(image: ImageAssets.attrEnergyWarfareResistance, height: 28),
      title: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: _getNeutralizationTextGroup(
            context.l10n,
            ship,
            stable: stable,
            resistance: resistance,
            resistanceRate: resistanceRate,
          ),
        ),
      ),
    );
  }
}

List<Text> _getNeutralizationTextGroup(
  AppLocalizations l10n,
  native.Ship ship, {
  required bool stable,
  required double resistance,
  required double resistanceRate,
}) {
  final texts = <Text>[
    Text(
      l10n.fitAttributeTabNeutralizationResistance(
        percent: (resistanceRate * 100).toStringAsFixed(1),
      ),
    ),
    const Text(" | "),
  ];

  if (stable) {
    final margin = ship.hull.getAttribute(EveConstExtendedAttrID.capacitorPeakDelta);
    final breakRate = neutralizationBreakPeakRate(
      peakDelta: margin,
      energyWarfareResistance: resistance,
    );
    texts.add(
      Text(
        l10n.fitAttributeTabNeutralizationBreak(
          rate: breakRate.isFinite ? breakRate.toStringAsMaxDecimals(2) : "∞",
        ),
        style: const TextStyle(color: Colors.green),
      ),
    );
  } else {
    final clearAmount = neutralizationClearAmount(
      capacity: ship.hull.getAttribute(EveConstAttrID.capacitorCapacity),
      energyWarfareResistance: resistance,
    );
    texts.add(
      Text(
        l10n.fitAttributeTabNeutralizationClear(
          amount: clearAmount.isFinite ? clearAmount.round().toString() : "∞",
        ),
        style: const TextStyle(color: Colors.red),
      ),
    );
  }

  return texts;
}
