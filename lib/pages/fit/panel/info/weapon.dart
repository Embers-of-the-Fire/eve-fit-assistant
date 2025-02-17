part of 'info_component.dart';

class Weapon extends StatelessWidget {
  final ShipProxy ship;

  const Weapon({super.key, required this.ship});

  @override
  Widget build(BuildContext context) => ListTile(
      minTileHeight: 0,
      leading: const Image(image: weaponImage, height: 28),
      title: DefaultTextStyle(
        style: const TextStyle(fontSize: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: _getWeaponTextGroup(ship.hull),
        ),
      ));
}

List<Text> _getWeaponTextGroup(ItemProxy hull) {
  final List<Text> texts = [];

  final dps = hull.attributes[damagePerSecondWithoutReload] ?? 0.0;
  texts.add(Text('${dps.toStringAsFixed(1)}/s'));

  texts.add(const Text(' | '));

  final dpsWithReload = hull.attributes[damagePerSecondWithReload] ?? 0.0;
  texts.add(Text('${dpsWithReload.toStringAsFixed(1)}/s'));

  texts.add(const Text(' | '));

  final dmg = hull.attributes[damageAlpha] ?? 0.0;
  texts.add(Text(dmg.toStringAsFixed(0)));

  return texts;
}
