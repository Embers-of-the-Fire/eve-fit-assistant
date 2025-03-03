part of '../preference.dart';

class DebugTile extends StatefulWidget {
  const DebugTile({super.key});

  @override
  State<DebugTile> createState() => _DebugTileState();
}

class _DebugTileState extends State<DebugTile> {
  bool value = false;

  @override
  void initState() {
    value = GlobalPreference.debug == Debug.enable;
    super.initState();
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: value,
        onChanged: (value) => setState(() {
          GlobalPreference.debug = value ? Debug.enable : Debug.disable;
          this.value = value;
        }),
        title: const Text('调试模式'),
        subtitle: const Text('是否启用调试模式。'),
      );
}
