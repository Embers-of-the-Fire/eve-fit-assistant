@TestOn("vm")
library;

import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:file/memory.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late MemoryFileSystem fs;

  setUpAll(() {
    GlobalLogger.init(
      Directory.systemTemp.createTempSync("efa_recover_log_").path,
      enableDebugLog: false,
    );
  });

  setUp(() {
    fs = MemoryFileSystem();
    PathProvider.documentsPath = "/";
    PathProvider.appSupportPath = "/";
  });

  test("recoverSync deletes orphaned .tmp files but keeps real blobs", () {
    final assets = fs.directory(RepoPaths.assetsPath)..createSync(recursive: true);
    final blobDir = fs.directory(p.join(assets.path, "blobs", "ab", "abc"))
      ..createSync(recursive: true);
    final realBlob = fs.file(p.join(blobDir.path, "content"))..writeAsStringSync("data");
    final orphanedTmp = fs.file(p.join(blobDir.path, "content.tmp"))..writeAsStringSync("partial");

    AssetStore.forTest(fs).recoverSync();

    expect(realBlob.existsSync(), isTrue);
    expect(orphanedTmp.existsSync(), isFalse);
  });

  test("recoverSync removes tmp_* and *_temp working directories", () {
    final assets = fs.directory(RepoPaths.assetsPath)..createSync(recursive: true);
    final tmpDir = fs.directory(p.join(assets.path, "tmp_resource_snapshot"))
      ..createSync(recursive: true);
    fs.file(p.join(tmpDir.path, "x")).writeAsStringSync("y");
    final tempSuffixDir = fs.directory(p.join(assets.path, "foo_temp"))
      ..createSync(recursive: true);

    AssetStore.forTest(fs).recoverSync();

    expect(tmpDir.existsSync(), isFalse);
    expect(tempSuffixDir.existsSync(), isFalse);
  });

  test("recoverSync is a no-op when the assets directory is absent", () {
    expect(AssetStore.forTest(fs).recoverSync, returnsNormally);
  });
}
