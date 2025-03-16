part of 'info_component.dart';

class Cargo extends StatelessWidget {
  final ShipProxy ship;

  const Cargo({super.key, required this.ship});

  @override
  Widget build(BuildContext context) => Column(children: [
        ListTile(
            minTileHeight: 0,
            minVerticalPadding: 0,
            leading: const Image(image: massImage, height: 28),
            title: DefaultTextStyle(
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.end,
              child: Text('${ship.hull.attributes[totalMass].unwrapOr(0.0).moneyFormat} kg'),
            )),
      ]);
}
