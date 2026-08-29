/// Web variant: the browser applies its own proxy settings, so there is no
/// system proxy to resolve. See `system_proxy_io.dart`.
library;

import "package:eve_fit_assistant/features/remote_content/system_proxy.dart";

/// Always `null` on web.
SystemProxyConfig? get systemProxyConfig => null;
