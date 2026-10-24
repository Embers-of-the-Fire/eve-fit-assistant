part of "page.dart";

class DataChannelTile extends ConsumerStatefulWidget {
  const DataChannelTile({super.key});

  @override
  ConsumerState<DataChannelTile> createState() => _DataChannelTileState();
}

class _DataChannelTileState extends ConsumerState<DataChannelTile> {
  bool _switching = false;

  @override
  Widget build(BuildContext context) {
    final channelName = ref.watch(
      appSettingServiceProvider.select((setting) => setting.remoteContent.channel),
    );
    final channel = Channel.tryParse(channelName) ?? Channel.defaultChannel;
    return ListTile(
      leading: const Icon(Icons.cloud_outlined),
      title: Text(context.l10n.appSettingsPageDataChannelTitle),
      subtitle: Text(context.l10n.appSettingsPageDataChannelDescription),
      trailing: _switching
          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          : DropdownButton<Channel>(
              value: channel,
              items: Channel.values
                  .map(
                    (c) => DropdownMenuItem<Channel>(
                      value: c,
                      child: Text(switch (c) {
                        Channel.testing => context.l10n.appSettingsPageRemoteContentChannelTesting,
                        Channel.stable => context.l10n.appSettingsPageRemoteContentChannelStable,
                      }),
                    ),
                  )
                  .toList(),
              onChanged: (next) {
                if (next != null) unawaited(_switchTo(next));
              },
            ),
    );
  }

  Future<void> _switchTo(Channel next) async {
    final current = ref.read(appSettingServiceProvider).remoteContent.channel;
    if (next.value == current) return;
    final confirmed = await showConfirmDialog(
      context,
      title: context.l10n.appSettingsPageDataChannelSwitchConfirmTitle,
      content: Text(context.l10n.appSettingsPageRemoteContentChannelSwitchDescription),
    );
    if (!confirmed || !mounted) return;
    setState(() => _switching = true);
    // The action commits the new channel to settings on success; the widget
    // only surfaces a failure, which is safe to skip once disposed.
    final failure = await ref.read(channelSwitchActionProvider)(next.value);
    if (!mounted) return;
    setState(() => _switching = false);
    if (failure != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.appSettingsPageRemoteContentChannelSwitchFailed(error: failure),
          ),
        ),
      );
    }
  }
}

class DataCadenceTile extends ConsumerWidget {
  const DataCadenceTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appSettingServiceProvider.select((setting) => setting.remoteContent));
    final channel = Channel.tryParse(config.channel) ?? Channel.defaultChannel;
    final cadence = DataCadence.parse(config.cadence);
    final isTesting = channel == Channel.testing;
    return ListTile(
      leading: const Icon(Icons.schedule_outlined),
      title: Text(context.l10n.appSettingsPageDataCadenceTitle),
      subtitle: Text(
        isTesting
            ? context.l10n.appSettingsPageRemoteContentCadenceTestingHint
            : context.l10n.appSettingsPageDataCadenceDescription,
      ),
      trailing: DropdownButton<DataCadence>(
        value: cadence,
        items: DataCadence.values
            .map(
              (c) => DropdownMenuItem<DataCadence>(
                value: c,
                child: Text(switch (c) {
                  DataCadence.immediate =>
                    context.l10n.appSettingsPageRemoteContentCadenceImmediate,
                  DataCadence.weekly => context.l10n.appSettingsPageRemoteContentCadenceWeekly,
                  DataCadence.monthly => context.l10n.appSettingsPageRemoteContentCadenceMonthly,
                }),
              ),
            )
            .toList(),
        // The cadence preference is inert on the testing channel, which
        // always tracks immediately; the stored value is left untouched.
        onChanged: isTesting
            ? null
            : (value) {
                if (value == null) return;
                ref
                    .read(appSettingServiceProvider.notifier)
                    .update((setting) => setting.copyWith.remoteContent(cadence: value.value));
              },
      ),
    );
  }
}
