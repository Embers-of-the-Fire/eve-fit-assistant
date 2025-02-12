part of 'fit.dart';

class InfoTab extends ConsumerWidget {
  final String fitID;

  const InfoTab({super.key, required this.fitID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fitRef = ref.read(fitRecordNotifierProvider(fitID));
    final out = fitRef.output.ship;

    return Center(
      child: Text(
        (out.hull.attributes.getById(key: damagePerSecondWithoutReload) ?? 0.0)
            .toString(),
      ),
    );
  }
}
