@TestOn("browser")
library;

import "package:efa_compat/io.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("web Platform stub", () {
    test("reports web as the operating system", () {
      expect(Platform.operatingSystem, "web");
      expect(Platform.operatingSystemVersion, isEmpty);
    });

    test("reports no native platform", () {
      expect(Platform.isAndroid, isFalse);
      expect(Platform.isIOS, isFalse);
      expect(Platform.isLinux, isFalse);
      expect(Platform.isMacOS, isFalse);
      expect(Platform.isWindows, isFalse);
      expect(Platform.isFuchsia, isFalse);
    });

    test("exposes an empty environment and posix separator", () {
      expect(Platform.environment, isEmpty);
      expect(Platform.pathSeparator, "/");
    });
  });

  group("web filesystem stubs", () {
    test("File constructor throws UnsupportedError", () {
      expect(() => File("some/path.json"), throwsUnsupportedError);
    });

    test("Directory constructor throws UnsupportedError", () {
      expect(() => Directory("some/dir"), throwsUnsupportedError);
    });

    test("Link constructor throws UnsupportedError", () {
      expect(() => Link("some/link"), throwsUnsupportedError);
    });

    test("FileSystemEntity static lookups throw UnsupportedError", () {
      expect(() => FileSystemEntity.typeSync("x"), throwsUnsupportedError);
      expect(() => FileSystemEntity.isFileSync("x"), throwsUnsupportedError);
      expect(() => FileSystemEntity.isDirectorySync("x"), throwsUnsupportedError);
    });

    test("FileStat lookups throw UnsupportedError", () {
      expect(() => FileStat.statSync("x"), throwsUnsupportedError);
      expect(() => FileStat.stat("x"), throwsUnsupportedError);
    });

    test("gzip codec throws UnsupportedError when used", () {
      expect(() => gzip.encode(const [1, 2, 3]), throwsUnsupportedError);
      expect(() => gzip.decode(const [1, 2, 3]), throwsUnsupportedError);
    });

    test("FileSystemException stays constructible for catch clauses", () {
      const e = FileSystemException("boom", "some/path");
      expect(e.message, "boom");
      expect(e.path, "some/path");
    });
  });
}
