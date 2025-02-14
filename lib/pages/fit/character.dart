part of 'fit.dart';

class CharacterTab extends StatelessWidget {
  final String fitID;
  final List<SlotItem?> implants;

  final ScrollController _controller = ScrollController();

  CharacterTab({super.key, required this.fitID, required this.implants});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10),
      child: ListView(
        controller: _controller,
        children: [
          ...implants.enumerate().map((t) {
            final index = t.$1;
            final el = t.$2;
            return getSlotRow(
              fitID,
              el,
              type: FitItemType.implant,
              index: index,
              slotType: FitItemType.implant,
            );
          })
        ],
      ),
    );
  }
}
