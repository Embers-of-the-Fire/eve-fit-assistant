import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/features/remote_content/cadence.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class RemoteContentSettingsPage extends ConsumerWidget {
  const RemoteContentSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Layout(
    title: context.l10n.appSettingsPageSectionRemoteContent,
    child: const ConfigListView(
      children: [
        ConfigListTile.custom(RemoteContentPanelVisibleTile()),
        ConfigListTile.custom(RemoteContentEnabledTile()),
        ConfigListTile.custom(RemoteContentEndpointTile()),
      ],
    ),
  );
}

class RemoteContentPanelVisibleTile extends ConsumerWidget {
  const RemoteContentPanelVisibleTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exposed = ref.watch(
      appSettingServiceProvider.select((setting) => setting.remoteContent.exposed),
    );
    return SwitchListTile(
      secondary: const Icon(Icons.visibility_off_outlined),
      title: Text(context.l10n.appSettingsPageRemoteContentPanelVisibleTitle),
      subtitle: Text(context.l10n.appSettingsPageRemoteContentVisibleDescription),
      value: exposed,
      onChanged: (value) {
        ref
            .read(appSettingServiceProvider.notifier)
            .update((setting) => setting.copyWith.remoteContent(exposed: value));
        if (!value) {
          unawaited(context.router.maybePop());
        }
      },
    );
  }
}

class RemoteContentEnabledTile extends ConsumerWidget {
  const RemoteContentEnabledTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(
      appSettingServiceProvider.select((setting) => setting.remoteContent.enabled),
    );
    return SwitchListTile(
      secondary: const Icon(Icons.cloud_sync_outlined),
      title: Text(context.l10n.appSettingsPageRemoteContentEnabledTitle),
      subtitle: Text(context.l10n.appSettingsPageRemoteContentEnabledDescription),
      value: enabled,
      onChanged: (value) => ref
          .read(appSettingServiceProvider.notifier)
          .update((setting) => setting.copyWith.remoteContent(enabled: value)),
    );
  }
}

class RemoteContentEndpointTile extends ConsumerWidget {
  const RemoteContentEndpointTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appSettingServiceProvider.select((setting) => setting.remoteContent));
    final notSet = context.l10n.appSettingsPageRemoteContentNotSet;
    String endpointValue(String value) => value.isEmpty ? notSet : value;

    return ListTile(
      leading: const Icon(Icons.link_outlined),
      title: Text(context.l10n.appSettingsPageRemoteContentEndpointTitle),
      subtitle: Text(
        context.l10n.appSettingsPageRemoteContentEndpointDescription(
          origin: endpointValue(config.originUrl),
          resourceRoot: "",
          channel: endpointValue(config.channel),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showRemoteContentEndpointDialog(context, ref, config),
    );
  }
}

Future<void> _showRemoteContentEndpointDialog(
  BuildContext context,
  WidgetRef ref,
  RemoteContentSetting config,
) async {
  final result = await showDialog<RemoteContentSetting>(
    context: context,
    builder: (context) => _RemoteContentEndpointDialog(config: config),
  );
  if (result == null || !context.mounted) {
    return;
  }
  ref
      .read(appSettingServiceProvider.notifier)
      .update((setting) => setting.copyWith(remoteContent: result));

  // A changed channel is a real switch: sync the target channel, re-bind every
  // checkout, and force all update checks to re-resolve against it.
  if (result.channel != config.channel) {
    await _switchChannel(ref, result.channel);
  }
}

/// Performs the channel switch: discovers the registry, syncs the target
/// channel's generation (including the promoted history), re-binds checkouts,
/// and invalidates every consumer of channel state so tiles re-check
/// immediately against the new channel.
Future<void> _switchChannel(WidgetRef ref, String channel) async {
  final repo = ref.read(repoServiceProvider);
  await repo.discoverChannels();
  await repo.syncChannelGeneration(channel);
  await ref.read(dataUpdateServiceProvider).rebindCheckoutsToChannel(channel);

  ref
    ..invalidate(repoStateProvider)
    ..invalidate(batchDataUpdateControllerProvider);
  for (final checkoutId in ref.read(installedCheckoutIdsProvider)) {
    ref.invalidate(checkoutUpdateControllerProvider(checkoutId));
  }
  ref.invalidate(appReleaseCheckStatusProvider);
}

class _RemoteContentEndpointDialog extends StatefulWidget {
  const _RemoteContentEndpointDialog({required this.config});

  final RemoteContentSetting config;

  @override
  State<_RemoteContentEndpointDialog> createState() => _RemoteContentEndpointDialogState();
}

class _RemoteContentEndpointDialogState extends State<_RemoteContentEndpointDialog> {
  late final TextEditingController originController;
  late Channel _channel;
  late DataCadence _cadence;

  @override
  void initState() {
    super.initState();
    originController = TextEditingController(text: widget.config.originUrl);
    _channel = Channel.tryParse(widget.config.channel) ?? Channel.defaultChannel;
    _cadence = DataCadence.parse(widget.config.cadence);
  }

  @override
  void dispose() {
    originController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.l10n.appSettingsPageRemoteContentEndpointTitle),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: originController,
            decoration: InputDecoration(
              labelText: context.l10n.appSettingsPageRemoteContentOriginUrlLabel,
              hintText: context.l10n.appSettingsPageRemoteContentUrlHint,
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
          ),
          DropdownButtonFormField<Channel>(
            initialValue: _channel,
            decoration: InputDecoration(
              labelText: context.l10n.appSettingsPageRemoteContentChannelLabel,
            ),
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
            onChanged: (value) {
              if (value != null) {
                setState(() => _channel = value);
              }
            },
          ),
          if (_channel != Channel.tryParse(widget.config.channel))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.appSettingsPageRemoteContentChannelSwitchDescription,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          DropdownButtonFormField<DataCadence>(
            initialValue: _cadence,
            decoration: InputDecoration(
              labelText: context.l10n.appSettingsPageRemoteContentCadenceLabel,
            ),
            items: DataCadence.values
                .map(
                  (c) => DropdownMenuItem<DataCadence>(
                    value: c,
                    child: Text(switch (c) {
                      DataCadence.immediate =>
                        context.l10n.appSettingsPageRemoteContentCadenceImmediate,
                      DataCadence.weekly => context.l10n.appSettingsPageRemoteContentCadenceWeekly,
                      DataCadence.monthly =>
                        context.l10n.appSettingsPageRemoteContentCadenceMonthly,
                    }),
                  ),
                )
                .toList(),
            // The cadence preference is inert on the testing channel, which
            // always tracks immediately; the stored value is left untouched.
            onChanged: _channel == Channel.testing
                ? null
                : (value) {
                    if (value != null) {
                      setState(() => _cadence = value);
                    }
                  },
          ),
          if (_channel == Channel.testing)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                context.l10n.appSettingsPageRemoteContentCadenceTestingHint,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(
          widget.config.copyWith(
            originUrl: originController.text.trim(),
            channel: _channel.value,
            cadence: _cadence.value,
          ),
        ),
        child: Text(MaterialLocalizations.of(context).saveButtonLabel),
      ),
    ],
  );
}
