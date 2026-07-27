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
            _ResourceRow(icon: ImageAssets.attrCpu, used: cpuUse, all: cpuCap, unit: "tf"),
            _ResourceRow(icon: ImageAssets.attrPower, used: powerUse, all: powerCap, unit: "MW"),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: _ResourceRow(
                    icon: ImageAssets.attrRig,
                    warning: false,
                    used: ship.hull.getAttribute(EveConstExtendedAttrID.upgradeUsed),
                    all: ship.hull.getAttribute(EveConstAttrID.upgradeCapacity),
                  ),
                ),
                Expanded(
                  child: _ResourceRow(
                    icon: ImageAssets.attrWeaponDrone,
                    warning: false,
                    used: ship.hull.getAttribute(EveConstAttrID.droneBandwidthLoad),
                    all: ship.hull.getAttribute(EveConstAttrID.droneBandwidth),
                    unit: "MB/s",
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({
    required this.icon,
    required this.used,
    required this.all,
    this.unit,
    this.warning = true,
  });

  final ImageProvider icon;
  final double used;
  final double all;
  final String? unit;
  final bool warning;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: .start,
    children: [
      Image(image: icon, height: 28),
      const SizedBox(width: 12),
      Expanded(
        child: ResourceCompare(
          used: used,
          all: all,
          unit: unit,
          align: .end,
          warning: warning,
          bar: true,
        ),
      ),
    ],
  );
}
