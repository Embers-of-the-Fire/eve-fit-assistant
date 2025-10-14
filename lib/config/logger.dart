import 'package:logger/logger.dart';

void debug(dynamic message, {StackTrace? stackTrace}) {
  GlobalLogger._console.d(message, stackTrace: stackTrace);
  GlobalLogger._file.d(message, stackTrace: stackTrace);
}

void info(dynamic message, {StackTrace? stackTrace}) {
  GlobalLogger._console.i(message, stackTrace: stackTrace);
  GlobalLogger._file.i(message, stackTrace: stackTrace);
}

void warning(dynamic message, {StackTrace? stackTrace}) {
  GlobalLogger._console.w(message, stackTrace: stackTrace);
  GlobalLogger._file.w(message, stackTrace: stackTrace);
}

void error(dynamic message, {StackTrace? stackTrace}) {
  GlobalLogger._console.e(message, stackTrace: stackTrace);
  GlobalLogger._file.e(message, stackTrace: stackTrace);
}

void fatal(dynamic message, {StackTrace? stackTrace}) {
  GlobalLogger._console.f(message, stackTrace: stackTrace);
  GlobalLogger._file.f(message, stackTrace: stackTrace);
}

class GlobalLogger {
  static late final Logger _console;
  static late final Logger _file;

  static void init(String fileOutputDir, bool enableDebugLog) {
    _console = Logger(
      printer: PrefixPrinter(PrettyPrinter()),
      filter: DevelopmentFilter()..level = Level.debug,
      output: ConsoleOutput(),
    );
    _file = Logger(
      printer: SimplePrinter(printTime: true, colors: false),
      filter: ProductionFilter()..level = enableDebugLog ? Level.debug : Level.info,
      output: AdvancedFileOutput(path: fileOutputDir),
    );
  }
}
