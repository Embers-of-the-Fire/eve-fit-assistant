/// Global logging facade.
///
/// On native platforms this uses `package:logger` with console + rotating
/// file outputs. On web (`package:logger` requires `dart:io`) it emits to the
/// browser `console` via `dart:js_interop`, one console entry per record whose
/// embedded newlines render as a multi-line block.
library;

export "logger_io.dart" if (dart.library.js_interop) "logger_web.dart";
