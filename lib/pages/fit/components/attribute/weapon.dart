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
          child: Row(mainAxisAlignment: MainAxisAlignment.end, children: _getWeaponTextGroup(ship)),
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

double _fighterVolleySum(native.Ship ship) => ship.modules
    .where((item) => item.slot.slotType is native.OutSlotType_Fighter)
    .fold(0, (sum, item) => sum + _fighterVolley(item));

List<Text> _getWeaponTextGroup(native.Ship ship) {
  final hull = ship.hull;
  final List<Text> texts = [];

  final fighterDps = hull.getAttribute(EveConstExtendedAttrID.fighterDamagePerSecond);
  final dps = hull.getAttribute(EveConstExtendedAttrID.damagePerSecondWithoutReload);
  texts
    ..add(Text("${(dps + fighterDps).toStringAsFixed(1)}/s"))
    ..add(const Text(" | "));

  final dpsWithReload = hull.getAttribute(EveConstExtendedAttrID.damagePerSecondWithReload);
  texts
    ..add(Text("${(dpsWithReload + fighterDps).toStringAsFixed(1)}/s"))
    ..add(const Text(" | "));

  final alpha = hull.getAttribute(EveConstExtendedAttrID.damageAlpha) + _fighterVolleySum(ship);
  texts.add(Text(alpha.toStringAsFixed(1)));

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
  texts
    ..add(Text("${(dpsWithReload - drone).toStringAsFixed(1)}/s"))
    ..add(const Text(" | "));

  // damageAlpha only aggregates weapon modules; drones and fighters are excluded.
  final alpha = hull.getAttribute(EveConstExtendedAttrID.damageAlpha);
  texts.add(Text(alpha.toStringAsFixed(1)));

  return texts;
}

List<Text> _getWeaponDroneOnlyTextGroup(native.Item hull) {
  final List<Text> texts = [];

  final drone = hull.getAttribute(EveConstExtendedAttrID.droneDamagePerSecond);
  final fighterDps = hull.getAttribute(EveConstExtendedAttrID.fighterDamagePerSecond);
  texts.add(Text("${(drone + fighterDps).toStringAsFixed(1)}/s"));

  return texts;
}
