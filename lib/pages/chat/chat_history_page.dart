import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/ai_gate/ai_gate.dart";
import "package:eve_fit_assistant/features/ai_gate/ai_gate_controller.dart";
import "package:eve_fit_assistant/features/ai_gate/ai_gate_state.dart";
import "package:eve_fit_assistant/features/chat/chat_controller.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/chat/models.dart";
import "package:eve_fit_assistant/storage/chat/service.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class ChatHistoryPage extends ConsumerWidget {
  const ChatHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(chatStorageServiceProvider);
    final gateReady = ref.watch(aiGateControllerProvider) is AiGateReady;
    return Layout(
      title: context.l10n.chatHistoryPageTitle,
      actions: [
        if (gateReady && conversations.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: context.l10n.chatClearAll,
            onPressed: () => unawaited(_clearAll(context, ref)),
          ),
      ],
      child: AiFeatureGate(
        child: conversations.isEmpty
            ? Center(
                child: Text(
                  context.l10n.chatConversationEmpty,
                  style: context.theme.textTheme.bodyMedium?.copyWith(
                    color: context.theme.hintColor,
                  ),
                ),
              )
            : ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, index) =>
                    _ConversationTile(conversation: conversations[index]),
              ),
      ),
    );
  }

  Future<void> _clearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(context, title: context.l10n.chatClearAllConfirm);
    if (confirmed) {
      await ref.read(chatStorageServiceProvider.notifier).clear();
      ref.read(chatControllerProvider.notifier).newConversation();
    }
  }
}

class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final ChatConversation conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Dismissible(
    key: ValueKey(conversation.id),
    direction: .endToStart,
    background: Container(
      color: context.theme.colorScheme.errorContainer,
      alignment: .centerRight,
      padding: const .only(right: 16),
      child: Icon(Icons.delete_outline, color: context.theme.colorScheme.onErrorContainer),
    ),
    confirmDismiss: (_) =>
        showConfirmDialog(context, title: context.l10n.chatDeleteConversationConfirm),
    onDismissed: (_) =>
        unawaited(ref.read(chatStorageServiceProvider.notifier).delete(conversation.id)),
    child: ListTile(
      title: Text(conversation.title, maxLines: 1, overflow: .ellipsis),
      subtitle: Text(
        _formatTimestamp(conversation.updatedAt),
        style: context.theme.textTheme.bodySmall,
      ),
      trailing: conversation.model.isEmpty ? null : Text(conversation.model),
      onTap: () {
        unawaited(ref.read(chatControllerProvider.notifier).openConversation(conversation.id));
        final router = context.router;
        // History can be pushed from the AI hub as well as from the chat page;
        // only pop when a chat page is actually underneath.
        if (router.stack.any((route) => route.name == ChatRoute.name)) {
          router.popUntilRouteWithName(ChatRoute.name);
        } else {
          unawaited(router.replace(const ChatRoute()));
        }
      },
    ),
  );

  static String _formatTimestamp(int millis) {
    final time = DateTime.fromMillisecondsSinceEpoch(millis);
    String two(int value) => value.toString().padLeft(2, "0");
    return "${time.year}-${two(time.month)}-${two(time.day)} ${two(time.hour)}:${two(time.minute)}";
  }
}
