import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:eve_fit_assistant/features/welcome/welcome_step_template.dart";
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

  final VoidCallback onContinue;
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

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).name;
    final overview = ref.watch(channelOverviewProvider);

    return WelcomeStepTemplate(
      title: context.l10n.welcomeChannelTitle,
      subtitle: context.l10n.welcomeChannelSubtitle,
      onContinue: widget.onContinue,
      onSkip: widget.onSkip,
      onBack: widget.onBack,
      content: overview.when(
        loading: () => const _ChannelLoading(),
        error: (_, _) => _ChannelError(onRetry: () => ref.invalidate(channelOverviewProvider)),
        data: (data) => _buildList(context, data, locale),
      ),
    );
  }

  Widget _buildList(BuildContext context, ChannelOverview data, String locale) {
    final channels = data.channels;
    if (channels.isEmpty) {
      return _ChannelError(
        onRetry: () => ref.invalidate(channelOverviewProvider),
        message: context.l10n.welcomeChannelEmpty,
      );
    }

    final names = channels.keys.toList();
    final selected = names.contains(_selected)
        ? _selected
        : (names.contains(data.defaultChannel) ? data.defaultChannel : names.first);

    return Column(
      children: [
        for (final name in names)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ChannelCard(
              name: _resolveLabel(channels[name]!, name, locale),
              isSelected: name == selected,
              isDefault: name == data.defaultChannel,
              onTap: () => setState(() => _selected = name),
            ),
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

class _ChannelCard extends StatelessWidget {
  const _ChannelCard({
    required this.name,
    required this.isSelected,
    required this.isDefault,
    required this.onTap,
  });

  final String name;
  final bool isSelected;
  final bool isDefault;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outline.withValues(alpha: 0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      color: isSelected ? colorScheme.primaryContainer.withValues(alpha: 0.2) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w600 : null,
                        ),
                      ),
                    ),
                    if (isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          context.l10n.welcomeChannelDefaultBadge,
                          style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.primary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isSelected) Icon(Icons.check, color: colorScheme.primary, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelLoading extends StatelessWidget {
  const _ChannelLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Center(child: CircularProgressIndicator()),
  );
}

class _ChannelError extends StatelessWidget {
  const _ChannelError({required this.onRetry, this.message});

  final VoidCallback onRetry;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off, size: 48, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            message ?? context.l10n.welcomeChannelError,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: Text(context.l10n.fitPageRetryAction)),
        ],
      ),
    );
  }
}
