import "package:eve_fit_assistant/features/chat/provider.dart";
import "package:eve_fit_assistant/features/remote_content/system_proxy.dart";
import "package:eve_fit_assistant/native/api/chat.dart" as native_chat;
import "package:flutter_test/flutter_test.dart";

void main() {
  group("chatProxyRoutingForUri", () {
    test("carries the full per-scheme config for a proxied endpoint", () {
      const config = SystemProxyConfig(
        httpProxy: "http://127.0.0.1:7890",
        httpsProxy: "http://127.0.0.1:7891",
        bypass: ["localhost"],
      );
      final routing = chatProxyRoutingForUri(config, Uri.parse("https://api.openai.com/v1"));
      expect(
        routing,
        isA<native_chat.ChatProxyRouting_Proxy>()
            .having((r) => r.httpUrl, "httpUrl", "http://127.0.0.1:7890")
            .having((r) => r.httpsUrl, "httpsUrl", "http://127.0.0.1:7891")
            .having((r) => r.bypass, "bypass", ["localhost"]),
      );
    });

    test("routes a bypassed endpoint direct", () {
      // A bypassed endpoint must disable proxying entirely (`direct`), not
      // keep reqwest's env-var fallback (`systemDefault`).
      const config = SystemProxyConfig(allProxy: "http://127.0.0.1:7890", bypass: ["localhost"]);
      expect(
        chatProxyRoutingForUri(config, Uri.parse("https://localhost/v1")),
        isA<native_chat.ChatProxyRouting_Direct>(),
      );
    });

    test("a bypass wins over an uncovered scheme", () {
      const config = SystemProxyConfig(
        httpProxy: "http://127.0.0.1:7890",
        bypass: ["api.openai.com"],
      );
      expect(
        chatProxyRoutingForUri(config, Uri.parse("https://api.openai.com/v1")),
        isA<native_chat.ChatProxyRouting_Direct>(),
      );
    });

    // Regression test: an HTTPS endpoint with only an HTTP proxy configured
    // must still select `proxy`, not `direct`. `direct` disables proxying
    // entirely (ClientBuilder::no_proxy), so an HTTPS-to-HTTP redirect —
    // followed by reqwest inside the client — could never pick up the HTTP
    // proxy. With the full per-scheme config the native client re-resolves
    // the routing per request: the HTTPS endpoint itself goes direct, and
    // the HTTP redirect target uses the HTTP proxy.
    test("an https endpoint with only an http proxy keeps the proxy routing", () {
      const config = SystemProxyConfig(httpProxy: "http://127.0.0.1:7890");
      final routing = chatProxyRoutingForUri(config, Uri.parse("https://api.openai.com/v1"));
      expect(
        routing,
        isA<native_chat.ChatProxyRouting_Proxy>()
            .having((r) => r.httpUrl, "httpUrl", "http://127.0.0.1:7890")
            .having((r) => r.httpsUrl, "httpsUrl", isNull)
            .having((r) => r.allUrl, "allUrl", isNull),
      );
    });
  });
}
