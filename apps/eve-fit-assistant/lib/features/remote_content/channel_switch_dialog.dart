import "dart:async";

import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/components/wizard/wizard_option_tile.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/remote_content/channel_switch.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// Opens the channel switch dialog. The dialog owns the whole switch flow:
/// selection, the stable-to-testing warning, running
/// [channelSwitchActionProvider], and surfacing failures inline.
Future<void> showChannelSwitchDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (context) => const ChannelSwitchDialog());

/// Dedicated dialog for switching the data channel between stable and
/// testing. Used by the settings tile and by the `efa://action/switch-channel`
/// content link.
class ChannelSwitchDialog extends ConsumerStatefulWidget {
  const ChannelSwitchDialog({super.key});

  @override
  ConsumerState<ChannelSwitchDialog> createState() => _ChannelSwitchDialogState();
}

class _ChannelSwitchDialogState extends ConsumerState<ChannelSwitchDialog> {
  // Null until the user picks a channel explicitly; the selection then
  // follows the currently stored channel.
  Channel? _selected;
  bool _switching = false;
  String? _failure;

  Channel get _current {
    final stored = ref.read(appSettingServiceProvider).remoteContent.channel;
    return Channel.tryParse(stored) ?? Channel.defaultChannel;
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(
      appSettingServiceProvider.select(
        (setting) => Channel.tryParse(setting.remoteContent.channel) ?? Channel.defaultChannel,
      ),
    );
    final selected = _selected ?? current;
    final canApply = !_switching && selected != current;

    return PopScope(
      canPop: !_switching,
      child: AppDialog(
        title: context.l10n.channelSwitchDialogTitle,
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                WizardOptionList(
                  children: [
                    for (final channel in Channel.values)
                      WizardOptionTile(
                        title: switch (channel) {
                          Channel.testing =>
                            context.l10n.appSettingsPageRemoteContentChannelTesting,
                          Channel.stable => context.l10n.appSettingsPageRemoteContentChannelStable,
                        },
                        subtitle: switch (channel) {
                          Channel.testing => context.l10n.channelSwitchDialogTestingDescription,
                          Channel.stable => context.l10n.channelSwitchDialogStableDescription,
                        },
                        badge: channel == current
                            ? context.l10n.channelSwitchDialogCurrentBadge
                            : null,
                        selected: channel == selected,
                        onTap: _switching
                            ? () {}
                            : () => setState(() {
                                _selected = channel;
                                _failure = null;
                              }),
                      ),
                  ],
                ),
                if (_failure != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      context.l10n.appSettingsPageRemoteContentChannelSwitchFailed(
                        error: _failure!,
                      ),
                      style: context.theme.textTheme.bodySmall?.copyWith(
                        color: context.theme.colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _switching ? null : () => context.nav.pop(),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: canApply ? () => unawaited(_apply(selected)) : null,
            child: _switching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.channelSwitchDialogSwitchButton),
          ),
        ],
      ),
    );
  }

  Future<void> _apply(Channel target) async {
    if (_current == Channel.stable && target == Channel.testing) {
      final confirmed = await showConfirmDialog(
        context,
        title: context.l10n.channelSwitchToTestingWarningTitle,
        content: Text(context.l10n.channelSwitchToTestingWarningDescription),
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      _switching = true;
      _failure = null;
    });
    // The action commits the new channel to settings on success; the dialog
    // only surfaces a failure inline, which is safe to skip once disposed.
    // Exceptions from rebind or re-initialization are not converted to error
    // strings by the action, so catch them here to restore the dialog state.
    final String? failure;
    try {
      failure = await ref.read(channelSwitchActionProvider)(target.value);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _switching = false;
        _failure = error.toString();
      });
      return;
    }
    if (!mounted) return;
    setState(() {
      _switching = false;
      _failure = failure;
    });
    if (failure == null) {
      context.nav.pop();
    }
  }
}
