/// System proxy resolution for desktop (Linux) builds.
///
/// This file holds the pure, platform-independent resolution logic: parsing
/// the conventional `http_proxy`/`https_proxy`/`all_proxy`/`no_proxy`
/// environment variables and the GNOME `org.gnome.system.proxy` settings into
/// a [SystemProxyConfig], and deciding per-URL whether a request goes direct
/// or through a proxy. The platform glue that actually reads the environment
/// and runs `gsettings` lives in `system_proxy_io.dart` (with a web stub in
/// `system_proxy_stub.dart`).
library;

/// A resolved system proxy configuration.
///
/// Proxy values are normalized proxy URLs: an `http://` or `https://` scheme,
/// optional `user:password@` userinfo, and an explicit port. [bypass] holds
/// the `no_proxy`/ignore-hosts entries. Only HTTP (CONNECT) proxies are
/// representable: `dart:io`'s `HttpClient.findProxy` supports
/// `PROXY host:port` and `DIRECT` only, so SOCKS proxies are dropped during
/// parsing and the scheme is stripped again for the dart:io transport. The
/// full URL is kept for native chat, where reqwest honors an `https://`
/// proxy scheme (TLS to the proxy) instead of downgrading the connection.
class SystemProxyConfig {
  const SystemProxyConfig({this.httpProxy, this.httpsProxy, this.allProxy, this.bypass = const []});

  /// Proxy for `http://` URLs, as a proxy URL (`scheme://[user:password@]host:port`).
  final String? httpProxy;

  /// Proxy for `https://` URLs, as a proxy URL (`scheme://[user:password@]host:port`).
  final String? httpsProxy;

  /// Fallback proxy for any scheme, as a proxy URL (`scheme://[user:password@]host:port`).
  final String? allProxy;

  /// Hosts that must be reached directly (`no_proxy` / GNOME ignore-hosts).
  final List<String> bypass;

  /// Whether no proxy is configured at all (a lone `no_proxy` does not count).
  bool get isEmpty => httpProxy == null && httpsProxy == null && allProxy == null;
}

/// The default port assumed when a proxy value carries no port, matching
/// `dart:io`'s `HttpClient.findProxyFromEnvironment` convention.
const int _defaultProxyPort = 1080;

/// Normalize an environment/gsettings proxy value to a proxy URL with an
/// `http://` or `https://` scheme (keeping an optional `user:password@`
/// prefix). Values without a scheme are treated as plain HTTP proxies.
/// Returns `null` for empty values and for non-HTTP schemes such as
/// `socks5://`, which neither `dart:io` nor the chat client uses here.
///
/// The scheme is preserved so native consumers (the efa-chat reqwest client)
/// can keep a TLS connection to an `https://` proxy instead of silently
/// downgrading it — and its embedded credentials — to cleartext HTTP.
String? normalizeHttpProxy(String? value) {
  var v = value?.trim() ?? "";
  if (v.isEmpty) return null;
  var scheme = "http";
  final schemeEnd = v.indexOf("://");
  if (schemeEnd >= 0) {
    scheme = v.substring(0, schemeEnd).toLowerCase();
    if (scheme != "http" && scheme != "https") return null;
    v = v.substring(schemeEnd + 3);
  }
  // Drop any path component; keep userinfo@host:port intact.
  final pathStart = v.indexOf("/");
  if (pathStart >= 0) v = v.substring(0, pathStart);
  if (v.isEmpty) return null;
  // Add the default port if none is configured (mirroring dart:io).
  final authority = v.substring(v.lastIndexOf("@") + 1);
  if (authority.startsWith("[")) {
    // IPv6 literal: a port is present only when a colon follows the bracket.
    final closing = authority.indexOf("]");
    if (closing < 0 || closing == authority.length - 1) v = "$v:$_defaultProxyPort";
  } else if (!authority.contains(":")) {
    v = "$v:$_defaultProxyPort";
  }
  return "$scheme://$v";
}

/// Whether [host] matches one bypass entry. Supports `*` (match everything)
/// and suffix matching (`example.com` also covers `www.example.com`),
/// mirroring `dart:io`'s no-proxy semantics.
bool _isBypassed(List<String> bypass, String host) {
  final h = host.toLowerCase();
  for (final raw in bypass) {
    var entry = raw.trim().toLowerCase();
    if (entry.isEmpty) continue;
    if (entry == "*") return true;
    if (entry.startsWith("[") && entry.endsWith("]") && "[$h]" == entry) return true;
    if (entry.startsWith(".")) entry = entry.substring(1);
    if (h == entry || h.endsWith(".$entry")) return true;
  }
  return false;
}

/// Parse the conventional proxy environment variables
/// (`http_proxy`/`https_proxy`/`all_proxy`/`no_proxy`, lower- or uppercase).
/// `no_proxy` is honored even when no proxy variable is set.
SystemProxyConfig systemProxyFromEnvironment(Map<String, String> env) {
  String? lookup(String lower, String upper) => env[lower] ?? env[upper];
  final bypass = (lookup("no_proxy", "NO_PROXY") ?? "")
      .split(",")
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  return SystemProxyConfig(
    httpProxy: normalizeHttpProxy(lookup("http_proxy", "HTTP_PROXY")),
    httpsProxy: normalizeHttpProxy(lookup("https_proxy", "HTTPS_PROXY")),
    allProxy: normalizeHttpProxy(lookup("all_proxy", "ALL_PROXY")),
    bypass: bypass,
  );
}

/// Build a config from the GNOME `org.gnome.system.proxy` settings.
///
/// Returns `null` unless [mode] is `manual` (GNOME's `auto` mode points at a
/// PAC script, which cannot be evaluated without a JS engine). When
/// [useSameProxy] is set, the HTTP proxy also covers HTTPS URLs.
///
/// When [useAuthentication] is set, `user:password@` is embedded into the
/// HTTP proxy (and the HTTPS one via `use-same-proxy`): GNOME only stores
/// credentials for the HTTP proxy. Both transports pick credentials up from
/// the userinfo part — `dart:io` parses them out of the
/// `PROXY user:password@host:port` directive, reqwest out of the proxy URL.
/// GNOME models plain HTTP CONNECT proxies only (host/port, no scheme), so
/// the emitted values carry an `http://` scheme.
SystemProxyConfig? systemProxyFromGnome({
  required String mode,
  String httpHost = "",
  int httpPort = 0,
  String httpsHost = "",
  int httpsPort = 0,
  bool useSameProxy = false,
  bool useAuthentication = false,
  String authenticationUser = "",
  String authenticationPassword = "",
  List<String> ignoreHosts = const [],
}) {
  if (mode.trim() != "manual") return null;
  final user = authenticationUser.trim();
  final auth = useAuthentication && user.isNotEmpty ? "$user:$authenticationPassword@" : "";
  String? proxy(String host, int port, {bool authenticated = false}) {
    final h = host.trim();
    if (h.isEmpty || port <= 0) return null;
    return "http://${authenticated ? auth : ""}$h:$port";
  }

  final http = proxy(httpHost, httpPort, authenticated: true);
  final https = useSameProxy ? http : proxy(httpsHost, httpsPort);
  if (http == null && https == null) return null;
  return SystemProxyConfig(httpProxy: http, httpsProxy: https, bypass: ignoreHosts);
}

/// Return [config] with [extraBypass] entries appended to its bypass list.
///
/// Used to keep a lone `no_proxy` environment variable effective when the
/// actual proxies come from the GNOME desktop settings.
SystemProxyConfig systemProxyWithExtraBypass(SystemProxyConfig config, List<String> extraBypass) {
  if (extraBypass.isEmpty) return config;
  return SystemProxyConfig(
    httpProxy: config.httpProxy,
    httpsProxy: config.httpsProxy,
    allProxy: config.allProxy,
    bypass: [...config.bypass, ...extraBypass],
  );
}

/// The normalized proxy value applying to [url], or `null` when the URL is
/// reached directly.
String? _proxyForUrl(SystemProxyConfig config, Uri url) {
  if (_isBypassed(config.bypass, url.host)) return null;
  return switch (url.scheme.toLowerCase()) {
    "http" => config.httpProxy ?? config.allProxy,
    "https" => config.httpsProxy ?? config.allProxy,
    _ => null,
  };
}

/// The `host:port` authority (with optional userinfo) of a normalized proxy
/// value. `dart:io`'s `PROXY` directive carries no scheme.
String _proxyAuthority(String proxy) {
  final schemeEnd = proxy.indexOf("://");
  return schemeEnd >= 0 ? proxy.substring(schemeEnd + 3) : proxy;
}

/// Resolve the `HttpClient.findProxy` directive for [url]:
/// `PROXY host:port` when a proxy applies, `DIRECT` otherwise.
///
/// dart:io can only speak cleartext HTTP CONNECT to a proxy, so an
/// `https://` proxy scheme is dropped here; the scheme is honored on the
/// native chat path via [proxyUrlFor].
String findProxyForUrl(SystemProxyConfig config, Uri url) {
  final proxy = _proxyForUrl(config, url);
  return proxy == null ? "DIRECT" : "PROXY ${_proxyAuthority(proxy)}";
}

/// The proxy URL (`scheme://[user:password@]host:port`) that applies to
/// [url], or `null` when the URL is reached directly. Used to hand the
/// resolved proxy to native code (the efa-chat reqwest client), which takes
/// a full URL; reqwest applies the userinfo as basic proxy credentials and
/// honors an `https://` scheme as TLS to the proxy, so the configured scheme
/// must be preserved here rather than downgraded to cleartext HTTP.
String? proxyUrlFor(SystemProxyConfig config, Uri url) {
  final proxy = _proxyForUrl(config, url);
  if (proxy == null) return null;
  return proxy.contains("://") ? proxy : "http://$proxy";
}
