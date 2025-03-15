part of '../preference.dart';

class EsiAuthBehaviorTile extends ConsumerStatefulWidget {
  const EsiAuthBehaviorTile({super.key});

  @override
  ConsumerState<EsiAuthBehaviorTile> createState() => _EsiAuthBehaviorTileState();
}

class _EsiAuthBehaviorTileState extends ConsumerState<EsiAuthBehaviorTile> {
  bool value = false;

  @override
  void initState() {
    super.initState();
    value = ref.read(globalPreferenceProvider).preference.esiAuthBehavior ==
        EsiAuthBehavior.doubleCheck;
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(globalPreferenceProvider.notifier);

    return SwitchListTile(
      value: value,
      onChanged: (value) => setState(() {
        notifier.modify((preference) => preference.esiAuthBehavior =
            value ? EsiAuthBehavior.doubleCheck : EsiAuthBehavior.immediate);
        this.value = value;
      }),
      title: const Text('授权二次确认'),
      subtitle: const Text('是否在进入授权页面时弹出二次确认弹窗。'),
    );
  }
}

class EsiAuthServerTile extends ConsumerStatefulWidget {
  const EsiAuthServerTile({super.key});

  @override
  ConsumerState<EsiAuthServerTile> createState() => _EsiAuthServerTileState();
}

class _EsiAuthServerTileState extends ConsumerState<EsiAuthServerTile> {
  EsiAuthServer value = EsiAuthServer.tranquility;

  @override
  void initState() {
    super.initState();
    value = ref.read(globalPreferenceProvider).preference.esiAuthServer;
  }

  @override
  Widget build(BuildContext context) {
    final preference = ref.watch(globalPreferenceProvider).preference;
    final notifier = ref.read(globalPreferenceProvider.notifier);
    final dataNotifier = ref.read(esiDataStorageProvider.notifier);

    return ListTile(
      title: const Text('ESI 服务器'),
      subtitle: const Text('绑定的本地账号的服务器'),
      trailing: DropdownButton(
          value: value,
          items: const <DropdownMenuItem<EsiAuthServer>>[
            DropdownMenuItem(value: EsiAuthServer.tranquility, child: Text('欧服')),
            DropdownMenuItem(value: EsiAuthServer.serenity, child: Text('国服')),
          ],
          onChanged: preference.esiAuthBehavior == EsiAuthBehavior.doubleCheck
              ? (EsiAuthServer? value) => setState(() {
                    if (value == null) return;
                    notifier.modify((preference) => preference.esiAuthServer = value);
                    this.value = value;
                    if (preference.esiAuthServer != value) dataNotifier.clearAuthorize();
                  })
              : null),
    );
  }
}
