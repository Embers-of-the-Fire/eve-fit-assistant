/// Web variant: the browser applies its own proxy settings, so there is no
/// system proxy to resolve. See `system_proxy_io.dart`.
library;

/// Always `null` on web.
String Function(Uri)? systemProxyFindProxy() => null;

/// Always `null` on web.
String? systemProxyUrlFor(Uri url) => null;
