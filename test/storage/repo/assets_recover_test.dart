@TestOn("vm")
library;

import "dart:io";
import "dart:typed_data";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/fs/memory_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/assets.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

void main() {
  late MemoryBlobStore store;

  setUpAll(() {
    GlobalLogger.init(
      Directory.systemTemp.createTempSync("efa_recover_log_").path,
      enableDebugLog: false,
    );
  });

  setUp(() {
    store = MemoryBlobStore();
    PathProvider.documentsPath = "/";
    PathProvider.appSupportPath = "/";
  });

  test("recover deletes orphaned .tmp files but keeps real blobs", () async {
    final blobDir = p.join(RepoPaths.blobsDirPath, "ab", "abc");
    await store.write(p.join(blobDir, "content"), Uint8List.fromList([1, 2, 3]));
    await store.write(p.join(blobDir, "content.tmp"), Uint8List.fromList([4, 5]));

    await AssetStore.forTest(store).recover();

    expect(await store.exists(p.join(blobDir, "content")), isTrue);
    expect(await store.exists(p.join(blobDir, "content.tmp")), isFalse);
  });

  test("recover is a no-op when the assets directory is absent", () async {
    await expectLater(AssetStore.forTest(store).recover(), completes);
  });
}
