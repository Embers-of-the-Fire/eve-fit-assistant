// We accept dynamic messages here.
// ignore_for_file: avoid_annotating_with_dynamic

import "package:flutter/foundation.dart";

void debug(dynamic message, {StackTrace? stackTrace}) {
  _log("DEBUG", message, stackTrace);
}

void info(dynamic message, {StackTrace? stackTrace}) {
  _log("INFO", message, stackTrace);
}

void warning(dynamic message, {StackTrace? stackTrace}) {
  _log("WARN", message, stackTrace);
}

void error(dynamic message, {StackTrace? stackTrace, Object? error}) {
  _log("ERROR", message, stackTrace, error);
}

void fatal(dynamic message, {StackTrace? stackTrace, Object? error}) {
  _log("FATAL", message, stackTrace, error);
}

void _log(String level, dynamic message, StackTrace? stackTrace, [Object? error]) {
  final buffer = StringBuffer("[$level] $message");
  if (error != null) buffer.write(" | $error");
  if (stackTrace != null) buffer.write("\n$stackTrace");
  debugPrint(buffer.toString());
}

/// Web variant of the global logger. File logging is unavailable on web, so
/// only console output is kept. [GlobalLogger.init] accepts the same
/// arguments as the IO variant and ignores the file output directory.
class GlobalLogger {
  static void init(String fileOutputDir, {required bool enableDebugLog}) {}
}
