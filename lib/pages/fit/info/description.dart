part of 'item_info.dart';

class DescriptionTab extends StatelessWidget {
  final int typeID;

  const DescriptionTab({super.key, required this.typeID});

  @override
  Widget build(BuildContext context) {
    final text = GlobalStorage().static.types[typeID]?.description ?? '暂无描述';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Text(text),
        ),
      ),
    );
  }
}
