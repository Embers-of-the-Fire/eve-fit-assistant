part of "../../page.dart";

class Resource extends StatelessWidget {
  const Resource({required this.ship, super.key});

  final native.Ship ship;

  @override
  Widget build(BuildContext context) {
    final cpuCap = ship.hull.getAttribute(EveConstAttrID.cpuOutput);
    final cpuUse = cpuCap - ship.hull.getAttribute(EveConstExtendedAttrID.cpuFree);

    final powerCap = ship.hull.getAttribute(EveConstAttrID.powerOutput);
    final powerUse = powerCap - ship.hull.getAttribute(EveConstExtendedAttrID.powerFree);

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 22, top: 8, bottom: 8),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 16),
        child: Column(
          spacing: 10,
          children: [
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                const Image(image: ImageAssets.attrCpu, height: 28),
                ResourceCompare(used: cpuUse, all: cpuCap, unit: "tf"),
              ],
            ),
            Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                const Image(image: ImageAssets.attrPower, height: 28),
                ResourceCompare(used: powerUse, all: powerCap, unit: "MW"),
              ],
            ),
            Table(
              columnWidths: const {
                0: FixedColumnWidth(28),
                1: FlexColumnWidth(),
                2: FixedColumnWidth(10),
                3: FixedColumnWidth(28),
                4: FlexColumnWidth(),
              },
              defaultVerticalAlignment: .middle,
              children: <TableRow>[
                TableRow(
                  children: [
                    const Image(image: ImageAssets.attrRig, height: 28),
                    ResourceCompare(
                      align: .end,
                      warning: false,
                      used: ship.hull.getAttribute(EveConstExtendedAttrID.upgradeUsed),
                      all: ship.hull.getAttribute(EveConstAttrID.upgradeCapacity),
                    ),
                    const SizedBox.shrink(),
                    const Image(image: ImageAssets.attrWeaponDrone, height: 28),
                    ResourceCompare(
                      align: .end,
                      warning: false,
                      used: ship.hull.getAttribute(EveConstAttrID.droneBandwidthLoad),
                      all: ship.hull.getAttribute(EveConstAttrID.droneBandwidth),
                      unit: "MB/s",
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
