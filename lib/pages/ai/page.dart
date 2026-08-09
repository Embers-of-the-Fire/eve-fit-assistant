import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/features/ai_gate/ai_gate.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

/// The AI assistant hub: the single entry point for every AI surface
/// (chat, history, configuration). Gated by [AiFeatureGate] — first contact
/// shows the AI service notice, then the enable/download/data-required
/// states, and only then the hub itself.
@RoutePage()
class AiPage extends ConsumerWidget {
  const AiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Layout(
    title: context.l10n.aiHubTitle,
    child: AiFeatureGate(
      child: ConfigListView(
        children: [
          const ConfigListTile.space(20),
          ConfigListTile.item(
            icon: const Icon(Icons.add_comment_outlined),
            title: context.l10n.aiHubNewChatEntry,
            onTap: () => unawaited(context.router.push(const ChatRoute())),
          ),
          ConfigListTile.item(
            icon: const Icon(Icons.history),
            title: context.l10n.chatHistoryPageTitle,
            onTap: () => unawaited(context.router.push(const ChatHistoryRoute())),
          ),
          ConfigListTile.item(
            icon: const Icon(Icons.settings_outlined),
            title: context.l10n.aiChatSettingsTitle,
            onTap: () => unawaited(context.router.push(const AiChatSettingsRoute())),
          ),
        ],
      ),
    ),
  );
}
