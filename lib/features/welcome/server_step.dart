import "package:eve_fit_assistant/components/wizard/wizard.dart";
import "package:eve_fit_assistant/storage/repo/generation_nav.dart";
import "package:eve_fit_assistant/storage/repo/providers.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart" show localeProvider;
import "package:eve_fit_assistant/utils/context.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

class ServerStepPage extends ConsumerStatefulWidget {
  const ServerStepPage({
    required this.channelName,
    required this.onContinue,
    required this.onSkip,
    required this.onBack,
    super.key,
  });

  final String channelName;
  final VoidCallback onContinue;
  final VoidCallback onSkip;
  final VoidCallback onBack;

  @override
  ConsumerState<ServerStepPage> createState() => _ServerStepPageState();
}

class _ServerStepPageState extends ConsumerState<ServerStepPage> {
  String? _selectedServerId;

  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeProvider).name;
    final servers = ref.watch(serverListProvider(widget.channelName));

    return WizardScaffold(
      title: context.l10n.welcomeServerTitle,
      subtitle: context.l10n.welcomeServerSubtitle,
      primaryLabel: context.l10n.welcomeContinueButton,
      onPrimary: widget.onContinue,
      secondaryActions: [
        WizardAction(label: context.l10n.welcomeBackButton, onPressed: widget.onBack),
        WizardAction(label: context.l10n.welcomeSkipButton, onPressed: widget.onSkip),
      ],
      content: WizardAsyncContent(
        value: servers,
        onRetry: () => ref.invalidate(serverListProvider(widget.channelName)),
        errorMessage: context.l10n.welcomeServerError,
        retryLabel: context.l10n.fitPageRetryAction,
        builder: (data) => _buildList(context, data, locale),
      ),
    );
  }

  Widget _buildList(BuildContext context, IList<ServerSummary> servers, String locale) {
    if (servers.isEmpty) {
      return WizardContentMessage(
        message: context.l10n.welcomeServerEmpty,
        retryLabel: context.l10n.fitPageRetryAction,
        onRetry: () => ref.invalidate(serverListProvider(widget.channelName)),
      );
    }

    final ids = servers.map((s) => s.serverId).toList();
    final selected = ids.contains(_selectedServerId) ? _selectedServerId! : ids.first;

    return WizardOptionList(
      children: [
        for (final server in servers)
          WizardOptionTile(
            title: server.displayName(locale),
            selected: server.serverId == selected,
            onTap: () => setState(() => _selectedServerId = server.serverId),
          ),
      ],
    );
  }
}
