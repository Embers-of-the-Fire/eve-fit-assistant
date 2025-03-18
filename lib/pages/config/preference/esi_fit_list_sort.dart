part of '../preference.dart';

class EsiFitListSortMethodTile extends ConsumerStatefulWidget {
  const EsiFitListSortMethodTile({super.key});

  @override
  ConsumerState createState() => _EsiFitListSortMethodTileState();
}

class _EsiFitListSortMethodTileState extends ConsumerState<EsiFitListSortMethodTile> {
  EsiFitListSortMethod value = EsiFitListSortMethod.defaultValue;

  @override
  void initState() {
    super.initState();
    value = ref.read(globalPreferenceProvider).preference.esiFitListSortMethod;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(globalPreferenceProvider.notifier);
    final dataNotifier = ref.read(esiDataStorageProvider.notifier);

    return ListTile(
      title: const Text('装配列表排序方法'),
      subtitle: const Text('保留：使用默认排序\n舰船：按照舰船排序\nID：按照配置 ID 排序'),
      trailing: DropdownButton(
          value: value,
          items: const <DropdownMenuItem<EsiFitListSortMethod>>[
            DropdownMenuItem(value: EsiFitListSortMethod.preserve, child: Text('保留')),
            DropdownMenuItem(value: EsiFitListSortMethod.ship, child: Text('舰船')),
            DropdownMenuItem(value: EsiFitListSortMethod.internalID, child: Text('ID')),
          ],
          onChanged: (value) => setState(() {
                if (value == null) return;
                notifier.modify((preference) => preference.esiFitListSortMethod = value);
                dataNotifier.clearCache();
                this.value = value;
              })),
    );
  }
}

class EsiFitListSortSequenceTile extends ConsumerStatefulWidget {
  const EsiFitListSortSequenceTile({super.key});

  @override
  ConsumerState createState() => _EsiFitListSortSequenceTileState();
}

class _EsiFitListSortSequenceTileState extends ConsumerState<EsiFitListSortSequenceTile> {
  EsiFitListSortSequence value = EsiFitListSortSequence.defaultValue;

  @override
  void initState() {
    super.initState();
    value = ref.read(globalPreferenceProvider).preference.esiFitListSortSequence;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(globalPreferenceProvider.notifier);
    final dataNotifier = ref.read(esiDataStorageProvider.notifier);

    return ListTile(
      title: const Text('装配列表排序顺序'),
      trailing: DropdownButton(
          value: value,
          items: const <DropdownMenuItem<EsiFitListSortSequence>>[
            DropdownMenuItem(value: EsiFitListSortSequence.ascending, child: Text('升序')),
            DropdownMenuItem(value: EsiFitListSortSequence.descending, child: Text('降序')),
          ],
          onChanged: (value) => setState(() {
                if (value == null) return;
                notifier.modify((preference) => preference.esiFitListSortSequence = value);
                dataNotifier.clearCache();
                this.value = value;
              })),
    );
  }
}
