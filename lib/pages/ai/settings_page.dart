import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/dialog/confirm_dialog.dart";
import "package:eve_fit_assistant/components/dialog/dialog.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/components/list/config_list.dart";
import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/features/ai_gate/ai_gate.dart";
import "package:eve_fit_assistant/features/ai_gate/ai_gate_controller.dart";
import "package:eve_fit_assistant/features/chat/api_key_store.dart";
import "package:eve_fit_assistant/features/chat/model_list.dart";
import "package:eve_fit_assistant/features/chat/provider.dart";
import "package:eve_fit_assistant/features/chat/system_prompt.dart";
import "package:eve_fit_assistant/native/api/chat.dart" as native_chat;
import "package:eve_fit_assistant/storage/chat/service.dart";
import "package:eve_fit_assistant/storage/setting/setting.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class AiChatSettingsPage extends ConsumerWidget {
  const AiChatSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Layout(
    title: context.l10n.aiChatSettingsTitle,
    child: AiFeatureGate(
      child: ConfigListView(
        children: [
          ConfigListTile.title(context.l10n.aiChatSettingsSectionConnection),
          const ConfigListTile.custom(_ProviderTile()),
          const ConfigListTile.custom(_BaseUrlTile()),
          const ConfigListTile.custom(_ApiKeyTile()),
          ConfigListTile.title(context.l10n.aiChatSettingsSectionModels),
          const ConfigListTile.custom(_DefaultModelTile()),
          const ConfigListTile.custom(_FetchModelsTile()),
          const ConfigListTile.custom(_ModelListEditor()),
          ConfigListTile.title(context.l10n.aiChatSettingsSectionActions),
          const ConfigListTile.custom(_TestConnectionTile()),
          const ConfigListTile.custom(_ClearConversationsTile()),
          const ConfigListTile.custom(_RefreshAgentDbTile()),
          const ConfigListTile.custom(_DisableAssistantTile()),
        ],
      ),
    ),
  );
}

String _providerLabel(BuildContext context, ChatProvider provider) => switch (provider) {
  ChatProvider.openAiCompatible => context.l10n.aiChatProviderOpenAiCompatible,
  ChatProvider.anthropic => context.l10n.aiChatProviderAnthropic,
  ChatProvider.deepSeek => context.l10n.aiChatProviderDeepSeek,
};

class _ProviderTile extends ConsumerWidget {
  const _ProviderTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ref.watch(appSettingServiceProvider.select((s) => s.aiChat.provider));
    return ListTile(
      leading: const Icon(Icons.hub_outlined),
      title: Text(context.l10n.aiChatProviderTitle),
      subtitle: Text(
        "${_providerLabel(context, provider)}\n${context.l10n.aiChatProviderToolHint}",
      ),
      isThreeLine: true,
      onTap: () async {
        final selected = await showDialog<ChatProvider>(
          context: context,
          builder: (context) => SimpleDialog(
            title: Text(context.l10n.aiChatProviderTitle),
            children: [
              for (final option in ChatProvider.values)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(option),
                  child: Row(
                    children: [
                      Icon(
                        option == provider ? Icons.radio_button_checked : Icons.radio_button_off,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(_providerLabel(context, option)),
                    ],
                  ),
                ),
            ],
          ),
        );
        if (selected != null && selected != provider) {
          ref
              .read(appSettingServiceProvider.notifier)
              .update((s) => s.copyWith(aiChat: s.aiChat.copyWith(provider: selected)));
        }
      },
    );
  }
}

class _BaseUrlTile extends ConsumerWidget {
  const _BaseUrlTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiChat = ref.watch(appSettingServiceProvider.select((s) => s.aiChat));
    return ListTile(
      leading: const Icon(Icons.link),
      title: Text(context.l10n.aiChatBaseUrlTitle),
      subtitle: Text(aiChat.baseUrl),
      onTap: () async {
        final value = await _showTextInputDialog(
          context,
          title: context.l10n.aiChatBaseUrlTitle,
          hint: context.l10n.aiChatBaseUrlHint,
          initial: aiChat.connection.baseUrl,
        );
        if (value != null) {
          ref
              .read(appSettingServiceProvider.notifier)
              .update(
                (s) => s.copyWith(
                  aiChat: s.aiChat.withConnection(
                    s.aiChat.provider,
                    (connection) => connection.copyWith(baseUrl: value),
                  ),
                ),
              );
        }
      },
    );
  }
}

class _ApiKeyTile extends ConsumerWidget {
  const _ApiKeyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiKey = ref.watch(aiChatApiKeyProvider).value;
    final configured = apiKey != null && apiKey.isNotEmpty;
    return ListTile(
      leading: const Icon(Icons.key_outlined),
      title: Text(context.l10n.aiChatApiKeyTitle),
      subtitle: Text(
        configured ? context.l10n.aiChatApiKeyConfigured : context.l10n.aiChatApiKeyNotConfigured,
      ),
      trailing: configured
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: context.l10n.aiChatApiKeyClear,
              onPressed: () => unawaited(ref.read(aiChatApiKeyProvider.notifier).set(null)),
            )
          : null,
      onTap: () async {
        final value = await _showTextInputDialog(
          context,
          title: context.l10n.aiChatApiKeyTitle,
          hint: context.l10n.aiChatApiKeyHint,
          obscure: true,
        );
        if (value != null && value.isNotEmpty) {
          await ref.read(aiChatApiKeyProvider.notifier).set(value);
        }
      },
    );
  }
}

class _DefaultModelTile extends ConsumerWidget {
  const _DefaultModelTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiChat = ref.watch(appSettingServiceProvider.select((s) => s.aiChat));
    return ListTile(
      leading: const Icon(Icons.model_training),
      title: Text(context.l10n.aiChatDefaultModelTitle),
      trailing: DropdownButton<String>(
        value: aiChat.models.any((m) => m.id == aiChat.model) ? aiChat.model : null,
        hint: Text(aiChat.model),
        underline: const SizedBox.shrink(),
        items: [
          for (final model in aiChat.models)
            DropdownMenuItem(value: model.id, child: Text(model.id)),
        ],
        onChanged: (value) {
          if (value != null) {
            ref
                .read(appSettingServiceProvider.notifier)
                .update(
                  (s) => s.copyWith(
                    aiChat: s.aiChat.withConnection(
                      s.aiChat.provider,
                      (connection) => connection.copyWith(model: value),
                    ),
                  ),
                );
          }
        },
      ),
    );
  }
}

class _FetchModelsTile extends ConsumerStatefulWidget {
  const _FetchModelsTile();

  @override
  ConsumerState<_FetchModelsTile> createState() => _FetchModelsTileState();
}

class _FetchModelsTileState extends ConsumerState<_FetchModelsTile> {
  bool _fetching = false;
  Timer? _ticker;

  Duration get _cooldown => modelListFetchCooldownRemaining();

  bool get _disabled => _fetching || _cooldown > Duration.zero;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.cloud_download_outlined),
    title: Text(context.l10n.aiChatFetchModels),
    subtitle: _cooldown > Duration.zero
        ? Text(context.l10n.aiChatFetchModelsCooldown(seconds: _cooldown.inSeconds))
        : null,
    trailing: _fetching
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : null,
    onTap: _disabled ? null : () => unawaited(_fetch()),
  );

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

  Future<void> _fetch() async {
    setState(() => _fetching = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final models = await refreshAvailableModels(ref);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.aiChatFetchModelsSuccess(count: models.length))),
      );
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
}

class _ModelListEditor extends ConsumerWidget {
  const _ModelListEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final models = ref.watch(appSettingServiceProvider.select((s) => s.aiChat.models));
    return Column(
      mainAxisSize: .min,
      children: [
        for (final model in models)
          ListTile(
            dense: true,
            leading: const Icon(Icons.smart_toy_outlined),
            title: Text(model.id),
            subtitle: model.ownedBy != null ? Text(model.ownedBy!) : null,
            trailing: IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () {
                ref
                    .read(appSettingServiceProvider.notifier)
                    .update(
                      (s) => s.copyWith(
                        aiChat: s.aiChat.withConnection(
                          s.aiChat.provider,
                          (connection) => connection.copyWith(
                            models: [
                              for (final m in connection.models)
                                if (m.id != model.id) m,
                            ],
                          ),
                        ),
                      ),
                    );
              },
            ),
          ),
        ListTile(
          dense: true,
          leading: const Icon(Icons.add),
          title: Text(context.l10n.aiChatAddModel),
          onTap: () async {
            final value = await _showTextInputDialog(
              context,
              title: context.l10n.aiChatAddModel,
              hint: context.l10n.chatCustomModelHint,
            );
            if (value != null && value.isNotEmpty) {
              ref
                  .read(appSettingServiceProvider.notifier)
                  .update(
                    (s) => s.aiChat.models.any((m) => m.id == value)
                        ? s
                        : s.copyWith(
                            aiChat: s.aiChat.withConnection(
                              s.aiChat.provider,
                              (connection) => connection.copyWith(
                                models: [
                                  ...connection.models,
                                  AiChatModel(id: value),
                                ],
                              ),
                            ),
                          ),
                  );
            }
          },
        ),
      ],
    );
  }
}

class _TestConnectionTile extends ConsumerStatefulWidget {
  const _TestConnectionTile();

  @override
  ConsumerState<_TestConnectionTile> createState() => _TestConnectionTileState();
}

class _TestConnectionTileState extends ConsumerState<_TestConnectionTile> {
  bool _testing = false;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.wifi_tethering),
    title: Text(context.l10n.aiChatTestConnection),
    trailing: _testing
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
        : null,
    onTap: _testing ? null : () => unawaited(_test()),
  );

  Future<void> _test() async {
    setState(() => _testing = true);
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final apiKey = await ref.read(aiChatApiKeyProvider.future);
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception(l10n.aiChatApiKeyNotConfigured);
      }
      final aiChat = ref.read(appSettingServiceProvider).aiChat;
      final session = native_chat.ChatSession.create(
        config: native_chat.ChatConfig(
          provider: toNativeChatProvider(aiChat.provider),
          apiKey: apiKey,
          baseUrl: aiChat.baseUrl,
          model: aiChat.model,
          systemPrompt: ref.read(chatSystemPromptProvider),
          language: ref.read(localeProvider).name,
        ),
      );
      await session.prompt(text: "Hello");
      messenger.showSnackBar(SnackBar(content: Text(l10n.aiChatTestConnectionSuccess)));
    } on Object catch (e, st) {
      error("chat: connection test failed", error: e, stackTrace: st);
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.aiChatTestConnectionFailed(error: e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }
}

class _ClearConversationsTile extends ConsumerWidget {
  const _ClearConversationsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.delete_sweep_outlined),
    title: Text(context.l10n.chatClearAll),
    onTap: () async {
      final confirmed = await showConfirmDialog(context, title: context.l10n.chatClearAllConfirm);
      if (confirmed) {
        await ref.read(chatStorageServiceProvider.notifier).clear();
      }
    },
  );
}

class _RefreshAgentDbTile extends ConsumerWidget {
  const _RefreshAgentDbTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.refresh),
    title: Text(context.l10n.aiChatRefreshDataTitle),
    subtitle: Text(context.l10n.aiChatRefreshDataDescription),
    onTap: () => unawaited(ref.read(aiGateControllerProvider.notifier).refreshAgentDb()),
  );
}

class _DisableAssistantTile extends ConsumerWidget {
  const _DisableAssistantTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
    leading: const Icon(Icons.power_settings_new),
    title: Text(context.l10n.aiChatDisableTitle),
    onTap: () async {
      final confirmed = await showConfirmDialog(context, title: context.l10n.aiChatDisableConfirm);
      if (confirmed) {
        ref.read(aiGateControllerProvider.notifier).disableAssistant();
      }
    },
  );
}

Future<String?> _showTextInputDialog(
  BuildContext context, {
  required String title,
  String? hint,
  String? initial,
  bool obscure = false,
}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AppDialog(
      title: title,
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: obscure,
        decoration: InputDecoration(hintText: hint),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.cancel)),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(controller.text.trim()),
          child: Text(context.l10n.save),
        ),
      ],
    ),
  );
}
