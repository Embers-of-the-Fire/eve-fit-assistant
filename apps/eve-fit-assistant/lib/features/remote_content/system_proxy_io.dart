import "dart:io";

import "package:eve_fit_assistant/features/remote_content/system_proxy.dart";

/// Linux desktop proxy glue: resolves the [SystemProxyConfig] once from the
/// process environment, falling back to the GNOME `org.gnome.system.proxy`
/// settings (read via `gsettings`) when no proxy environment variable is
/// set. GUI-launched desktop apps usually do not inherit shell proxy
/// variables, which is why the desktop settings matter.
///
/// The result is cached: `HttpClient.findProxy` is synchronous, so the
/// (process-spawning) gsettings lookup happens exactly once, on first use.

SystemProxyConfig? _cached;
bool _resolved = false;

/// The resolved desktop proxy config, or `null` off Linux.
SystemProxyConfig? get systemProxyConfig {
  if (!Platform.isLinux) return null;
  if (!_resolved) {
    _resolved = true;
    _cached = _resolve();
  }
  return _cached;
}

SystemProxyConfig? _resolve() {
  final fromEnv = systemProxyFromEnvironment(Platform.environment);
  if (!fromEnv.isEmpty) return fromEnv;
  final gnome = _readGnomeProxy();
  // A lone `no_proxy` does not count as an env proxy, but its bypass entries
  // must stay effective when the desktop proxy settings take over.
  return gnome == null ? null : systemProxyWithExtraBypass(gnome, fromEnv.bypass);
}

String? _gsettings(List<String> args) {
  try {
    final result = Process.runSync("gsettings", args);
    if (result.exitCode != 0) return null;
    return (result.stdout as String).trim();
  } on Object {
    // gsettings missing (non-GNOME desktop, minimal container, ...).
    return null;
  }
}

/// Parse a gsettings scalar: strings come out single-quoted
/// (`'manual'`), integers/booleans bare (`7890`, `true`).
String _gsettingsScalar(String? raw) {
  var v = (raw ?? "").trim();
  if (v.length >= 2 && v.startsWith("'") && v.endsWith("'")) {
    v = v.substring(1, v.length - 1);
  }
  return v;
}

/// Parse a gsettings string array: `['localhost', '127.0.0.0/8', '::1']`.
List<String> _gsettingsStringList(String? raw) {
  var v = (raw ?? "").trim();
  if (v.length >= 2 && v.startsWith("[") && v.endsWith("]")) {
    v = v.substring(1, v.length - 1);
  }
  return v
      .split(",")
      .map(_gsettingsScalar)
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
}

SystemProxyConfig? _readGnomeProxy() {
  final mode = _gsettingsScalar(_gsettings(["get", "org.gnome.system.proxy", "mode"]));
  if (mode.isEmpty) return null;
  String ghttp(String key) =>
      _gsettingsScalar(_gsettings(["get", "org.gnome.system.proxy.http", key]));
  return systemProxyFromGnome(
    mode: mode,
    httpHost: ghttp("host"),
    httpPort: int.tryParse(ghttp("port")) ?? 0,
    httpsHost: _gsettingsScalar(_gsettings(["get", "org.gnome.system.proxy.https", "host"])),
    httpsPort:
        int.tryParse(
          _gsettingsScalar(_gsettings(["get", "org.gnome.system.proxy.https", "port"])),
        ) ??
        0,
    useSameProxy:
        _gsettingsScalar(_gsettings(["get", "org.gnome.system.proxy", "use-same-proxy"])) == "true",
    useAuthentication: ghttp("use-authentication") == "true",
    authenticationUser: ghttp("authentication-user"),
    authenticationPassword: ghttp("authentication-password"),
    ignoreHosts: _gsettingsStringList(
      _gsettings(["get", "org.gnome.system.proxy", "ignore-hosts"]),
    ),
  );
}

/// The `HttpClient.findProxy` function honoring the Linux desktop proxy
/// settings, or `null` off Linux / when no proxy is configured (in which
/// case dart:io's default env-var handling applies).
String Function(Uri)? systemProxyFindProxy() {
  final config = systemProxyConfig;
  if (config == null) return null;
  return (url) => findProxyForUrl(config, url);
}

/// The routing decision for [url] under the Linux desktop proxy settings, or
/// `null` off Linux / when no proxy is configured (in which case the client's
/// default env-var proxy handling applies). An explicit
/// [SystemProxyRouting.direct] means the endpoint matched a proxy bypass and
/// must not fall back to proxy env vars. Used to hand the resolved routing
/// to the efa-chat reqwest client.
SystemProxyRouting? systemProxyRoutingForUrl(Uri url) {
  final config = systemProxyConfig;
  return config == null ? null : systemProxyRoutingFor(config, url);
}
