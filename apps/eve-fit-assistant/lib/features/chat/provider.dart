import "package:eve_fit_assistant/features/remote_content/system_proxy.dart";
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
/// env-var proxy handling. On web the browser handles proxying and
/// `systemDefault` is returned. With a resolved proxy config the decision
/// splits between `direct` and `proxy` — see [chatProxyRoutingForUri].
native_chat.ChatProxyRouting chatProxyRoutingFor(ChatProvider provider, String baseUrl) {
  final stored = baseUrl.trim();
  final effectiveUrl = stored.isEmpty ? provider.defaultBaseUrl : stored;
  final uri = Uri.tryParse(effectiveUrl);
  if (uri == null) return const native_chat.ChatProxyRouting.systemDefault();
  final config = systemProxyConfig;
  if (config == null) return const native_chat.ChatProxyRouting.systemDefault();
  return chatProxyRoutingForUri(config, uri);
}

/// The proxy routing for the chat endpoint [uri] under a resolved system
/// proxy [config].
///
/// `direct` applies only when [config] bypasses the endpoint — reqwest must
/// NOT fall back to the proxy env vars there, so the native client disables
/// proxying entirely (`ClientBuilder::no_proxy`). Otherwise `proxy` carries
/// the full per-scheme proxy URLs and the bypass list (not just the proxy
/// resolved for the endpoint — which may not even cover [uri]'s own scheme,
/// e.g. an HTTPS endpoint with only an HTTP proxy configured): reqwest
/// follows redirects inside the client, so the native client re-resolves the
/// routing for every request — the endpoint itself goes direct when its
/// scheme has no proxy, a redirect to a bypassed host goes direct, and a
/// cross-scheme redirect picks up that scheme's proxy. Collapsing the
/// scheme-uncovered case into `direct` would disable proxying entirely, so
/// an HTTPS-to-HTTP redirect could never use the HTTP proxy.
native_chat.ChatProxyRouting chatProxyRoutingForUri(SystemProxyConfig config, Uri uri) {
  if (systemProxyBypasses(config, uri)) {
    return const native_chat.ChatProxyRouting.direct();
  }
  return native_chat.ChatProxyRouting.proxy(
    httpUrl: config.httpProxy,
    httpsUrl: config.httpsProxy,
    allUrl: config.allProxy,
    bypass: config.bypass,
  );
}

/// A stable string key for [routing], used in the session config fingerprint
/// to detect routing changes across session reuse.
String chatProxyRoutingKey(native_chat.ChatProxyRouting routing) => switch (routing) {
  native_chat.ChatProxyRouting_SystemDefault() => "default",
  native_chat.ChatProxyRouting_Direct() => "direct",
  native_chat.ChatProxyRouting_Proxy(
    :final httpUrl,
    :final httpsUrl,
    :final allUrl,
    :final bypass,
  ) =>
    "proxy|${httpUrl ?? ""}|${httpsUrl ?? ""}|${allUrl ?? ""}|${bypass.join(",")}",
};
