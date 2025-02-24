part of 'info_component.dart';

class Capacitor extends StatelessWidget {
  final ShipProxy ship;

  const Capacitor({super.key, required this.ship});

  @override
  Widget build(BuildContext context) => ListTile(
        minTileHeight: 0,
        leading: const Image(image: capacitorChargeImage, height: 28),
        title: DefaultTextStyle(
            style: const TextStyle(fontSize: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: _getCapacitorTextGroup(ship.hull),
            )),
      );
}

List<Text> _getCapacitorTextGroup(ItemProxy hull) {
  final List<Text> texts = [];

  final capPeakUsage = hull.attributes[capacitorPeakLoad] ?? 0.0;

  final capDeplete = hull.attributes[capacitorDepletesIn];
  if (capDeplete != null && capDeplete > 0) {
    texts.add(Text(
      Duration(seconds: capDeplete.round()).format(),
      style: const TextStyle(color: Colors.red),
    ));
  } else {
    final capRechargeRate = hull.attributes[rechargeRate] ?? 0.0;
    final cap = hull.attributes[capacitorCapacity] ?? 0.0;
    final capPeakDelta = capacitorStableAt(
        capacity: cap, targetRechargeRage: capPeakUsage, rechargeTime: capRechargeRate);

    texts.add(Text(
      '${capPeakDelta.min(100).toStringAsFixed(1)}% 稳定',
      style: const TextStyle(color: Colors.green),
    ));
  }

  texts.add(const Text(' | '));

  final diff = hull.attributes[capacitorPeakDelta] ?? 0.0;
  texts.add(Text(
    '${diff.isNegative ? '-' : '+'}${diff.abs().toStringAsMaxDecimals(2)} GJ/s',
    style: TextStyle(color: diff.isNegative ? Colors.red : Colors.green),
  ));

  texts.add(const Text(' | '));

  final cap = hull.attributes[capacitorCapacity] ?? 0.0;
  texts.add(Text('${cap.round().toString()} GJ'));

  return texts;
}
