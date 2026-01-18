part of "../../page.dart";

class Cargo extends StatelessWidget {
  const Cargo({required this.ship, super.key});
  final native.Ship ship;

  @override
  Widget build(BuildContext context) {
    final List<ListTile> children = [
      ListTile(
        minTileHeight: 0,
        minVerticalPadding: 0,
        leading: const Image(image: ImageAssets.attrMass, height: 28),
        title: DefaultTextStyle(
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.end,
          child: Text(
            "${ship.hull.getAttribute(EveConstExtendedAttrID.totalMass).round().commaSeparated} kg",
          ),
        ),
      ),
      ListTile(
        minTileHeight: 0,
        minVerticalPadding: 0,
        leading: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [Image(image: ImageAssets.attrTargetRange, height: 28)],
        ),
        title: DefaultTextStyle(
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.end,
          child: Text(
            "${ship.hull.getAttribute(EveConstAttrID.capacity).round().commaSeparated} m³",
          ),
        ),
      ),
    ];

    {
      final fleetCap = ship.hull.getAttribute(EveConstAttrID.fleetHangarCapacity);
      if (fleetCap != 0) {
        children.add(
          ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: ImageAssets.attrTargetRange, height: 28),
                SizedBox(width: 6),
                Image(image: ImageAssets.unknownIcon, height: 28),
              ],
            ),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text("${fleetCap.round().commaSeparated} m³"),
            ),
          ),
        );
      }
    }

    // ship maintenance bay
    {
      final shipCap = ship.hull.getAttribute(EveConstAttrID.shipMaintenanceBayCapacity);
      if (shipCap != 0) {
        children.add(
          ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: ImageAssets.attrTargetRange, height: 28),
                SizedBox(width: 6),
                Image(image: ImageAssets.unknownIcon, height: 28),
              ],
            ),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text("${shipCap.round().commaSeparated} m³"),
            ),
          ),
        );
      }
    }

    // general mining hold
    {
      final generalMineCap = ship.hull.getAttribute(EveConstAttrID.generalMiningHoldCapacity);
      if (generalMineCap != 0) {
        children.add(
          ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: ImageAssets.attrTargetRange, height: 28),
                SizedBox(width: 6),
                Image(image: ImageAssets.unknownIcon, height: 28),
              ],
            ),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text("${generalMineCap.round().commaSeparated} m³"),
            ),
          ),
        );
      }
    }

    // special gas hold
    {
      final gasCap = ship.hull.getAttribute(EveConstAttrID.specialGasHoldCapacity);
      if (gasCap != 0) {
        children.add(
          ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: ImageAssets.attrTargetRange, height: 28),
                SizedBox(width: 6),
                Image(image: ImageAssets.unknownIcon, height: 28),
              ],
            ),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text("${gasCap.round().commaSeparated} m³"),
            ),
          ),
        );
      }
    }

    // special mineral hold
    {
      final mineralCap = ship.hull.getAttribute(EveConstAttrID.specialMineralHoldCapacity);
      if (mineralCap != 0) {
        children.add(
          ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: ImageAssets.attrTargetRange, height: 28),
                SizedBox(width: 6),
                Image(image: ImageAssets.unknownIcon, height: 28),
              ],
            ),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text("${mineralCap.round().commaSeparated} m³"),
            ),
          ),
        );
      }
    }

    // ice hold
    {
      final iceCap = ship.hull.getAttribute(EveConstAttrID.specialIceHoldCapacity);
      if (iceCap != 0) {
        children.add(
          ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: ImageAssets.attrTargetRange, height: 28),
                SizedBox(width: 6),
                Image(image: ImageAssets.unknownIcon, height: 26),
              ],
            ),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text("${iceCap.round().commaSeparated} m³"),
            ),
          ),
        );
      }
    }

    // command center
    {
      final cmdCenterCap = ship.hull.getAttribute(EveConstAttrID.specialCommandCenterHoldCapacity);
      if (cmdCenterCap != 0) {
        children.add(
          ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: ImageAssets.attrTargetRange, height: 28),
                SizedBox(width: 6),
                Image(image: ImageAssets.unknownIcon, height: 28),
              ],
            ),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text("${cmdCenterCap.round().commaSeparated} m³"),
            ),
          ),
        );
      }
    }

    // planetary commodities
    {
      final planetCap = ship.hull.getAttribute(
        EveConstAttrID.specialPlanetaryCommoditiesHoldCapacity,
      );
      if (planetCap != 0) {
        children.add(
          ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: ImageAssets.attrTargetRange, height: 28),
                SizedBox(width: 6),
                Image(image: ImageAssets.unknownIcon, height: 28),
              ],
            ),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text("${planetCap.round().commaSeparated} m³"),
            ),
          ),
        );
      }
    }

    // colony / infrastructure (using same attr key as planetary in original)
    {
      final colonyCap = ship.hull.getAttribute(
        EveConstAttrID.specialPlanetaryCommoditiesHoldCapacity,
      );
      if (colonyCap != 0) {
        children.add(
          ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: ImageAssets.attrTargetRange, height: 28),
                SizedBox(width: 6),
                Image(image: ImageAssets.unknownIcon, height: 28),
              ],
            ),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text("${colonyCap.round().commaSeparated} m³"),
            ),
          ),
        );
      }
    }

    // fuel bay
    {
      final fuelCap = ship.hull.getAttribute(EveConstAttrID.specialFuelBayCapacity);
      if (fuelCap != 0) {
        children.add(
          ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image(image: ImageAssets.attrTargetRange, height: 28),
                SizedBox(width: 6),
                Image(image: ImageAssets.unknownIcon, height: 28),
              ],
            ),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text("${fuelCap.round().commaSeparated} m³"),
            ),
          ),
        );
      }
    }

    return Column(spacing: 10, children: children);
  }
}
