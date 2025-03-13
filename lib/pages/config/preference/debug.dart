part of '../preference.dart';

class DebugTile extends ConsumerStatefulWidget {
  const DebugTile({super.key});

  @override
  ConsumerState<DebugTile> createState() => _DebugTileState();
}

class _DebugTileState extends ConsumerState<DebugTile> {
  bool value = false;

  @override
  void initState() {
    value = ref.read(globalPreferenceProvider).preference.debug == Debug.enable;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(globalPreferenceProvider.notifier);
    return SwitchListTile(
      value: value,
      onChanged: (value) => setState(() {
        notifier.modify((preference) => preference.debug = value ? Debug.enable : Debug.disable);
        this.value = value;
      }),
      title: const Text('调试模式'),
      subtitle: const Text('是否启用调试模式。'),
    );
  }
}
