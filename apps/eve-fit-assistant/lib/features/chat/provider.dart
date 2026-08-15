import "package:eve_fit_assistant/native/api/chat.dart" as native_chat;
import "package:eve_fit_assistant/storage/setting/setting.dart";

/// Map the settings-layer provider to its FRB bridge counterpart.
native_chat.ChatProvider toNativeChatProvider(ChatProvider provider) => switch (provider) {
  ChatProvider.openAiCompatible => native_chat.ChatProvider.openAiCompatible,
  ChatProvider.anthropic => native_chat.ChatProvider.anthropic,
  ChatProvider.deepSeek => native_chat.ChatProvider.deepSeek,
};
