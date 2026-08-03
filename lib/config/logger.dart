/// Global logging facade.
///
/// On native platforms this uses `package:logger` with console + rotating
/// file outputs. On web (`package:logger` requires `dart:io`) it falls back
/// to console-only logging via `debugPrint`.
library;

export "logger_io.dart" if (dart.library.js_interop) "logger_web.dart";
