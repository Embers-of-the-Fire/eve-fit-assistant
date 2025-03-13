part of '../preference.dart';

class ItemListPopBehaviorTile extends ConsumerStatefulWidget {
  const ItemListPopBehaviorTile({super.key});

  @override
  ConsumerState<ItemListPopBehaviorTile> createState() => _ItemListPopBehaviorTileState();
}

class _ItemListPopBehaviorTileState extends ConsumerState<ItemListPopBehaviorTile> {
  bool value = false;

  @override
  void initState() {
    super.initState();
    value = ref.read(globalPreferenceProvider).preference.itemListPopBehavior ==
        ItemListPopBehavior.exit;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(globalPreferenceProvider.notifier);

    return SwitchListTile(
      value: value,
      onChanged: (v) async {
        setState(() => value = v);
        notifier.modify((preference) => preference.itemListPopBehavior =
            v ? ItemListPopBehavior.exit : ItemListPopBehavior.prevPage);
      },
      title: const Text('物品列表直接返回'),
      subtitle: const Text('在物品列表页面中返回时是否直接退出页面'),
    );
  }
}
