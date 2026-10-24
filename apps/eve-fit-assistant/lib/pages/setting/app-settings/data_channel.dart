part of "page.dart";

class DataChannelTile extends ConsumerWidget {
  const DataChannelTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channelName = ref.watch(
      appSettingServiceProvider.select((setting) => setting.remoteContent.channel),
    );
    final channel = Channel.tryParse(channelName) ?? Channel.defaultChannel;
    return ListTile(
      leading: const Icon(Icons.cloud_outlined),
      title: Text(context.l10n.appSettingsPageDataChannelTitle),
      subtitle: Text(context.l10n.appSettingsPageDataChannelDescription),
      trailing: Text(switch (channel) {
        Channel.testing => context.l10n.appSettingsPageRemoteContentChannelTesting,
        Channel.stable => context.l10n.appSettingsPageRemoteContentChannelStable,
      }),
      onTap: () => unawaited(showChannelSwitchDialog(context)),
    );
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
