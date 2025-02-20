part of 'item_info.dart';

class TraitsTab extends StatelessWidget {
  final int typeID;

  const TraitsTab({super.key, required this.typeID});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: SingleChildScrollView(
          child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              // child: Text(GlobalStorage().static.types[typeID]?.traits ?? '',
              //     style: const TextStyle(fontSize: 18)),
              child: DescriptionText(
                  text: GlobalStorage().static.types[typeID]?.traits ?? '',
                  style: const TextStyle(fontSize: 18))),
        ),
      );
}
