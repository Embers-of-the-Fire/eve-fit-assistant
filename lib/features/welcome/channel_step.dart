import "package:eve_fit_assistant/components/wizard/wizard.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/storage/repo/generation_nav.dart";
import "package:eve_fit_assistant/storage/repo/models/channel_registry.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart" show localeProvider;
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class ChannelStepPage extends ConsumerStatefulWidget {
  const ChannelStepPage({
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
    super.key,
  });

  final ValueChanged<String> onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  ConsumerState<ChannelStepPage> createState() => _ChannelStepPageState();
}

class _ChannelStepPageState extends ConsumerState<ChannelStepPage> {
  // FIXME(welcome): the default channel selection is hardcoded to `testing`.
  // It should follow ChannelOverview.defaultChannel (the registry `active`
  // channel) once the remote registry reliably advertises the intended
  // default; this hardcoding forces `testing` regardless of registry state.
  String? _selected = Channel.testing.value;

  // The channel name reported to [onContinue]; refined to the resolved
  // selection once the channel list is available.
  String _effectiveSelected = Channel.testing.value;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).name;
    final overview = ref.watch(channelOverviewProvider);

    _effectiveSelected = _selected ?? Channel.testing.value;

    return WizardScaffold(
      title: context.l10n.welcomeChannelTitle,
      subtitle: context.l10n.welcomeChannelSubtitle,
      primaryLabel: context.l10n.welcomeContinueButton,
      primaryEnabled: overview.hasValue,
      onPrimary: () => widget.onContinue(_effectiveSelected),
      secondaryActions: [
        WizardAction(label: context.l10n.welcomeBackButton, onPressed: widget.onBack),
        WizardAction(label: context.l10n.welcomeSkipButton, onPressed: widget.onSkip),
      ],
      content: WizardAsyncContent(
        value: overview,
        onRetry: () => ref.invalidate(channelOverviewProvider),
        errorMessage: context.l10n.welcomeChannelError,
        retryLabel: context.l10n.fitPageRetryAction,
        builder: (data) => _buildList(context, data, locale),
      ),
    );
  }

  Widget _buildList(BuildContext context, ChannelOverview data, String locale) {
    final channels = data.channels;
    if (channels.isEmpty) {
      return WizardContentMessage(
        message: context.l10n.welcomeChannelEmpty,
        retryLabel: context.l10n.fitPageRetryAction,
        onRetry: () => ref.invalidate(channelOverviewProvider),
      );
    }

    final names = channels.keys.toList();
    final selected = names.contains(_selected)
        ? _selected!
        : (names.contains(data.defaultChannel) ? data.defaultChannel : names.first);
    _effectiveSelected = selected;

    return WizardOptionList(
      children: [
        for (final name in names)
          WizardOptionTile(
            title: _resolveLabel(channels[name]!, name, locale),
            badge: name == data.defaultChannel ? context.l10n.welcomeChannelDefaultBadge : null,
            selected: name == selected,
            onTap: () => setState(() => _selected = name),
          ),
      ],
    );
  }

  String _resolveLabel(ChannelEntry entry, String name, String locale) {
    final label = entry.label;
    if (label.isEmpty) return name;
    return label[locale] ?? label["en"] ?? label.values.first;
  }
}
