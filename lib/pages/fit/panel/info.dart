part of 'fit.dart';

class InfoTab extends ConsumerWidget {
  final String fitID;

  const InfoTab({super.key, required this.fitID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitRef = ref.watch(fitRecordNotifierProvider(fitID));
    final out = fitRef.output.ship;
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      child: SingleChildScrollView(
        child: Column(
          children: [
            ShipInfo(fitID: fitID),
            const Divider(height: 0),
            Capacitor(ship: out),
            Weapon(ship: out),
            Resource(ship: out),
            Hp(fitID: fitID, ship: out),
            Extra(ship: out),
          ],
        ),
      ),
    );
  }
}
