import "package:eve_fit_assistant/features/remote_content/system_proxy_io.dart"
    if (dart.library.js_interop) "package:eve_fit_assistant/features/remote_content/system_proxy_stub.dart";
import "package:eve_fit_assistant/native/api/chat.dart" as native_chat;
import "package:eve_fit_assistant/storage/setting/setting.dart";

/// Map the settings-layer provider to its FRB bridge counterpart.
native_chat.ChatProvider toNativeChatProvider(ChatProvider provider) => switch (provider) {
  ChatProvider.openAiCompatible => native_chat.ChatProvider.openAiCompatible,
  ChatProvider.anthropic => native_chat.ChatProvider.anthropic,
  ChatProvider.deepSeek => native_chat.ChatProvider.deepSeek,
};

/// The desktop system proxy URL (`http://host:port`) applying to the chat
/// endpoint at [baseUrl], or `null` when the endpoint is reached directly
/// (or on web, where the browser handles proxying).
String? chatProxyUrlFor(String baseUrl) {
  final uri = Uri.tryParse(baseUrl);
  return uri == null ? null : systemProxyUrlFor(uri);
}
