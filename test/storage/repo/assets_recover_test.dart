import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late Directory tempDir;

  setUpAll(() {
    GlobalLogger.init(
      Directory.systemTemp.createTempSync("efa_recover_log_").path,
      enableDebugLog: false,
    );
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync("efa_recover_test_");
    PathProvider.documentsPath = tempDir.path;
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test("recoverSync deletes orphaned .tmp files but keeps real blobs", () {
    final assets = Directory(RepoPaths.assetsPath)..createSync(recursive: true);
    final blobDir = Directory(p.join(assets.path, "blobs", "ab", "abc"))
      ..createSync(recursive: true);
    final realBlob = File(p.join(blobDir.path, "content"))..writeAsStringSync("data");
    final orphanedTmp = File(p.join(blobDir.path, "content.tmp"))..writeAsStringSync("partial");

    const AssetStore().recoverSync();

    expect(realBlob.existsSync(), isTrue);
    expect(orphanedTmp.existsSync(), isFalse);
  });

  test("recoverSync removes tmp_* and *_temp working directories", () {
    final assets = Directory(RepoPaths.assetsPath)..createSync(recursive: true);
    final tmpDir = Directory(p.join(assets.path, "tmp_resource_snapshot"))
      ..createSync(recursive: true);
    File(p.join(tmpDir.path, "x")).writeAsStringSync("y");
    final tempSuffixDir = Directory(p.join(assets.path, "foo_temp"))..createSync(recursive: true);

    const AssetStore().recoverSync();

    expect(tmpDir.existsSync(), isFalse);
    expect(tempSuffixDir.existsSync(), isFalse);
  });

  test("recoverSync is a no-op when the assets directory is absent", () {
    expect(Directory(RepoPaths.assetsPath).existsSync(), isFalse);
    expect(const AssetStore().recoverSync, returnsNormally);
  });
}
