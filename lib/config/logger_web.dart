/// Web logging sink backed by the browser `console` API.
///
/// `package:logger` requires `dart:io`, so on web the browser `console`
/// methods are bound directly through `dart:js_interop`. Each record is
/// emitted as a single console entry carrying its embedded newlines, which
/// browser consoles render as a multi-line block — keeping stack traces and
/// formatted errors grouped with their message in one entry.
library;

// We accept dynamic messages here.
// ignore_for_file: avoid_annotating_with_dynamic

import "dart:js_interop";

void debug(dynamic message, {StackTrace? stackTrace}) {
  _log(_ConsoleLevel.debug, message, stackTrace);
}

void info(dynamic message, {StackTrace? stackTrace}) {
  _log(_ConsoleLevel.info, message, stackTrace);
}

void warning(dynamic message, {StackTrace? stackTrace}) {
  _log(_ConsoleLevel.warn, message, stackTrace);
}

void error(dynamic message, {StackTrace? stackTrace, Object? error}) {
  _log(_ConsoleLevel.error, message, stackTrace, error);
}

void fatal(dynamic message, {StackTrace? stackTrace, Object? error}) {
  _log(_ConsoleLevel.error, message, stackTrace, error);
}

enum _ConsoleLevel {
  debug("DEBUG"),
  info("INFO"),
  warn("WARN"),
  error("ERROR");

  const _ConsoleLevel(this.tag);

  final String tag;

  void write(String record) {
    final jsRecord = record.toJS;
    switch (this) {
      case _ConsoleLevel.debug:
        _consoleDebug(jsRecord);
      case _ConsoleLevel.info:
        _consoleInfo(jsRecord);
      case _ConsoleLevel.warn:
        _consoleWarn(jsRecord);
      case _ConsoleLevel.error:
        _consoleError(jsRecord);
    }
  }
}

void _log(_ConsoleLevel level, dynamic message, StackTrace? stackTrace, [Object? error]) {
  final buffer = StringBuffer("[${level.tag}] $message");
  if (error != null) buffer.write(" | $error");
  if (stackTrace != null) buffer.write("\n$stackTrace");
  level.write(buffer.toString());
}

@JS("console.debug")
external void _consoleDebug(JSString message);

@JS("console.info")
external void _consoleInfo(JSString message);

@JS("console.warn")
external void _consoleWarn(JSString message);

@JS("console.error")
external void _consoleError(JSString message);

/// Web variant of the global logger. File logging is unavailable on web, so
/// only console output is kept. [GlobalLogger.init] accepts the same
/// arguments as the IO variant and ignores the file output directory.
class GlobalLogger {
  static void init(String fileOutputDir, {required bool enableDebugLog}) {}
}
