/// Raises the fd soft limit to the hard limit on Linux (no-op elsewhere).
library;

export "fd_limit_io.dart" if (dart.library.js_interop) "fd_limit_stub.dart";
