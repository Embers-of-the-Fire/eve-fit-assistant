part of 'info_component.dart';

class Resource extends StatelessWidget {
  final ShipProxy ship;

  const Resource({super.key, required this.ship});

  @override
  Widget build(BuildContext context) {
    final allCpu = ship.hull.attributes[cpuOutput] ?? 0.0;
    final cpuUsed = allCpu - (ship.hull.attributes[cpuFree] ?? 0.0);

    final allPower = ship.hull.attributes[powerOutput] ?? 0.0;
    final powerUsed = allPower - (ship.hull.attributes[powerFree] ?? 0.0);

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 22, top: 8, bottom: 8),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 16),
        child: Column(
          spacing: 10,
          children: <Widget>[
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Image(image: cpuImage, height: 28),
              ResourceCompare(
                used: cpuUsed,
                all: allCpu,
                fixed: 1,
                unit: 'tf',
              ),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Image(image: powerImage, height: 28),
              ResourceCompare(
                used: powerUsed,
                all: allPower,
                unit: 'MW',
              ),
            ]),
            Table(
              columnWidths: const {
                0: FixedColumnWidth(28),
                1: FlexColumnWidth(),
                2: FixedColumnWidth(10),
                3: FixedColumnWidth(28),
                4: FlexColumnWidth(),
              },
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: <TableRow>[
                TableRow(children: [
                  const Image(image: rigImage, height: 28),
                  ResourceCompare(
                    align: TextAlign.end,
                    used: ship.hull.attributes[upgradeUsed] ?? 0.0,
                    all: ship.hull.attributes[upgradeCapacity] ?? 0.0,
                    warning: false,
                  ),
                  const SizedBox.shrink(),
                  const Image(image: weaponDroneImage, height: 28),
                  // const SizedBox.shrink(),
                  ResourceCompare(
                    align: TextAlign.end,
                    used: ship.hull.attributes[droneBandwidthLoad] ?? 0,
                    all: ship.hull.attributes[droneBandwidth] ?? 0,
                    unit: 'mb/s',
                    warning: false,
                  )
                ])
              ],
            )
          ],
        ),
      ),
    );
  }
}
