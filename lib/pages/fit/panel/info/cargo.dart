part of 'info_component.dart';

class Cargo extends StatelessWidget {
  final ShipProxy ship;

  const Cargo({super.key, required this.ship});

  @override
  Widget build(BuildContext context) {
    final List<ListTile> children = [];
    children.add(ListTile(
        minTileHeight: 0,
        minVerticalPadding: 0,
        leading: const Image(image: massImage, height: 28),
        title: DefaultTextStyle(
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.end,
          child: Text('${ship.hull.attributes[totalMass].unwrapOr(0.0).commaSeparated} kg'),
        )));
    children.add(ListTile(
        minTileHeight: 0,
        minVerticalPadding: 0,
        leading: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [Image(image: cargoCapacityImage, height: 28)]),
        title: DefaultTextStyle(
          style: const TextStyle(fontSize: 16),
          textAlign: TextAlign.end,
          child: Text('${ship.hull.attributes[capacity].unwrapOr(0.0).commaSeparated} m³'),
        )));

    {
      final fleetCap = ship.hull.attributes[fleetHangarCapacity] ?? 0.0;
      if (fleetCap != 0) {
        children.add(ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
              Image(image: cargoCapacityImage, height: 28),
              Image(image: fleetImage, height: 28)
            ]),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text('${fleetCap.commaSeparated} m³'),
            )));
      }
    }

    {
      final shipCap = ship.hull.attributes[shipMaintenanceBayCapacity] ?? 0.0;
      if (shipCap != 0) {
        children.add(ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
              Image(image: cargoCapacityImage, height: 28),
              Image(image: shipImage, height: 28)
            ]),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text('${shipCap.commaSeparated} m³'),
            )));
      }
    }

    {
      final generalMineCap = ship.hull.attributes[generalMiningHoldCapacity] ?? 0.0;
      if (generalMineCap != 0) {
        children.add(ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
              Image(image: cargoCapacityImage, height: 28),
              Image(image: oreImage, height: 28)
            ]),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text('${generalMineCap.commaSeparated} m³'),
            )));
      }
    }

    {
      final gasCap = ship.hull.attributes[specialGasHoldCapacity] ?? 0.0;
      if (gasCap != 0) {
        children.add(ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
              Image(image: cargoCapacityImage, height: 28),
              Image(image: gasImage, height: 28)
            ]),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text('${gasCap.commaSeparated} m³'),
            )));
      }
    }

    {
      final mineralCap = ship.hull.attributes[specialMineralHoldCapacity] ?? 0.0;
      if (mineralCap != 0) {
        children.add(ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
              Image(image: cargoCapacityImage, height: 28),
              Image(image: mineralImage, height: 28)
            ]),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text('${mineralCap.commaSeparated} m³'),
            )));
      }
    }

    {
      final iceCap = ship.hull.attributes[specialIceHoldCapacity] ?? 0.0;
      if (iceCap != 0) {
        children.add(ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(mainAxisSize: MainAxisSize.min, spacing: 6, children: [
              Image(image: cargoCapacityImage, height: 28),
              Image(image: iceImage, height: 26)
            ]),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text('${iceCap.commaSeparated} m³'),
            )));
      }
    }

    {
      final cmdCenterCap = ship.hull.attributes[specialCommandCenterHoldCapacity] ?? 0.0;
      if (cmdCenterCap != 0) {
        children.add(ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
              Image(image: cargoCapacityImage, height: 28),
              Image(image: commandCenterImage, height: 28)
            ]),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text('${cmdCenterCap.commaSeparated} m³'),
            )));
      }
    }

    {
      final planetCap = ship.hull.attributes[specialPlanetaryCommoditiesHoldCapacity] ?? 0.0;
      if (planetCap != 0) {
        children.add(ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
              Image(image: cargoCapacityImage, height: 28),
              Image(image: planetaryMaterialsImage, height: 28)
            ]),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text('${planetCap.commaSeparated} m³'),
            )));
      }
    }

    {
      final colonyCap = ship.hull.attributes[specialPlanetaryCommoditiesHoldCapacity] ?? 0.0;
      if (colonyCap != 0) {
        children.add(ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
              Image(image: cargoCapacityImage, height: 28),
              Image(image: infrastructureImage, height: 28)
            ]),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text('${colonyCap.commaSeparated} m³'),
            )));
      }
    }

    {
      final fuelCap = ship.hull.attributes[specialFuelBayCapacity] ?? 0.0;
      if (fuelCap != 0) {
        children.add(ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Row(mainAxisSize: MainAxisSize.min, spacing: 4, children: [
              Image(image: cargoCapacityImage, height: 28),
              Image(image: fuelImage, height: 28)
            ]),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text('${fuelCap.commaSeparated} m³'),
            )));
      }
    }

    return Column(spacing: 10, children: children);
  }
}
