import 'package:logger/logger.dart';

void debug(dynamic message) {
  GlobalLogger._console.d(message);
  GlobalLogger._file.d(message);
}

void info(dynamic message) {
  GlobalLogger._console.i(message);
  GlobalLogger._file.i(message);
}

void warning(dynamic message) {
  GlobalLogger._console.w(message);
  GlobalLogger._file.w(message);
}

void error(dynamic message) {
  GlobalLogger._console.e(message);
  GlobalLogger._file.e(message);
}

void fatal(dynamic message) {
  GlobalLogger._console.f(message);
  GlobalLogger._file.f(message);
}

class GlobalLogger {
  static late final Logger _console;
  static late final Logger _file;

  static void init(String fileOutputDir) {
    _console = Logger(
      printer: PrefixPrinter(PrettyPrinter()),
      filter: DevelopmentFilter()..level = Level.debug,
      output: ConsoleOutput(),
    );
    _file = Logger(
      printer: SimplePrinter(printTime: true, colors: false),
      filter: ProductionFilter()..level = Level.info,
      output: AdvancedFileOutput(path: fileOutputDir),
    );
  }
}
