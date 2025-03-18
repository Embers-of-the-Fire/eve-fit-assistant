part of '../preference.dart';

class EsiFitListSortTile extends ConsumerStatefulWidget {
  const EsiFitListSortTile({super.key});

  @override
  ConsumerState createState() => _EsiFitListSortTileState();
}

class _EsiFitListSortTileState extends ConsumerState<EsiFitListSortTile> {
  EsiFitListSort value = EsiFitListSort.defaultValue;

  @override
  void initState() {
    super.initState();
    value = ref.read(globalPreferenceProvider).preference.esiFitListSort;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(globalPreferenceProvider.notifier);
    final dataNotifier = ref.read(esiDataStorageProvider.notifier);

    return ListTile(
      title: const Text('装配列表排序'),
      subtitle: const Text('保留：使用默认排序\n舰船：按照舰船排序\nID：按照配置 ID 排序'),
      trailing: DropdownButton(
          value: value,
          items: const <DropdownMenuItem<EsiFitListSort>>[
            DropdownMenuItem(value: EsiFitListSort.preserve, child: Text('保留')),
            DropdownMenuItem(value: EsiFitListSort.ship, child: Text('舰船')),
            DropdownMenuItem(value: EsiFitListSort.internalID, child: Text('ID')),
          ],
          onChanged: (value) => setState(() {
                if (value == null) return;
                notifier.modify((preference) => preference.esiFitListSort = value);
                dataNotifier.clearCache();
                this.value = value;
              })),
    );
  }
}
