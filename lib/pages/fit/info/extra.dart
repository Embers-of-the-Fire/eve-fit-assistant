part of 'info_component.dart';

class Extra extends StatelessWidget {
  final ShipProxy ship;

  const Extra({super.key, required this.ship});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          children: _getExtraTableContent(ship.hull),
        ),
      ),
    );
  }
}

List<TableRow> _getExtraTableContent(ItemProxy hull) {
  final List<TableRow> rows = [];

  {
    // speed & warp speed
    final List<Widget> children = [];
    final speed = hull.attributes.getById(key: maxVelocity) ?? 0.0;
    children.add(const Image(image: speedImage));
    children.add(Text('${speed.toStringAsFixed(1)} m/s'));

    children.add(const SizedBox.shrink());

    final warpSpeedBase = hull.attributes.getById(key: baseWarpSpeed) ?? 0.0;
    final warpSpeedFactor = hull.attributes.getById(key: warpSpeedMultiplier) ?? 0.0;
    final warpSpeed = warpSpeedBase * warpSpeedFactor;
    children.add(const Image(image: warpSpeedImage));
    children.add(Text('${warpSpeed.toStringAsFixed(1)} AU/s'));
    rows.add(TableRow(children: children));
  }

  {
    // target range & scan resolution
    final List<Widget> children = [];
    final targetRange = hull.attributes.getById(key: maxTargetRange) ?? 0.0;
    children.add(const Image(image: targetRangeImage));
    children.add(Text('${(targetRange / 1000).toStringAsFixed(0)} km'));

    children.add(const SizedBox.shrink());

    final scanRes = hull.attributes.getById(key: scanResolution) ?? 0.0;
    children.add(const Image(image: scanResolutionImage));
    children.add(Text('${scanRes.toStringAsFixed(0)} mm'));
    rows.add(TableRow(children: children));
  }

  {
    // max target num & scan strength
    final List<Widget> children = [];
    final maxTargetNum = hull.attributes.getById(key: maxLockedTargets) ?? 0;
    children.add(const Image(image: lockNumImage));
    children.add(Text('$maxTargetNum'));

    children.add(const SizedBox.shrink());
    final (image, strength) = _getMaxRadarStrength(hull);
    children.add(Image(image: image));
    children.add(Text(strength.toStringAsFixed(1)));
    rows.add(TableRow(children: children));
  }

  {
    // align time & signature radius
    final List<Widget> children = [];
    final align = hull.attributes.getById(key: alignTime) ?? 0.0;
    children.add(const Image(image: alignTimeImage));
    children.add(Text('${align.toStringAsFixed(2)} s'));

    children.add(const SizedBox.shrink());
    final sigRadius = hull.attributes.getById(key: signatureRadius) ?? 0.0;
    children.add(const Image(image: signatureRadiusImage));
    children.add(Text('${sigRadius.toStringAsFixed(0)} m'));
    rows.add(TableRow(children: children));
  }

  return rows;
}

(AssetImage, double) _getMaxRadarStrength(ItemProxy hull) {
  final radar = hull.attributes.getById(key: scanRadarStrength) ?? 0.0;
  final ladar = hull.attributes.getById(key: scanLadarStrength) ?? 0.0;
  final magnetometric = hull.attributes.getById(key: scanMagnetometricStrength) ?? 0.0;
  final gravimetric = hull.attributes.getById(key: scanGravimetricStrength) ?? 0.0;

  if (radar >= ladar && radar >= magnetometric && radar >= gravimetric) {
    return (scanRadarImage, radar);
  } else if (ladar >= radar && ladar >= magnetometric && ladar >= gravimetric) {
    return (scanLadarImage, ladar);
  } else if (magnetometric >= radar && magnetometric >= ladar && magnetometric >= gravimetric) {
    return (scanMagnetometricImage, magnetometric);
  } else {
    return (scanGravimetricImage, gravimetric);
  }
}
