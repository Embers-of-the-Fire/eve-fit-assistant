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
    secondary: const FaIcon(FontAwesomeIcons.terminal),
    title: const Text.rich(
      TextSpan(
        children: [
          TextSpan(text: "Enable Debug Log"),
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: InfoButton(title: "Enable Debug Log", content: _debugLogDescription),
          ),
        ],
      ),
    ),
    subtitle: (initialEnabled != enabled).then(
      () => Text(
        "Apply after restart",
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

Widget _debugLogDescription() => const Text(
  "The application will print all logs to the logging directory when this feature is activated.\n"
  "It's suggested not to enable this unless a developer requires the activation.",
);
