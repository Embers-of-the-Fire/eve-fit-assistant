/// Web stub for `dart:io`.
///
/// Every API here mirrors the corresponding `dart:io` declaration closely
/// enough for the app to compile for web, but all filesystem/process
/// operations throw [UnsupportedError] when invoked. [Platform] reports
/// sensible web values instead of throwing, so platform detection code
/// degrades gracefully.
///
/// The declarations intentionally mirror the shape of the real `dart:io`
/// API, which does not follow this project's style lints.
// ignore_for_file: use_enums, sort_constructors_first, avoid_unused_constructor_parameters
library;

import "dart:async";
import "dart:convert";
import "dart:typed_data";

Never _unsupported(String member) =>
    throw UnsupportedError("dart:io '$member' is not available on the web platform.");

/// Stub for `dart:io` `Platform`. All `isX` getters are `false` and
/// [operatingSystem] reports `"web"`.
abstract final class Platform {
  static const bool isAndroid = false;
  static const bool isIOS = false;
  static const bool isLinux = false;
  static const bool isMacOS = false;
  static const bool isWindows = false;
  static const bool isFuchsia = false;

  static String get operatingSystem => "web";
  static String get operatingSystemVersion => "";
  static String get version => "";

  /// Throws: web locale must come from `ui.PlatformDispatcher.instance.locale`,
  /// not from `Platform.localeName`.
  static String get localeName => _unsupported("Platform.localeName");
  static Map<String, String> get environment => const {};
  static String get pathSeparator => "/";
  static int get numberOfProcessors => 1;
  static String get executable => "";
  static String get resolvedExecutable => "";
  static Uri get script => Uri();
}

/// Stub for `dart:io` `FileMode`.
class FileMode {
  final int _mode;
  const FileMode._(this._mode);

  static const read = FileMode._(0);
  static const write = FileMode._(1);
  static const append = FileMode._(2);
  static const writeOnly = FileMode._(3);
  static const writeOnlyAppend = FileMode._(4);

  @override
  String toString() => "FileMode($_mode)";
}

/// Stub for `dart:io` `FileSystemEntityType`.
class FileSystemEntityType {
  final int _type;
  const FileSystemEntityType._(this._type);

  static const file = FileSystemEntityType._(1);
  static const directory = FileSystemEntityType._(2);
  static const link = FileSystemEntityType._(3);
  static const pipe = FileSystemEntityType._(4);
  static const unixDomainSock = FileSystemEntityType._(5);
  static const notFound = FileSystemEntityType._(0);

  @override
  String toString() => "FileSystemEntityType($_type)";
}

/// Stub for `dart:io` `FileStat`.
class FileStat {
  DateTime get changed => _unsupported("FileStat.changed");
  DateTime get modified => _unsupported("FileStat.modified");
  DateTime get accessed => _unsupported("FileStat.accessed");
  FileSystemEntityType get type => _unsupported("FileStat.type");
  int get mode => _unsupported("FileStat.mode");
  int get size => _unsupported("FileStat.size");

  static FileStat statSync(String path) => _unsupported("FileStat.statSync");
  static Future<FileStat> stat(String path) => _unsupported("FileStat.stat");
}

/// Stub for `dart:io` `IOException`.
class IOException implements Exception {
  const IOException([this.message = ""]);

  final String message;

  @override
  String toString() => "IOException: $message";
}

/// Stub for `dart:io` `OSError`.
class OSError implements Exception {
  const OSError([this.message = "", this.errorCode = 0]);

  final String message;
  final int errorCode;

  @override
  String toString() => "OS Error: $message, errno = $errorCode";
}

/// Stub for `dart:io` `FileSystemException`.
class FileSystemException implements IOException {
  const FileSystemException([this.message = "", this.path, this.osError]);

  @override
  final String message;
  final String? path;
  final OSError? osError;

  @override
  String toString() => "FileSystemException: $message${path == null ? "" : ", path = $path"}";
}

/// Stub for `dart:io` `FileSystemEntity`.
abstract class FileSystemEntity {
  String get path;
  Uri get uri;
  FileSystemEntity get absolute;
  Directory get parent;

  Future<bool> exists() => _unsupported("FileSystemEntity.exists");
  bool existsSync() => _unsupported("FileSystemEntity.existsSync");
  Future<FileStat> stat() => _unsupported("FileSystemEntity.stat");
  FileStat statSync() => _unsupported("FileSystemEntity.statSync");
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      _unsupported("FileSystemEntity.delete");
  void deleteSync({bool recursive = false}) => _unsupported("FileSystemEntity.deleteSync");
  Future<FileSystemEntity> rename(String newPath) => _unsupported("FileSystemEntity.rename");
  FileSystemEntity renameSync(String newPath) => _unsupported("FileSystemEntity.renameSync");

  static Future<FileSystemEntityType> type(String path, {bool followLinks = true}) =>
      _unsupported("FileSystemEntity.type");
  static FileSystemEntityType typeSync(String path, {bool followLinks = true}) =>
      _unsupported("FileSystemEntity.typeSync");
  static Future<bool> isFile(String path) => _unsupported("FileSystemEntity.isFile");
  static bool isFileSync(String path) => _unsupported("FileSystemEntity.isFileSync");
  static Future<bool> isDirectory(String path) => _unsupported("FileSystemEntity.isDirectory");
  static bool isDirectorySync(String path) => _unsupported("FileSystemEntity.isDirectorySync");
  static Future<bool> isLink(String path) => _unsupported("FileSystemEntity.isLink");
  static bool isLinkSync(String path) => _unsupported("FileSystemEntity.isLinkSync");
  static Future<bool> identical(String path1, String path2) =>
      _unsupported("FileSystemEntity.identical");
  static bool identicalSync(String path1, String path2) =>
      _unsupported("FileSystemEntity.identicalSync");
}

/// Stub for `dart:io` `File`.
abstract class File implements FileSystemEntity {
  factory File(String path) => _unsupported("File");

  @override
  Future<File> delete({bool recursive = false});
  @override
  Future<File> rename(String newPath);
  @override
  File renameSync(String newPath);

  Future<File> create({bool recursive = false});
  void createSync({bool recursive = false});
  Future<File> copy(String newPath);
  File copySync(String newPath);
  Future<int> length();
  int lengthSync();
  Future<DateTime> lastAccessed();
  DateTime lastAccessedSync();
  Future<DateTime> lastModified();
  DateTime lastModifiedSync();
  Future<RandomAccessFile> open({FileMode mode = FileMode.read});
  RandomAccessFile openSync({FileMode mode = FileMode.read});
  Stream<List<int>> openRead([int? start, int? end]);
  IOSink openWrite({FileMode mode = FileMode.write, Encoding encoding = utf8});
  Future<Uint8List> readAsBytes();
  Uint8List readAsBytesSync();
  Future<List<String>> readAsLines({Encoding encoding = utf8});
  List<String> readAsLinesSync({Encoding encoding = utf8});
  Future<String> readAsString({Encoding encoding = utf8});
  String readAsStringSync({Encoding encoding = utf8});
  Future<File> writeAsBytes(List<int> bytes, {FileMode mode = FileMode.write, bool flush = false});
  void writeAsBytesSync(List<int> bytes, {FileMode mode = FileMode.write, bool flush = false});
  Future<File> writeAsString(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  });
  void writeAsStringSync(
    String contents, {
    FileMode mode = FileMode.write,
    Encoding encoding = utf8,
    bool flush = false,
  });
}

/// Stub for `dart:io` `Directory`.
abstract class Directory implements FileSystemEntity {
  factory Directory(String path) => _unsupported("Directory");

  @override
  Future<Directory> delete({bool recursive = false});
  @override
  Future<Directory> rename(String newPath);
  @override
  Directory renameSync(String newPath);

  Future<Directory> create({bool recursive = false});
  void createSync({bool recursive = false});
  Future<Directory> createTemp([String? prefix]);
  Directory createTempSync([String? prefix]);
  Stream<FileSystemEntity> list({bool recursive = false, bool followLinks = true});
  List<FileSystemEntity> listSync({bool recursive = false, bool followLinks = true});

  static Directory get current => _unsupported("Directory.current");
  static Directory get systemTemp => _unsupported("Directory.systemTemp");
}

/// Stub for `dart:io` `Link`.
abstract class Link implements FileSystemEntity {
  factory Link(String path) => _unsupported("Link");

  @override
  Future<Link> delete({bool recursive = false});
  @override
  Future<Link> rename(String newPath);
  @override
  Link renameSync(String newPath);

  Future<Link> create(String target, {bool recursive = false});
  void createSync(String target, {bool recursive = false});
  Future<String> target();
  String targetSync();
  Future<Link> update(String target, {bool recursive = false});
  void updateSync(String target, {bool recursive = false});
}

/// Stub for `dart:io` `IOSink`.
abstract class IOSink implements StreamSink<List<int>>, StringSink {
  Encoding get encoding;
  set encoding(Encoding encoding);
}

/// Stub for `dart:io` `RandomAccessFile`.
abstract class RandomAccessFile {
  String get path;
  Future<int> position();
  int positionSync();
  Future<int> length();
  int lengthSync();
  Future<Uint8List> read(int count);
  Uint8List readSync(int count);
  Future<void> close();
  void closeSync();
}

/// Stub for `dart:io` `GZipCodec`. Members throw when used.
class GZipCodec extends Codec<List<int>, List<int>> {
  const GZipCodec({this.level = 6, this.windowBits = 15, this.memLevel = 8, this.raw = false});

  final int level;
  final int windowBits;
  final int memLevel;
  final bool raw;

  @override
  Converter<List<int>, List<int>> get encoder => _unsupported("gzip.encoder");
  @override
  Converter<List<int>, List<int>> get decoder => _unsupported("gzip.decoder");
  @override
  List<int> encode(List<int> input) => _unsupported("gzip.encode");
  @override
  List<int> decode(List<int> encoded) => _unsupported("gzip.decode");
}

/// Stub for `dart:io` `gzip`.
const GZipCodec gzip = GZipCodec();

/// Stub for `dart:io` `ZLibCodec`. Members throw when used.
class ZLibCodec extends Codec<List<int>, List<int>> {
  const ZLibCodec({this.level = 6, this.windowBits = 15, this.memLevel = 8, this.raw = false});

  final int level;
  final int windowBits;
  final int memLevel;
  final bool raw;

  @override
  Converter<List<int>, List<int>> get encoder => _unsupported("zlib.encoder");
  @override
  Converter<List<int>, List<int>> get decoder => _unsupported("zlib.decoder");
  @override
  List<int> encode(List<int> input) => _unsupported("zlib.encode");
  @override
  List<int> decode(List<int> encoded) => _unsupported("zlib.decode");
}

/// Stub for `dart:io` `zlib`.
const ZLibCodec zlib = ZLibCodec();
