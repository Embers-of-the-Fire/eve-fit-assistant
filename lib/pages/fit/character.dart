part of 'fit.dart';

class CharacterTab extends ConsumerWidget {
  final String fitID;

  final ScrollController _controller = ScrollController();

  CharacterTab({super.key, required this.fitID});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fit = ref.watch(fitRecordNotifierProvider(fitID));

    return Container(
      padding: const EdgeInsets.only(top: 10),
      child: ListView(
        controller: _controller,
        children: [
          ...fit.fit.body.implant.enumerate().map((t) {
            final index = t.$1;
            final el = t.$2;
            return getSlotRow(fitID, el, type: FitItemType.implant, index: index);
          })
        ],
      ),
    );
  }
}
