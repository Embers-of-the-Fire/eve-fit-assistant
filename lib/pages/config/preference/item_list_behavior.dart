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

class ItemListDisplayStyleTile extends ConsumerStatefulWidget {
  const ItemListDisplayStyleTile({super.key});

  @override
  ConsumerState<ItemListDisplayStyleTile> createState() => _ItemListDisplayStyleTileState();
}

class _ItemListDisplayStyleTileState extends ConsumerState<ItemListDisplayStyleTile> {
  ItemListDisplayStyle value = ItemListDisplayStyle.marketGroup;

  @override
  void initState() {
    super.initState();
    value = ref.read(globalPreferenceProvider).preference.itemListDisplayStyle;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(globalPreferenceProvider.notifier);

    return ListTile(
      title: const Text('舰船列表显示方式'),
      subtitle: const Text('如何显示舰船列表。\n市场：根据市场分类显示\n物品组：根据物品组显示'),
      trailing: DropdownButton(
          value: value,
          items: const <DropdownMenuItem<ItemListDisplayStyle>>[
            DropdownMenuItem(value: ItemListDisplayStyle.marketGroup, child: Text('市场')),
            DropdownMenuItem(value: ItemListDisplayStyle.group, child: Text('物品组')),
          ],
          onChanged: (value) => setState(() {
                if (value == null) return;
                notifier.modify((preference) => preference.itemListDisplayStyle = value);
                this.value = value;
              })),
    );
  }
}
