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

/// The proxy routing for [provider]'s chat endpoint at [baseUrl], resolved
/// from the desktop system proxy settings.
///
/// A blank [baseUrl] means the provider's default endpoint — the same
/// fallback the native client applies (`ChatConfig::resolved_base_url`). The
/// default must be resolved here too: parsing the blank string directly
/// yields a hostless, scheme-less URI that the routing layer treats as an
/// explicit direct connection, disabling proxying for an endpoint that the
/// configured system proxy would otherwise cover.
///
/// `systemDefault` applies off Linux, when no system proxy is configured, or
/// when the effective URL does not parse: reqwest then keeps its default
/// env-var proxy handling. `direct` applies when a resolved proxy config
/// bypasses the endpoint — reqwest must NOT fall back to the proxy env vars
/// there, so the native client disables proxying entirely
/// (`ClientBuilder::no_proxy`). On web the browser handles proxying and
/// `systemDefault` is returned.
native_chat.ChatProxyRouting chatProxyRoutingFor(ChatProvider provider, String baseUrl) {
  final stored = baseUrl.trim();
  final effectiveUrl = stored.isEmpty ? provider.defaultBaseUrl : stored;
  final uri = Uri.tryParse(effectiveUrl);
  final routing = uri == null ? null : systemProxyRoutingForUrl(uri);
  if (routing == null) return const native_chat.ChatProxyRouting.systemDefault();
  final proxyUrl = routing.proxyUrl;
  return proxyUrl == null
      ? const native_chat.ChatProxyRouting.direct()
      : native_chat.ChatProxyRouting.proxy(url: proxyUrl);
}

/// A stable string key for [routing], used in the session config fingerprint
/// to detect routing changes across session reuse.
String chatProxyRoutingKey(native_chat.ChatProxyRouting routing) => switch (routing) {
  native_chat.ChatProxyRouting_SystemDefault() => "default",
  native_chat.ChatProxyRouting_Direct() => "direct",
  native_chat.ChatProxyRouting_Proxy(:final url) => url,
};
