part of 'fit.dart';

class InfoTab extends ConsumerWidget {
  final String fitID;

  const InfoTab({super.key, required this.fitID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitRef = ref.watch(fitRecordNotifierProvider(fitID));
    final out = fitRef.output.ship;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        child: Column(
          children: [
            Capacitor(ship: out),
            Weapon(ship: out),
            Resource(ship: out),
            Hp(ship: out),
            Extra(ship: out),
          ],
        ),
      ),
    );
  }
}
