part of "page.dart";

class DebugLogTile extends ConsumerStatefulWidget {
  const DebugLogTile({super.key});

  @override
  ConsumerState createState() => _DebugLogTileState();
}

class _DebugLogTileState extends ConsumerState<DebugLogTile> {
  bool enabled = false;
  late final bool initialEnabled;

  @override
  void initState() {
    super.initState();
    enabled = ref.read(appSettingServiceProvider).enableDebugLog;
    initialEnabled = enabled;
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
    secondary: const Icon(FontAwesomeIcons.terminal),
    title: Text.rich(
      TextSpan(
        children: [
          TextSpan(text: context.l10n.appSettingsPageDebugLogTitle),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InfoButton(
              title: context.l10n.appSettingsPageDebugLogTitle,
              content: () => Text(context.l10n.appSettingsPageDebugLogDescription),
            ),
          ),
        ],
      ),
    ),
    subtitle: (initialEnabled != enabled).then(
      () => Text(
        context.l10n.applyAfterRestart,
        style: context.theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
      ),
    ),
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
