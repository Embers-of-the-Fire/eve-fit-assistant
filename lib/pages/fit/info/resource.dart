part of 'info_component.dart';

class Resource extends StatelessWidget {
  final ShipProxy ship;

  const Resource({super.key, required this.ship});

  @override
  Widget build(BuildContext context) {
    final allCpu = ship.hull.attributes.getById(key: cpuOutput) ?? 0.0;
    final cpuUsed = allCpu - (ship.hull.attributes.getById(key: cpuFree) ?? 0.0);

    final allPower = ship.hull.attributes.getById(key: powerOutput) ?? 0.0;
    final powerUsed = allPower - (ship.hull.attributes.getById(key: powerFree) ?? 0.0);

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 22, top: 8, bottom: 8),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 16),
        textAlign: TextAlign.end,
        child: Table(
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
              const Image(image: cpuImage, height: 28),
              ResourceCompare(
                alignment: MainAxisAlignment.end,
                used: cpuUsed,
                all: allCpu,
                fixed: 1,
                unit: 'tf',
              ),
              const SizedBox.shrink(),
              const Image(image: powerImage, height: 28),
              ResourceCompare(
                alignment: MainAxisAlignment.end,
                used: powerUsed,
                all: allPower,
                unit: 'MW',
              ),
            ])
          ],
        ),
      ),
    );
  }
}
