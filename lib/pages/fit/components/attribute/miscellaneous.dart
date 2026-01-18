part of "../../page.dart";

class Miscellaneous extends StatelessWidget {
  const Miscellaneous({required this.ship, super.key});
  final native.Ship ship;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.only(left: 14, right: 22, top: 8, bottom: 8),
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
        children: _getMiscTableContent(ship),
      ),
    ),
  );
}

List<TableRow> _getMiscTableContent(native.Ship ship) {
  final List<TableRow> rows = [];
  final hull = ship.hull;
  final character = ship.character;

  {
    // speed & warp speed
    final List<Widget> children = [];
    final speed = hull.getAttribute(EveConstAttrID.maxVelocity);
    children
      ..add(const Image(image: ImageAssets.attrSpeed, height: 28))
      ..add(Text("${speed.toStringAsMaxDecimals(1)} m/s"))
      ..add(const SizedBox.shrink());

    final warpSpeedValue = hull.getAttribute(EveConstExtendedAttrID.warpSpeed);
    children
      ..add(const Image(image: ImageAssets.attrWarpSpeed, height: 28))
      ..add(Text("${warpSpeedValue.toStringAsMaxDecimals(1)} AU/s"));
    rows.add(TableRow(children: children));
  }

  {
    // target range & scan resolution
    final List<Widget> children = [];
    final targetRange = hull.getAttribute(EveConstAttrID.maxTargetRange);
    children
      ..add(const Image(image: ImageAssets.attrTargetRange, height: 28))
      ..add(Text("${(targetRange / 1000).toStringAsFixed(0)} km"))
      ..add(const SizedBox.shrink());

    final scanRes = hull.getAttribute(EveConstAttrID.scanResolution);
    children
      ..add(const Image(image: ImageAssets.attrScanResolution, height: 28))
      ..add(Text("${scanRes.toStringAsFixed(0)} mm"));
    rows.add(TableRow(children: children));
  }

  {
    // max target num & scan strength
    final List<Widget> children = [];
    final maxTargetNum = hull.getAttribute(EveConstAttrID.maxLockedTargets).round();
    children
      ..add(const Image(image: ImageAssets.attrLockNum, height: 28))
      ..add(Text("$maxTargetNum"))
      ..add(const SizedBox.shrink());
    final pair = _getMaxRadarStrength(hull);
    children
      ..add(Image(image: pair.$1, height: 28))
      ..add(Text(pair.$2.toStringAsMaxDecimals(1)));
    rows.add(TableRow(children: children));
  }

  {
    // align time & signature radius
    final List<Widget> children = [];
    final align = hull.getAttribute(EveConstExtendedAttrID.alignTime);
    children
      ..add(const Image(image: ImageAssets.attrAlignTime, height: 28))
      ..add(Text("${align.toStringAsMaxDecimals(2)} s"))
      ..add(const SizedBox.shrink());
    final sigRadius = hull.getAttribute(EveConstAttrID.signatureRadius);
    children
      ..add(const Image(image: ImageAssets.attrSignatureRadius, height: 28))
      ..add(Text("${sigRadius.toStringAsMaxDecimals(0)} m"));
    rows.add(TableRow(children: children));
  }

  {
    // max drone & drone range
    final List<Widget> children = [];
    final maxDrone = character.getAttribute(EveConstAttrID.maxActiveDrones).round();
    children
      ..add(const Image(image: ImageAssets.attrDrone, height: 28))
      ..add(Text("$maxDrone"))
      ..add(const SizedBox.shrink());
    final droneRange = character.getAttribute(EveConstAttrID.droneControlDistance);
    children
      ..add(const Image(image: ImageAssets.attrDroneRange, height: 28))
      ..add(Text("${(droneRange / 1000).toStringAsMaxDecimals(1)} km"));
    rows.add(TableRow(children: children));
  }

  return rows;
}

(ImageProvider, double) _getMaxRadarStrength(native.Item hull) {
  final radar = hull.getAttribute(EveConstAttrID.scanRadarStrength);
  final ladar = hull.getAttribute(EveConstAttrID.scanLadarStrength);
  final magnetometric = hull.getAttribute(EveConstAttrID.scanMagnetometricStrength);
  final gravimetric = hull.getAttribute(EveConstAttrID.scanGravimetricStrength);

  if (radar >= ladar && radar >= magnetometric && radar >= gravimetric) {
    return (ImageAssets.attrScanRadar, radar);
  } else if (ladar >= radar && ladar >= magnetometric && ladar >= gravimetric) {
    return (ImageAssets.attrScanLadar, ladar);
  } else if (magnetometric >= radar && magnetometric >= ladar && magnetometric >= gravimetric) {
    return (ImageAssets.attrScanMagnetometric, magnetometric);
  } else {
    return (ImageAssets.attrScanGravimetric, gravimetric);
  }
}
