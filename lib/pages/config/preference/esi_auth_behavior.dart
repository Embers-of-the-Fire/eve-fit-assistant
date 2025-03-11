part of '../preference.dart';

class EsiAuthBehaviorTile extends StatefulWidget {
  const EsiAuthBehaviorTile({super.key});

  @override
  State<EsiAuthBehaviorTile> createState() => _EsiAuthBehaviorTileState();
}

class _EsiAuthBehaviorTileState extends State<EsiAuthBehaviorTile> {
  bool value = false;

  @override
  void initState() {
    super.initState();
    value = GlobalPreference.esiAuthBehavior == EsiAuthBehavior.doubleCheck;
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
        value: value,
        onChanged: (value) => setState(() {
          GlobalPreference.esiAuthBehavior =
              value ? EsiAuthBehavior.doubleCheck : EsiAuthBehavior.immediate;
          this.value = value;
        }),
        title: const Text('授权二次确认'),
        subtitle: const Text('是否在进入授权页面时弹出二次确认弹窗。'),
      );
}
