import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/chat/api_key_store.dart";
import "package:eve_fit_assistant/features/chat/chat_controller.dart";
import "package:eve_fit_assistant/features/chat/model_list.dart";
import "package:eve_fit_assistant/features/deeplink/deeplink.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/storage/chat/models.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatControllerProvider);
    final apiKey = ref.watch(aiChatApiKeyProvider).value;
    final configured = apiKey != null && apiKey.isNotEmpty;

    ref
      ..listen(chatControllerProvider.select((s) => s.conversation?.messages.length), (_, _) {
        _scrollToBottom();
      })
      ..listen(chatControllerProvider.select((s) => s.streamingText?.length), (_, _) {
        _scrollToBottom();
      });

    return Layout(
      title: context.l10n.chatPageTitle,
      actions: [
        if (configured) const _ModelPickerButton(key: Key("chat-model-picker")),
        IconButton(
          icon: const Icon(Icons.add_comment_outlined),
          tooltip: context.l10n.chatNewConversationTooltip,
          onPressed: () => ref.read(chatControllerProvider.notifier).newConversation(),
        ),
        IconButton(
          icon: const Icon(Icons.history),
          tooltip: context.l10n.chatHistoryTooltip,
          onPressed: () => unawaited(context.router.push(const ChatHistoryRoute())),
        ),
      ],
      child: configured ? _buildChat(context, chatState) : _buildNotConfigured(context),
    );
  }

  Widget _buildNotConfigured(BuildContext context) => Center(
    child: Padding(
      padding: const .all(24),
      child: Column(
        mainAxisSize: .min,
        children: [
          const Icon(Icons.smart_toy_outlined, size: 48),
          const SizedBox(height: 16),
          Text(
            context.l10n.chatNotConfiguredTitle,
            style: context.theme.textTheme.titleMedium,
            textAlign: .center,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.chatNotConfiguredDescription,
            style: context.theme.textTheme.bodyMedium,
            textAlign: .center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => unawaited(context.router.push(const AiChatSettingsRoute())),
            child: Text(context.l10n.chatGoToSettings),
          ),
        ],
      ),
    ),
  );

  Widget _buildChat(BuildContext context, ChatState chatState) {
    final messages = chatState.conversation?.messages ?? const <ChatMessage>[];
    return Column(
      children: [
        Expanded(
          child: messages.isEmpty && chatState.streamingText == null
              ? Center(
                  child: Text(
                    context.l10n.chatEmptyHint,
                    style: context.theme.textTheme.bodyMedium?.copyWith(
                      color: context.theme.hintColor,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const .symmetric(horizontal: 12, vertical: 8),
                  itemCount: messages.length + (chatState.streamingText != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return _AssistantBubble(text: chatState.streamingText!, streaming: true);
                    }
                    final message = messages[index];
                    return switch (message.role) {
                      ChatMessageRole.user => _UserBubble(text: message.content),
                      ChatMessageRole.assistant => _AssistantBubble(text: message.content),
                    };
                  },
                ),
        ),
        if (chatState.error != null) _buildErrorBanner(context, chatState),
        _buildComposer(context, chatState),
      ],
    );
  }

  Widget _buildErrorBanner(BuildContext context, ChatState chatState) => Material(
    color: context.theme.colorScheme.errorContainer,
    child: Padding(
      padding: const .symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.chatSendFailed(error: chatState.error!),
              style: context.theme.textTheme.bodySmall?.copyWith(
                color: context.theme.colorScheme.onErrorContainer,
              ),
              maxLines: 2,
              overflow: .ellipsis,
            ),
          ),
          if (chatState.failedText != null)
            TextButton(
              onPressed: () => unawaited(ref.read(chatControllerProvider.notifier).retry()),
              child: Text(context.l10n.retry),
            ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => ref.read(chatControllerProvider.notifier).dismissError(),
          ),
        ],
      ),
    ),
  );

  Widget _buildComposer(BuildContext context, ChatState chatState) => SafeArea(
    top: false,
    child: Padding(
      padding: const .symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: .end,
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              minLines: 1,
              maxLines: 5,
              enabled: !chatState.sending,
              textInputAction: .newline,
              decoration: InputDecoration(
                hintText: context.l10n.chatInputHint,
                border: const OutlineInputBorder(),
                isDense: true,
                contentPadding: const .symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: chatState.sending
                ? null
                : () {
                    final text = _inputController.text;
                    _inputController.clear();
                    unawaited(ref.read(chatControllerProvider.notifier).send(text));
                  },
            icon: chatState.sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
          ),
        ],
      ),
    ),
  );

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        unawaited(
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: .centerRight,
    child: Container(
      margin: const .only(left: 48, top: 4, bottom: 4),
      padding: const .symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SelectableText(text),
    ),
  );
}

class _AssistantBubble extends ConsumerWidget {
  const _AssistantBubble({required this.text, this.streaming = false});

  final String text;
  final bool streaming;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void onTapLink(String text, String? href, String title) {
      if (href == null) return;
      unawaited(ref.read(appLinkHandlerProvider).open(context, href));
    }

    return Align(
      alignment: .centerLeft,
      child: Container(
        margin: const .only(right: 48, top: 4, bottom: 4),
        padding: const .symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: context.theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: streaming
            ? MarkdownBody(data: "$text▍", onTapLink: onTapLink)
            : MarkdownBody(data: text, selectable: true, onTapLink: onTapLink),
      ),
    );
  }
}

class _ModelPickerSheet extends ConsumerStatefulWidget {
  const _ModelPickerSheet();

  @override
  ConsumerState<_ModelPickerSheet> createState() => _ModelPickerSheetState();
}

class _ModelPickerSheetState extends ConsumerState<_ModelPickerSheet> {
  bool _fetching = false;
  Timer? _ticker;

  Duration get _cooldown => modelListFetchCooldownRemaining();

  bool get _fetchDisabled => _fetching || _cooldown > Duration.zero;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final models = ref.watch(appSettingServiceProvider.select((s) => s.aiChat.models));
    return Column(
      mainAxisSize: .min,
      children: [
        Padding(
          padding: const .only(bottom: 8),
          child: Text(
            context.l10n.chatModelSelectTitle,
            style: context.theme.textTheme.titleMedium,
          ),
        ),
        if (models.isEmpty)
          Padding(
            padding: const .symmetric(horizontal: 16, vertical: 8),
            child: Text(
              context.l10n.chatModelListEmpty,
              style: context.theme.textTheme.bodySmall,
              textAlign: .center,
            ),
          ),
        for (final model in models)
          ListTile(
            title: Text(model.id),
            subtitle: model.ownedBy != null ? Text(model.ownedBy!) : null,
            onTap: () => Navigator.of(context).pop(model.id),
          ),
        ListTile(
          leading: const Icon(Icons.cloud_download_outlined),
          title: Text(context.l10n.aiChatFetchModels),
          subtitle: _cooldown > Duration.zero
              ? Text(context.l10n.aiChatFetchModelsCooldown(seconds: _cooldown.inSeconds))
              : null,
          trailing: _fetching
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
          onTap: _fetchDisabled ? null : () => unawaited(_fetch()),
        ),
        ListTile(
          leading: const Icon(Icons.edit_outlined),
          title: Text(context.l10n.chatCustomModelLabel),
          onTap: () async {
            final custom = await _showCustomModelDialog(context);
            if (custom != null && context.mounted) {
              Navigator.of(context).pop(custom);
            }
          },
        ),
      ],
    );
  }

  Future<void> _fetch() async {
    setState(() => _fetching = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await refreshAvailableModels(ref);
    } on ChatApiKeyMissingException {
      messenger.showSnackBar(SnackBar(content: Text(l10n.aiChatApiKeyNotConfigured)));
    } on Object catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.aiChatFetchModelsFailed(error: e.toString()))),
      );
    } finally {
      if (mounted) {
        setState(() => _fetching = false);
        _startTicker();
      }
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (modelListFetchCooldownRemaining() == Duration.zero) {
        _ticker?.cancel();
        _ticker = null;
      }
      setState(() {});
    });
  }

  Future<String?> _showCustomModelDialog(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AppDialog(
        title: context.l10n.chatCustomModelLabel,
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: context.l10n.chatCustomModelHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(context.l10n.confirm),
          ),
        ],
      ),
    );
  }
}

class _ModelPickerButton extends ConsumerWidget {
  const _ModelPickerButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final model = ref.watch(appSettingServiceProvider.select((s) => s.aiChat.model));
    return TextButton.icon(
      onPressed: () => unawaited(_showModelPicker(context, ref)),
      icon: const Icon(Icons.arrow_drop_down),
      label: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 120),
        child: Text(model, overflow: .ellipsis),
      ),
    );
  }

  Future<void> _showModelPicker(BuildContext context, WidgetRef ref) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => const SafeArea(child: _ModelPickerSheet()),
    );
    if (selected != null && selected.isNotEmpty) {
      await ref.read(chatControllerProvider.notifier).setModel(selected);
    }
  }
}
