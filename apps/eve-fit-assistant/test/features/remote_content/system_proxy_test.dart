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

    test("keeps the scheme, drops the path, keeps userinfo", () {
      expect(normalizeHttpProxy("http://127.0.0.1:7890"), "http://127.0.0.1:7890");
      expect(
        normalizeHttpProxy("https://proxy.example.com:8080/"),
        "https://proxy.example.com:8080",
      );
      expect(
        normalizeHttpProxy("http://user:pass@proxy.example.com:3128"),
        "http://user:pass@proxy.example.com:3128",
      );
      expect(
        normalizeHttpProxy("https://user:pass@proxy.example.com:443"),
        "https://user:pass@proxy.example.com:443",
      );
    });

    test("defaults scheme-less values to http and adds the default port", () {
      expect(normalizeHttpProxy("proxy.example.com"), "http://proxy.example.com:1080");
      expect(
        normalizeHttpProxy("user:pass@proxy.example.com"),
        "http://user:pass@proxy.example.com:1080",
      );
      expect(normalizeHttpProxy("[::1]"), "http://[::1]:1080");
      expect(normalizeHttpProxy("[::1]:7890"), "http://[::1]:7890");
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
      expect(config.httpProxy, "http://127.0.0.1:7890");
      expect(config.httpsProxy, "https://127.0.0.1:7891");
      expect(config.allProxy, "http://127.0.0.1:7892");
      expect(config.bypass, ["localhost", ".internal.example.com"]);
      expect(config.isEmpty, isFalse);
    });

    test("a lone no_proxy leaves the config empty", () {
      final config = systemProxyFromEnvironment({"no_proxy": "localhost"});
      expect(config.isEmpty, isTrue);
      expect(config.bypass, ["localhost"]);
    });

    test("an https proxy URL survives end to end for native chat", () {
      final config = systemProxyFromEnvironment({
        "https_proxy": "https://user:password@proxy.example:443",
      });
      expect(config.httpsProxy, "https://user:password@proxy.example:443");
      expect(
        proxyUrlFor(config, Uri.parse("https://api.openai.com/v1")),
        "https://user:password@proxy.example:443",
      );
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
      expect(config.httpProxy, "http://127.0.0.1:7890");
      expect(config.httpsProxy, "http://127.0.0.1:7891");
      expect(config.bypass, ["localhost"]);
    });

    test("use-same-proxy reuses the http proxy for https", () {
      final config = systemProxyFromGnome(
        mode: "manual",
        httpHost: "127.0.0.1",
        httpPort: 7890,
        useSameProxy: true,
      )!;
      expect(config.httpsProxy, "http://127.0.0.1:7890");
    });

    test("authentication credentials are embedded into the http proxy", () {
      final config = systemProxyFromGnome(
        mode: "manual",
        httpHost: "proxy.example.com",
        httpPort: 3128,
        httpsHost: "https-proxy.example.com",
        httpsPort: 3129,
        useAuthentication: true,
        authenticationUser: "alice",
        authenticationPassword: "s3cret",
      )!;
      expect(config.httpProxy, "http://alice:s3cret@proxy.example.com:3128");
      // GNOME stores credentials for the HTTP proxy only.
      expect(config.httpsProxy, "http://https-proxy.example.com:3129");
    });

    test("use-same-proxy carries the credentials over to https", () {
      final config = systemProxyFromGnome(
        mode: "manual",
        httpHost: "proxy.example.com",
        httpPort: 3128,
        useSameProxy: true,
        useAuthentication: true,
        authenticationUser: "alice",
        authenticationPassword: "s3cret",
      )!;
      expect(config.httpsProxy, "http://alice:s3cret@proxy.example.com:3128");
    });

    test("authentication without a user is ignored", () {
      final config = systemProxyFromGnome(
        mode: "manual",
        httpHost: "proxy.example.com",
        httpPort: 3128,
        useAuthentication: true,
        authenticationPassword: "s3cret",
      )!;
      expect(config.httpProxy, "http://proxy.example.com:3128");
    });

    test("manual mode without any usable host/port returns null", () {
      expect(systemProxyFromGnome(mode: "manual"), isNull);
      expect(systemProxyFromGnome(mode: "manual", httpHost: "127.0.0.1"), isNull);
    });
  });

  group("systemProxyWithExtraBypass", () {
    test("appends extra bypass entries, keeping the proxies", () {
      const gnome = SystemProxyConfig(httpProxy: "http://127.0.0.1:7890", bypass: ["localhost"]);
      final merged = systemProxyWithExtraBypass(gnome, const ["internal.example.com"]);
      expect(merged.httpProxy, "http://127.0.0.1:7890");
      expect(merged.bypass, ["localhost", "internal.example.com"]);
    });

    test("returns the config unchanged without extra entries", () {
      const gnome = SystemProxyConfig(httpProxy: "http://127.0.0.1:7890", bypass: ["localhost"]);
      expect(systemProxyWithExtraBypass(gnome, const []), same(gnome));
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
      expect(
        findProxyForUrl(config, Uri.parse("https://notexample.com/")),
        "PROXY https-proxy:8081",
      );
      const star = SystemProxyConfig(allProxy: "p:1", bypass: ["*"]);
      expect(findProxyForUrl(star, Uri.parse("https://foo.bar/")), "DIRECT");
    });

    test("unknown schemes and empty configs go direct", () {
      expect(findProxyForUrl(config, Uri.parse("ftp://foo.bar/")), "DIRECT");
      const empty = SystemProxyConfig();
      expect(findProxyForUrl(empty, Uri.parse("https://foo.bar/")), "DIRECT");
    });
  });

  group("GNOME ignore-hosts formats", () {
    String find(String url, List<String> bypass) =>
        findProxyForUrl(SystemProxyConfig(allProxy: "proxy:8080", bypass: bypass), Uri.parse(url));

    test("'*.example.com' matches the host itself and any subdomain", () {
      expect(find("https://example.com/", ["*.example.com"]), "DIRECT");
      expect(find("https://api.example.com/", ["*.example.com"]), "DIRECT");
      expect(find("https://deep.api.example.com/", ["*.example.com"]), "DIRECT");
      expect(find("https://notexample.com/", ["*.example.com"]), "PROXY proxy:8080");
    });

    test("port-qualified hostnames match only URLs on that port", () {
      expect(find("http://example.com/", ["example.com:80"]), "DIRECT");
      expect(find("http://example.com:80/", ["example.com:80"]), "DIRECT");
      expect(find("http://example.com:8080/", ["example.com:80"]), "PROXY proxy:8080");
      expect(find("https://example.com/", ["example.com:80"]), "PROXY proxy:8080");
      expect(find("https://example.com/", ["example.com:443"]), "DIRECT");
    });

    test("port-qualified entries keep subdomain matching", () {
      expect(find("https://api.example.com/", ["example.com:443"]), "DIRECT");
      expect(find("https://api.example.com/", ["*.example.com:443"]), "DIRECT");
    });

    test("IPv6 literals with a port require brackets", () {
      expect(find("https://[::1]/", ["[::1]:443"]), "DIRECT");
      expect(find("https://[::1]:8443/", ["[::1]:443"]), "PROXY proxy:8080");
      expect(find("https://[::1]/", ["::1"]), "DIRECT");
    });

    test("IPv4 CIDR ranges match addresses within the prefix", () {
      expect(find("http://127.0.0.1/", ["127.0.0.0/8"]), "DIRECT");
      expect(find("http://127.1.2.3/", ["127.0.0.0/8"]), "DIRECT");
      expect(find("http://128.0.0.1/", ["127.0.0.0/8"]), "PROXY proxy:8080");
      expect(find("http://127.0.0.1/", ["127.0.0.0/33"]), "PROXY proxy:8080");
    });

    test("IPv6 CIDR ranges match addresses within the prefix", () {
      expect(find("http://[fe80::1]/", ["fe80::/10"]), "DIRECT");
      expect(find("http://[febf:ffff::1]/", ["fe80::/10"]), "DIRECT");
      expect(find("http://[fec0::1]/", ["fe80::/10"]), "PROXY proxy:8080");
    });

    test("IP entries never match hostnames and vice versa", () {
      expect(find("http://example.com/", ["192.168.1.1"]), "PROXY proxy:8080");
      expect(find("http://192.168.1.1/", ["example.com"]), "PROXY proxy:8080");
      expect(find("http://192.168.1.1/", ["192.168.1.1"]), "DIRECT");
      expect(find("http://192.168.1.2/", ["192.168.1.1"]), "PROXY proxy:8080");
    });

    test("malformed entries never match", () {
      expect(find("http://example.com/", ["example.com:http"]), "PROXY proxy:8080");
      expect(find("http://[::1]/", ["[::1"]), "PROXY proxy:8080");
      expect(find("http://127.0.0.1/", ["127.0.0.0/"]), "PROXY proxy:8080");
    });

    test("malformed IPv4 bypass entries never match", () {
      // A negative component must not be masked into the prefix range.
      expect(find("http://255.0.0.1/", ["-1.0.0.0/8"]), "PROXY proxy:8080");
      expect(find("http://1.0.0.1/", ["1.0.-1.0/16"]), "PROXY proxy:8080");
      expect(find("http://255.0.0.1/", ["-1.0.0.0/0"]), "PROXY proxy:8080");
    });

    test("malformed IPv6 bypass entries never match", () {
      expect(find("http://[fe80::1]/", ["-1::/16"]), "PROXY proxy:8080");
      expect(find("http://[fe80::1]/", ["fe80::-1"]), "PROXY proxy:8080");
      expect(find("http://[fe80::1]/", ["fe80::10000"]), "PROXY proxy:8080");
    });
  });

  group("proxyUrlFor", () {
    test("returns a full URL for proxied targets, null for direct ones", () {
      const config = SystemProxyConfig(httpsProxy: "http://127.0.0.1:7890", bypass: ["localhost"]);
      expect(proxyUrlFor(config, Uri.parse("https://api.openai.com/v1")), "http://127.0.0.1:7890");
      expect(proxyUrlFor(config, Uri.parse("https://localhost/v1")), isNull);
    });

    test("keeps embedded credentials for both transports", () {
      const config = SystemProxyConfig(httpsProxy: "http://alice:s3cret@127.0.0.1:7890");
      final url = Uri.parse("https://api.openai.com/v1");
      expect(findProxyForUrl(config, url), "PROXY alice:s3cret@127.0.0.1:7890");
      expect(proxyUrlFor(config, url), "http://alice:s3cret@127.0.0.1:7890");
    });

    test("preserves an https proxy scheme and credentials for native chat", () {
      // The resolved URL is handed to the efa-chat reqwest client
      // (build_http_client); downgrading it to http:// would expose the proxy
      // credentials in cleartext to an on-path actor.
      const config = SystemProxyConfig(httpsProxy: "https://user:password@proxy.example:443");
      final url = Uri.parse("https://api.openai.com/v1");
      // dart:io's PROXY directive carries no scheme; the reqwest path does.
      expect(findProxyForUrl(config, url), "PROXY user:password@proxy.example:443");
      expect(proxyUrlFor(config, url), "https://user:password@proxy.example:443");
    });

    test("treats scheme-less values as plain http proxies", () {
      const config = SystemProxyConfig(httpsProxy: "127.0.0.1:7890");
      expect(proxyUrlFor(config, Uri.parse("https://api.openai.com/v1")), "http://127.0.0.1:7890");
    });
  });

  group("systemProxyRoutingFor", () {
    test("carries the proxy URL for proxied targets", () {
      const config = SystemProxyConfig(allProxy: "http://127.0.0.1:7890");
      final routing = systemProxyRoutingFor(config, Uri.parse("https://api.openai.com/v1"));
      expect(routing.isDirect, isFalse);
      expect(routing.proxyUrl, "http://127.0.0.1:7890");
    });

    test("marks bypassed targets as an explicit direct route", () {
      // A bypassed endpoint must stay distinguishable from "no proxy
      // configured": the native chat client disables env-var proxying for an
      // explicit direct route, while the default route keeps it.
      const config = SystemProxyConfig(
        allProxy: "http://127.0.0.1:7890",
        bypass: ["localhost"],
      );
      final routing = systemProxyRoutingFor(config, Uri.parse("https://localhost/v1"));
      expect(routing.isDirect, isTrue);
      expect(routing.proxyUrl, isNull);
    });

    test("marks targets no proxy covers as an explicit direct route", () {
      const config = SystemProxyConfig(httpProxy: "http://127.0.0.1:7890");
      final routing = systemProxyRoutingFor(config, Uri.parse("https://api.openai.com/v1"));
      expect(routing.isDirect, isTrue);
    });
  });
}
