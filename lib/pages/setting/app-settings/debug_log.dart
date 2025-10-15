part of 'page.dart';

class DebugLogTile extends ConsumerStatefulWidget {
  const DebugLogTile({super.key});

  @override
  ConsumerState createState() => _DebugLogTileState();
}

class _DebugLogTileState extends ConsumerState<DebugLogTile> {
  bool enabled = false;

  @override
  void initState() {
    super.initState();
    enabled = ref.read(appSettingServiceProvider).enableDebugLog;
  }

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text(context.l10n.appSettingsPageDebugLogTitle),
      value: enabled,
      onChanged: (value) async {
        setState(() {
          enabled = value;
        });
        ref
            .read(appSettingServiceProvider.notifier)
            .update((setting) => setting.copyWith(enableDebugLog: value));
      },
    );
  }
}
