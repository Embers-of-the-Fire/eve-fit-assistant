import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:eve_fit_assistant/storage/repo/schema_version.dart";
import "package:flutter_test/flutter_test.dart";
import "package:fpdart/fpdart.dart";

void main() {
  late String tempDir;
  late SchemaVersionService service;

  setUpAll(() {
    final logDir = Directory.systemTemp.createTempSync("efa_schema_version_test_log_");
    GlobalLogger.init(logDir.path, enableDebugLog: false);
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_schema_version_test_").path;
    PathProvider.documentsPath = tempDir;
    service = const SchemaVersionService();
  });

  tearDown(() {
    final dir = Directory(tempDir);
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  group("SchemaVersionService.ensure", () {
    test("writes file on first call", () {
      service.ensure();

      final file = File(RepoPaths.schemaVersionPath);
      expect(file.existsSync(), isTrue);

      final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      expect(json["schemaVersion"], 2);
    });

    test("is idempotent on second call", () {
      service.ensure();

      // Set a sentinel mtime so a rewrite is detectable even within the same
      // filesystem timestamp tick.
      final file = File(RepoPaths.schemaVersionPath);
      final sentinel = DateTime(2020, 1, 1);
      file.setLastModifiedSync(sentinel);

      service.ensure();
      expect(file.lastModifiedSync(), sentinel);
    });
  });

  group("SchemaVersionService.read", () {
    test("returns Some(1) after ensure", () {
      service.ensure();

      expect(service.read(), const Some(2));
    });

    test("returns None when file is absent", () {
      expect(service.read(), const None());
    });

    test("returns None on malformed JSON", () {
      final file = File(RepoPaths.schemaVersionPath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync("not json");

      expect(service.read(), const None());
    });

    test("returns None when schemaVersion field is missing", () {
      final file = File(RepoPaths.schemaVersionPath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode({"other": 1}));

      expect(service.read(), const None());
    });
  });

  group("SchemaVersionService atomic write", () {
    test("after ensure, no .tmp file remains", () {
      service.ensure();

      final tmpFile = File("${RepoPaths.schemaVersionPath}.tmp");
      expect(tmpFile.existsSync(), isFalse);
    });
  });

  group("SchemaVersionService.exists", () {
    test("returns false when file is absent", () {
      expect(service.exists(), isFalse);
    });

    test("returns true after ensure", () {
      service.ensure();
      expect(service.exists(), isTrue);
    });

    test("returns true when file exists with valid content", () {
      final file = File(RepoPaths.schemaVersionPath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(jsonEncode({"schemaVersion": 2}));

      expect(service.exists(), isTrue);
    });

    test("returns true when file exists even with malformed content", () {
      final file = File(RepoPaths.schemaVersionPath);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync("garbage");

      expect(service.exists(), isTrue);
    });
  });
}
