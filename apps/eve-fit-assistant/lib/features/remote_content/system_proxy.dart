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
/// parsing. dart:io can only speak cleartext HTTP CONNECT to a proxy, so an
/// `https://` proxy (TLS to the proxy) fails closed on the dart:io
/// transport: [findProxyForUrl] throws [UnsupportedProxyException] rather
/// than silently bypassing the configured egress policy with `DIRECT` or
/// downgrading the connection — and its credentials — to cleartext. The directive carries no userinfo either —
/// dart:io does not percent-decode credentials embedded in it — so the
/// dart:io transport takes the decoded credentials from
/// [systemProxyCredentials] instead. The full URL is kept for native chat,
/// where reqwest honors an `https://` proxy scheme (TLS to the proxy)
/// instead of downgrading the connection.
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

/// Whether [url] matches one bypass entry. Supports the GNOME `ignore-hosts`
/// formats (a superset of `dart:io`'s no-proxy semantics), see
/// https://docs.gtk.org/gio/property.SimpleProxyResolver.ignore-hosts.html:
///
/// - `*` matches everything.
/// - A hostname (`example.com`, `.example.com`, or `*.example.com`) matches
///   the host itself and any subdomain of it.
/// - An IPv4 or IPv6 address matches only that exact address; hostname
///   entries never match IP-literal hosts and vice versa.
/// - Any entry may carry a `:port` qualifier (`example.com:80`,
///   `[::1]:443`), restricting the match to URLs using that port.
/// - An IP range in CIDR notation (`127.0.0.0/8`, `fe80::/10`) matches any
///   address within the range.
bool _isBypassed(List<String> bypass, Uri url) {
  var host = url.host.toLowerCase();
  if (host.startsWith("[") && host.endsWith("]")) host = host.substring(1, host.length - 1);
  final hostIp = _parseIpBytes(host);
  final port = url.port;
  for (final raw in bypass) {
    var entry = raw.trim().toLowerCase();
    if (entry.isEmpty) continue;

    // Strip an optional :port qualifier; it restricts the entry to that
    // port. IPv6 literals keep their brackets for the qualifier (`[::1]:443`).
    if (entry.startsWith("[")) {
      final closing = entry.indexOf("]");
      if (closing < 0) continue;
      if (entry.length > closing + 1) {
        final entryPort = int.tryParse(entry.substring(closing + 2));
        if (entry[closing + 1] != ":" || entryPort == null || entryPort != port) continue;
      }
      entry = entry.substring(1, closing);
    } else if (entry.contains(":") && entry.indexOf(":") == entry.lastIndexOf(":")) {
      final colon = entry.lastIndexOf(":");
      final entryPort = int.tryParse(entry.substring(colon + 1));
      if (entryPort != null) {
        if (entryPort != port) continue;
        entry = entry.substring(0, colon);
      }
    }
    if (entry == "*") return true;

    // CIDR range: base address plus prefix length (`127.0.0.0/8`).
    final slash = entry.indexOf("/");
    if (slash >= 0) {
      final base = _parseIpBytes(entry.substring(0, slash));
      final prefix = int.tryParse(entry.substring(slash + 1));
      if (base != null && prefix != null && hostIp != null && _ipInPrefix(hostIp, base, prefix)) {
        return true;
      }
      continue;
    }

    final entryIp = _parseIpBytes(entry);
    if (hostIp != null || entryIp != null) {
      // IP entries match only IP-literal hosts, and only exactly; hostname
      // entries never match IP-literal hosts.
      if (hostIp != null && entryIp != null && _ipEquals(hostIp, entryIp)) return true;
      continue;
    }

    if (entry.startsWith("*.")) {
      entry = entry.substring(2);
    } else if (entry.startsWith(".")) {
      entry = entry.substring(1);
    }
    if (host == entry || host.endsWith(".$entry")) return true;
  }
  return false;
}

/// Parse an IPv4 or IPv6 literal into its bytes (4 for IPv4, 16 for IPv6),
/// or `null` when [value] is not an IP literal. IPv6 addresses with an
/// embedded IPv4 tail (`::ffff:127.0.0.1`) are not recognized.
List<int>? _parseIpBytes(String value) => _parseIpv4Bytes(value) ?? _parseIpv6Bytes(value);

List<int>? _parseIpv4Bytes(String value) {
  final parts = value.split(".");
  if (parts.length != 4) return null;
  final bytes = <int>[];
  for (final part in parts) {
    final n = int.tryParse(part);
    if (n == null || n < 0 || n > 255 || n.toString() != part) return null;
    bytes.add(n);
  }
  return bytes;
}

List<int>? _parseIpv6Bytes(String value) {
  final dc = value.indexOf("::");
  if (dc >= 0 && value.indexOf("::", dc + 2) >= 0) return null; // at most one "::"
  final head = dc >= 0 ? value.substring(0, dc) : value;
  final tail = dc >= 0 ? value.substring(dc + 2) : "";
  final headGroups = head.isEmpty ? <String>[] : head.split(":");
  final tailGroups = tail.isEmpty ? <String>[] : tail.split(":");
  if (headGroups.any((g) => g.isEmpty) || tailGroups.any((g) => g.isEmpty)) return null;
  if (dc < 0 && headGroups.length != 8) return null;
  if (dc >= 0 && headGroups.length + tailGroups.length > 8) return null;

  int? group(String g) {
    if (g.isEmpty || g.length > 4) return null;
    final n = int.tryParse(g, radix: 16);
    // tryParse accepts a leading sign; negative groups are not valid.
    return n != null && n < 0 ? null : n;
  }

  final groups = <int>[];
  for (final g in headGroups) {
    final n = group(g);
    if (n == null) return null;
    groups.add(n);
  }
  if (dc >= 0) {
    for (var i = headGroups.length + tailGroups.length; i < 8; i++) {
      groups.add(0);
    }
  }
  for (final g in tailGroups) {
    final n = group(g);
    if (n == null) return null;
    groups.add(n);
  }
  if (groups.length != 8) return null;
  return [
    for (final n in groups) ...[n >> 8, n & 0xff],
  ];
}

bool _ipEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Whether the IP [host] lies within [base]/[prefixLength] (CIDR).
bool _ipInPrefix(List<int> host, List<int> base, int prefixLength) {
  if (host.length != base.length || prefixLength < 0 || prefixLength > host.length * 8) {
    return false;
  }
  var bits = prefixLength;
  for (var i = 0; i < host.length && bits > 0; i++, bits -= 8) {
    final mask = bits >= 8 ? 0xff : (0xff << (8 - bits)) & 0xff;
    if ((host[i] & mask) != (base[i] & mask)) return false;
  }
  return true;
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
/// credentials for the HTTP proxy. User and password are percent-encoded
/// separately, so reserved characters (`/`, `?`, `#`, ...) in either cannot
/// corrupt the proxy URL handed to reqwest on the native chat path; the
/// dart:io transport takes the decoded credentials from
/// [systemProxyCredentials] instead, as its `PROXY` directive carries no
/// userinfo. GNOME models plain HTTP CONNECT proxies only (host/port, no
/// scheme), so the emitted values carry an `http://` scheme.
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
  final auth = useAuthentication && user.isNotEmpty
      ? "${Uri.encodeComponent(user)}:${Uri.encodeComponent(authenticationPassword)}@"
      : "";
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

/// Whether [url] matches [config]'s bypass list (`no_proxy` / GNOME
/// ignore-hosts) and so must be reached directly.
///
/// This is distinct from "no proxy covers the URL's scheme", though both
/// make [proxyUrlFor] return `null`. Callers that hand a routing decision to
/// the native chat client must keep the two apart: a bypass disables
/// proxying entirely, while an uncovered scheme still takes the full proxy
/// config so a cross-scheme redirect can pick up that scheme's proxy.
bool systemProxyBypasses(SystemProxyConfig config, Uri url) => _isBypassed(config.bypass, url);

/// The normalized proxy value applying to [url], or `null` when the URL is
/// reached directly.
String? _proxyForUrl(SystemProxyConfig config, Uri url) {
  if (_isBypassed(config.bypass, url)) return null;
  return switch (url.scheme.toLowerCase()) {
    "http" => config.httpProxy ?? config.allProxy,
    "https" => config.httpsProxy ?? config.allProxy,
    _ => null,
  };
}

/// The routing decision for a URL under a resolved [SystemProxyConfig]:
/// either a proxy URL to route through, or an explicit direct connection (a
/// bypass matched, or no proxy covers the URL's scheme).
///
/// This is distinct from "no system proxy configured at all", where callers
/// keep the HTTP client's own default (env-var) handling: an explicit direct
/// decision lets native code disable env-var proxying, which the default
/// client would otherwise apply to a bypassed endpoint.
class SystemProxyRouting {
  /// The URL is reached directly.
  const SystemProxyRouting.direct() : proxyUrl = null;

  /// Route through [proxyUrl].
  const SystemProxyRouting.proxy(this.proxyUrl);

  /// The proxy URL to route through, or `null` for an explicit direct
  /// connection.
  final String? proxyUrl;

  /// Whether the URL is reached directly.
  bool get isDirect => proxyUrl == null;
}

/// Resolve the routing for [url] under [config].
SystemProxyRouting systemProxyRoutingFor(SystemProxyConfig config, Uri url) {
  final proxy = proxyUrlFor(config, url);
  return proxy == null ? const SystemProxyRouting.direct() : SystemProxyRouting.proxy(proxy);
}

/// The `host:port` authority of a normalized proxy value. `dart:io`'s
/// `PROXY` directive carries neither the scheme nor the userinfo.
String _proxyAuthority(String proxy) {
  final schemeEnd = proxy.indexOf("://");
  final authority = schemeEnd >= 0 ? proxy.substring(schemeEnd + 3) : proxy;
  final at = authority.lastIndexOf("@");
  return at >= 0 ? authority.substring(at + 1) : authority;
}

/// Thrown by [findProxyForUrl] when the proxy applying to a URL uses an
/// `https://` scheme (TLS to the proxy), which dart:io cannot speak.
///
/// dart:io can only speak cleartext HTTP CONNECT to a proxy, so the
/// alternatives are both insecure: returning the proxy authority would make
/// dart:io open a plain socket to the proxy and send the CONNECT request —
/// and the proxy credentials — in cleartext, while returning `DIRECT` would
/// silently bypass the configured egress policy. Throwing fails the request
/// closed instead: dart:io surfaces the error to the caller of
/// `HttpClient.openUrl` before any connection is opened. The exception
/// carries only the proxy `host:port` authority, never the userinfo, so
/// credentials cannot leak into logs. The `https://` scheme remains honored
/// on the native chat path via [proxyUrlFor], where reqwest supports TLS to
/// the proxy.
class UnsupportedProxyException implements Exception {
  const UnsupportedProxyException(this.proxyAuthority);

  /// The `host:port` of the unsupported `https://` proxy (no userinfo).
  final String proxyAuthority;

  @override
  String toString() =>
      "UnsupportedProxyException: dart:io cannot use https:// proxy $proxyAuthority "
      "(TLS to the proxy is not supported)";
}

/// Resolve the `HttpClient.findProxy` directive for [url]:
/// `PROXY host:port` when a proxy applies, `DIRECT` otherwise.
///
/// dart:io can only speak cleartext HTTP CONNECT to a proxy (TLS, if any,
/// starts only inside the destination tunnel), so an `https://` proxy — TLS
/// to the proxy — cannot be honored: returning its authority here would make
/// dart:io open a plain socket to the proxy and send the proxy credentials
/// in cleartext, while returning `DIRECT` would silently bypass the
/// configured egress policy. Such proxies therefore fail closed: the
/// function throws [UnsupportedProxyException], which dart:io surfaces to
/// the caller of `HttpClient.openUrl` before any connection is opened. The
/// `https://` scheme is honored on the native chat path via [proxyUrlFor].
/// The directive likewise drops the userinfo: dart:io does not
/// percent-decode credentials embedded in it, so they are registered
/// with `HttpClient.addProxyCredentials` instead — see
/// [systemProxyCredentials].
String findProxyForUrl(SystemProxyConfig config, Uri url) {
  final proxy = _proxyForUrl(config, url);
  if (proxy == null) return "DIRECT";
  if (proxy.toLowerCase().startsWith("https://")) {
    throw UnsupportedProxyException(_proxyAuthority(proxy));
  }
  return "PROXY ${_proxyAuthority(proxy)}";
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

/// The decoded credentials of one authenticated proxy, for
/// `HttpClient.addProxyCredentials` / `HttpClient.authenticateProxy`.
class SystemProxyCredentials {
  const SystemProxyCredentials({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  /// The proxy host the credentials apply to.
  final String host;

  /// The proxy port the credentials apply to.
  final int port;

  /// The percent-decoded username.
  final String username;

  /// The percent-decoded password (possibly empty).
  final String password;
}

/// The credentials of every authenticated proxy in [config], one entry per
/// distinct proxy value carrying userinfo.
///
/// The `HttpClient.findProxy` directive carries no userinfo (and dart:io
/// would not percent-decode it anyway), so credentials embedded in the
/// proxy values — percent-encoded when they come from the GNOME settings —
/// must be registered with `HttpClient.addProxyCredentials` and served from
/// `HttpClient.authenticateProxy` instead. On the native chat path reqwest
/// keeps reading them straight out of the proxy URL.
List<SystemProxyCredentials> systemProxyCredentials(SystemProxyConfig config) {
  final credentials = <SystemProxyCredentials>[];
  final seen = <String>{};
  for (final proxy in [config.httpProxy, config.httpsProxy, config.allProxy]) {
    if (proxy == null || !seen.add(proxy)) continue;
    final parsed = Uri.tryParse(proxy.contains("://") ? proxy : "http://$proxy");
    if (parsed == null || parsed.userInfo.isEmpty) continue;
    // Uri.userInfo is not percent-decoded; decode each part separately so a
    // colon inside an encoded password cannot split the pair early.
    final userinfo = parsed.userInfo;
    final colon = userinfo.indexOf(":");
    credentials.add(
      SystemProxyCredentials(
        host: parsed.host,
        port: parsed.port,
        username: Uri.decodeComponent(colon < 0 ? userinfo : userinfo.substring(0, colon)),
        password: colon < 0 ? "" : Uri.decodeComponent(userinfo.substring(colon + 1)),
      ),
    );
  }
  return credentials;
}
