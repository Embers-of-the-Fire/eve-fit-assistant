part of "../../page.dart";

class Weapon extends StatelessWidget {
  const Weapon({required this.ship, super.key});

  final native.Ship ship;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ListTile(
        minTileHeight: 0,
        leading: const Image(image: ImageAssets.attrDamageAlpha, height: 28),
        title: DefaultTextStyle(
          style: const TextStyle(fontSize: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _getWeaponTextGroup(ship.hull),
          ),
        ),
      ),
      ListTile(
        minTileHeight: 0,
        leading: const Image(image: ImageAssets.attrWeaponTurret, height: 28),
        title: DefaultTextStyle(
          style: const TextStyle(fontSize: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _getWeaponWithoutDroneTextGroup(ship.hull),
          ),
        ),
      ),
      ListTile(
        minTileHeight: 0,
        leading: const Image(image: ImageAssets.attrWeaponDrone, height: 28),
        title: DefaultTextStyle(
          style: const TextStyle(fontSize: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: _getWeaponDroneOnlyTextGroup(ship.hull),
          ),
        ),
      ),
    ],
  );
}

List<Text> _getWeaponTextGroup(native.Item hull) {
  final List<Text> texts = [];

  final fighterDps = hull.getAttribute(EveConstExtendedAttrID.fighterDamagePerSecond);
  final dps = hull.getAttribute(EveConstExtendedAttrID.damagePerSecondWithoutReload);
  texts
    ..add(Text("${(dps + fighterDps).toStringAsFixed(1)}/s"))
    ..add(const Text(" | "));

  final dpsWithReload = hull.getAttribute(EveConstExtendedAttrID.damagePerSecondWithReload);
  texts.add(Text("${dpsWithReload.toStringAsFixed(1)}/s"));

  return texts;
}

List<Text> _getWeaponWithoutDroneTextGroup(native.Item hull) {
  final List<Text> texts = [];

  final drone = hull.getAttribute(EveConstExtendedAttrID.droneDamagePerSecond);

  // we don't need to remove fighter dps as they're not included in dps sum;
  final dps = hull.getAttribute(EveConstExtendedAttrID.damagePerSecondWithoutReload);
  texts
    ..add(Text("${(dps - drone).toStringAsFixed(1)}/s"))
    ..add(const Text(" | "));

  final dpsWithReload = hull.getAttribute(EveConstExtendedAttrID.damagePerSecondWithReload);
  texts.add(Text("${(dpsWithReload - drone).toStringAsFixed(1)}/s"));

  return texts;
}

List<Text> _getWeaponDroneOnlyTextGroup(native.Item hull) {
  final List<Text> texts = [];

  final drone = hull.getAttribute(EveConstExtendedAttrID.droneDamagePerSecond);
  final fighterDps = hull.getAttribute(EveConstExtendedAttrID.fighterDamagePerSecond);
  texts.add(Text("${(drone + fighterDps).toStringAsFixed(1)}/s"));

  return texts;
}
