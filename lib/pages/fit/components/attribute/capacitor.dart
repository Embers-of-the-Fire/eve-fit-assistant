part of "../../page.dart";

class Capacitor extends StatelessWidget {
  const Capacitor({required this.ship, super.key});

  final native.Ship ship;

  @override
  Widget build(BuildContext context) {
    final hull = ship.hull;
    final stable = hull.getAttribute(EveConstExtendedAttrID.capacitorDepletesIn) <= 0;

    final double percent;
    if (stable) {
      percent = capacitorStableAt(
        capacity: hull.getAttribute(EveConstAttrID.capacitorCapacity),
        targetRechargeRage: hull.getAttribute(EveConstExtendedAttrID.capacitorPeakLoad),
        rechargeTime: hull.getAttribute(EveConstAttrID.rechargeRate),
      ).max(0).min(100);
    } else {
      percent = 0;
    }

    return ListTile(
      minTileHeight: 0,
      leading: const Image(image: ImageAssets.attrCapacitorCharge, height: 28),
      title: DefaultTextStyle(
        style: const TextStyle(fontSize: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _getCapacitorTextGroup(context.l10n, hull),
            ),
            const SizedBox(height: 4),
            ResourceBar(
              used: percent,
              all: 100,
              warning: false,
              trackColor: stable ? null : Colors.red.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }
}

List<Text> _getCapacitorTextGroup(AppLocalizations l10n, native.Item hull) {
  final List<Text> texts = [];

  final capPeakUsage = hull.getAttribute(EveConstExtendedAttrID.capacitorPeakLoad);

  final capDeplete = hull.getAttribute(EveConstExtendedAttrID.capacitorDepletesIn);
  if (capDeplete > 0) {
    texts.add(
      Text(
        Duration(seconds: capDeplete.round()).format(),
        style: const TextStyle(color: Colors.red),
      ),
    );
  } else {
    final capRechargeRate = hull.getAttribute(EveConstAttrID.rechargeRate);
    final cap = hull.getAttribute(EveConstAttrID.capacitorCapacity);
    final capPeakDelta = capacitorStableAt(
      capacity: cap,
      targetRechargeRage: capPeakUsage,
      rechargeTime: capRechargeRate,
    );

    texts.add(
      Text(
        l10n.fitAttributeTabCapacitorStable(percent: capPeakDelta.min(100).toStringAsFixed(1)),
        style: const TextStyle(color: Colors.green),
      ),
    );
  }

  texts.add(const Text(" | "));

  final diff = hull.getAttribute(EveConstExtendedAttrID.capacitorPeakDelta);
  texts
    ..add(
      Text(
        '${diff.isNegative ? '-' : '+'}${diff.abs().toStringAsMaxDecimals(2)} GJ/s',
        style: TextStyle(color: diff.isNegative ? Colors.red : Colors.green),
      ),
    )
    ..add(const Text(" | "));

  final cap = hull.getAttribute(EveConstAttrID.capacitorCapacity);
  texts.add(Text("${cap.round()} GJ"));

  return texts;
}
