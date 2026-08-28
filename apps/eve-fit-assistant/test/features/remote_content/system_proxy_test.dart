import "package:eve_fit_assistant/features/remote_content/system_proxy.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("normalizeHttpProxy", () {
    test("returns null for empty and non-HTTP values", () {
      expect(normalizeHttpProxy(null), isNull);
      expect(normalizeHttpProxy(""), isNull);
      expect(normalizeHttpProxy("   "), isNull);
      expect(normalizeHttpProxy("socks5://127.0.0.1:1080"), isNull);
    });

    test("strips the scheme and path, keeps userinfo", () {
      expect(normalizeHttpProxy("http://127.0.0.1:7890"), "127.0.0.1:7890");
      expect(normalizeHttpProxy("https://proxy.example.com:8080/"), "proxy.example.com:8080");
      expect(normalizeHttpProxy("http://user:pass@proxy.example.com:3128"), "user:pass@proxy.example.com:3128");
    });

    test("adds the default port when missing", () {
      expect(normalizeHttpProxy("proxy.example.com"), "proxy.example.com:1080");
      expect(normalizeHttpProxy("user:pass@proxy.example.com"), "user:pass@proxy.example.com:1080");
      expect(normalizeHttpProxy("[::1]"), "[::1]:1080");
      expect(normalizeHttpProxy("[::1]:7890"), "[::1]:7890");
    });
  });

  group("systemProxyFromEnvironment", () {
    test("reads lower- and uppercase variables", () {
      final config = systemProxyFromEnvironment({
        "http_proxy": "http://127.0.0.1:7890",
        "HTTPS_PROXY": "https://127.0.0.1:7891",
        "all_proxy": "http://127.0.0.1:7892",
        "NO_PROXY": "localhost, .internal.example.com",
      });
      expect(config.httpProxy, "127.0.0.1:7890");
      expect(config.httpsProxy, "127.0.0.1:7891");
      expect(config.allProxy, "127.0.0.1:7892");
      expect(config.bypass, ["localhost", ".internal.example.com"]);
      expect(config.isEmpty, isFalse);
    });

    test("a lone no_proxy leaves the config empty", () {
      final config = systemProxyFromEnvironment({"no_proxy": "localhost"});
      expect(config.isEmpty, isTrue);
      expect(config.bypass, ["localhost"]);
    });
  });

  group("systemProxyFromGnome", () {
    test("returns null unless the mode is manual", () {
      expect(systemProxyFromGnome(mode: "none"), isNull);
      expect(systemProxyFromGnome(mode: "auto"), isNull);
    });

    test("manual mode reads http/https proxies", () {
      final config = systemProxyFromGnome(
        mode: "manual",
        httpHost: "127.0.0.1",
        httpPort: 7890,
        httpsHost: "127.0.0.1",
        httpsPort: 7891,
        ignoreHosts: const ["localhost"],
      )!;
      expect(config.httpProxy, "127.0.0.1:7890");
      expect(config.httpsProxy, "127.0.0.1:7891");
      expect(config.bypass, ["localhost"]);
    });

    test("use-same-proxy reuses the http proxy for https", () {
      final config = systemProxyFromGnome(
        mode: "manual",
        httpHost: "127.0.0.1",
        httpPort: 7890,
        useSameProxy: true,
      )!;
      expect(config.httpsProxy, "127.0.0.1:7890");
    });

    test("manual mode without any usable host/port returns null", () {
      expect(systemProxyFromGnome(mode: "manual"), isNull);
      expect(systemProxyFromGnome(mode: "manual", httpHost: "127.0.0.1"), isNull);
    });
  });

  group("findProxyForUrl", () {
    const config = SystemProxyConfig(
      httpProxy: "http-proxy:8080",
      httpsProxy: "https-proxy:8081",
      allProxy: "all-proxy:8082",
      bypass: ["localhost", ".example.com"],
    );

    test("picks the scheme-specific proxy, falling back to all_proxy", () {
      expect(findProxyForUrl(config, Uri.parse("http://foo.bar/")), "PROXY http-proxy:8080");
      expect(findProxyForUrl(config, Uri.parse("https://foo.bar/")), "PROXY https-proxy:8081");
      const onlyAll = SystemProxyConfig(allProxy: "all-proxy:8082");
      expect(findProxyForUrl(onlyAll, Uri.parse("https://foo.bar/")), "PROXY all-proxy:8082");
    });

    test("bypassed hosts go direct, including subdomains and '*'", () {
      expect(findProxyForUrl(config, Uri.parse("https://localhost/")), "DIRECT");
      expect(findProxyForUrl(config, Uri.parse("https://api.example.com/")), "DIRECT");
      expect(findProxyForUrl(config, Uri.parse("https://example.com/")), "DIRECT");
      expect(findProxyForUrl(config, Uri.parse("https://notexample.com/")), "PROXY https-proxy:8081");
      const star = SystemProxyConfig(allProxy: "p:1", bypass: ["*"]);
      expect(findProxyForUrl(star, Uri.parse("https://foo.bar/")), "DIRECT");
    });

    test("unknown schemes and empty configs go direct", () {
      expect(findProxyForUrl(config, Uri.parse("ftp://foo.bar/")), "DIRECT");
      const empty = SystemProxyConfig();
      expect(findProxyForUrl(empty, Uri.parse("https://foo.bar/")), "DIRECT");
    });
  });

  group("proxyUrlFor", () {
    test("returns a full URL for proxied targets, null for direct ones", () {
      const config = SystemProxyConfig(httpsProxy: "127.0.0.1:7890", bypass: ["localhost"]);
      expect(proxyUrlFor(config, Uri.parse("https://api.openai.com/v1")), "http://127.0.0.1:7890");
      expect(proxyUrlFor(config, Uri.parse("https://localhost/v1")), isNull);
    });
  });
}
