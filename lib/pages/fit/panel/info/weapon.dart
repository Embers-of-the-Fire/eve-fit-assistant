part of 'info_component.dart';

class Weapon extends StatelessWidget {
  final ShipProxy ship;

  const Weapon({super.key, required this.ship});

  @override
  Widget build(BuildContext context) => Column(children: [
        ListTile(
            minTileHeight: 0,
            leading: const Image(image: damageAlphaImage, height: 28),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: _getWeaponText(ship.hull),
            )),
        ListTile(
            minTileHeight: 0,
            leading: const Image(image: weaponTurretImage, height: 28),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: _getWeaponNoDroneText(ship.hull),
            )),
        ListTile(
            minTileHeight: 0,
            leading: const Image(image: weaponDroneImage, height: 28),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: _getDroneText(ship.hull),
            )),
      ]);
}

Text _getWeaponText(ItemProxy hull) {
  String texts = '';

  final fighterDps = hull.attributes[fighterDamagePerSecond] ?? 0.0;

  final dps = hull.attributes[damagePerSecondWithoutReload] ?? 0.0;
  texts += '${(dps + fighterDps).toStringAsFixed(1)}/s';

  texts += ' | ';

  final dpsWithReload = hull.attributes[damagePerSecondWithReload] ?? 0.0;
  texts += '${(dpsWithReload + fighterDps).toStringAsFixed(1)}/s';

  return Text(texts);
}

Text _getWeaponNoDroneText(ItemProxy hull) {
  String texts = '';

  final drone = hull.attributes[droneDamagePerSecond] ?? 0.0;

  final dps = hull.attributes[damagePerSecondWithoutReload] ?? 0.0;
  texts += '${(dps - drone).toStringAsFixed(1)}/s';

  texts += ' | ';

  final dpsWithReload = hull.attributes[damagePerSecondWithReload] ?? 0.0;
  texts += '${(dpsWithReload - drone).toStringAsFixed(1)}/s';

  texts += ' | ';

  final dmg = hull.attributes[damageAlpha] ?? 0.0;
  texts += dmg.toStringAsFixed(0);

  return Text(texts);
}

Text _getDroneText(ItemProxy hull) {
  String text = '';

  final fighterDps = hull.attributes[fighterDamagePerSecond] ?? 0.0;
  final dps = hull.attributes[droneDamagePerSecond] ?? 0.0;
  text += '${(dps + fighterDps).toStringAsFixed(1)}/s';

  return Text(text);
}
