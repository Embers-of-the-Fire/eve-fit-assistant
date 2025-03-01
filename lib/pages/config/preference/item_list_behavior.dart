part of '../preference.dart';

class ItemListPopBehaviorTile extends StatefulWidget {
  const ItemListPopBehaviorTile({super.key});

  @override
  State<ItemListPopBehaviorTile> createState() => _ItemListPopBehaviorTileState();
}

class _ItemListPopBehaviorTileState extends State<ItemListPopBehaviorTile> {
  bool value = false;

  @override
  void initState() {
    value = GlobalPreference.itemListPopBehavior == ItemListPopBehavior.exit;
    super.initState();
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: value,
        onChanged: (v) async {
          setState(() => value = v);
          GlobalPreference.itemListPopBehavior =
              v ? ItemListPopBehavior.exit : ItemListPopBehavior.prevPage;
        },
        title: const Text('物品列表直接返回'),
        subtitle: const Text('在物品列表页面中返回时是否直接退出页面'),
      );
}
