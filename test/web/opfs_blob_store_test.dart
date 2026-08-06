@TestOn("browser")
library;

import "dart:typed_data";

import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/storage/fs/opfs_blob_store.dart";
import "package:eve_fit_assistant/storage/repo/paths.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  late OpfsBlobStore store;
  // Unique per run so repeated runs do not collide with stale OPFS entries.
  late String base;

  setUpAll(() async {
    await PathProvider.init();
  });

  setUp(() async {
    store = OpfsBlobStore.forTest();
    await store.init();
    base = "${RepoPaths.schemaResourcesPath}/opfs_test/${DateTime.now().microsecondsSinceEpoch}";
  });

  tearDown(() async {
    // Clean up the per-test tree so reruns do not accumulate in OPFS.
    await store.deleteTree(base);
  });

  test("write then read round-trips bytes", () async {
    final path = "$base/blob_a";
    final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

    await store.write(path, bytes);
    final read = await store.read(path);

    expect(read, bytes);
  });

  test("read returns null for a missing path", () async {
    expect(await store.read("$base/does_not_exist"), isNull);
  });

  test("exists reflects presence", () async {
    final path = "$base/blob_b";
    expect(await store.exists(path), isFalse);

    await store.write(path, Uint8List.fromList([9]));
    expect(await store.exists(path), isTrue);
  });

  test("delete removes a blob", () async {
    final path = "$base/blob_c";
    await store.write(path, Uint8List.fromList([7]));
    expect(await store.exists(path), isTrue);

    await store.delete(path);
    expect(await store.exists(path), isFalse);
  });

  test("delete on a missing path is a no-op", () async {
    await expectLater(store.delete("$base/never_written"), completes);
  });

  test("write creates nested directories", () async {
    final path = "$base/deep/nested/dir/blob_d";
    await store.write(path, Uint8List.fromList([42]));
    expect(await store.read(path), Uint8List.fromList([42]));
  });

  test("list returns files under a prefix", () async {
    await store.write("$base/list/x", Uint8List.fromList([1]));
    await store.write("$base/list/y", Uint8List.fromList([2]));
    await store.write("$base/list/sub/z", Uint8List.fromList([3]));

    final listed = await store.list("$base/list");
    expect(listed, containsAll(["$base/list/x", "$base/list/y", "$base/list/sub/z"]));
  });

  test("list returns empty for a missing prefix", () async {
    expect(await store.list("$base/no_such_dir"), isEmpty);
  });

  test("deleteTree removes a subtree", () async {
    await store.write("$base/tree/a", Uint8List.fromList([1]));
    await store.write("$base/tree/b/c", Uint8List.fromList([2]));

    await store.deleteTree("$base/tree");

    expect(await store.exists("$base/tree/a"), isFalse);
    expect(await store.exists("$base/tree/b/c"), isFalse);
  });

  test("write rejects the OPFS root", () async {
    await expectLater(store.write("", Uint8List.fromList([1])), throwsArgumentError);
    await expectLater(
      store.write(RepoPaths.schemaResourcesPath, Uint8List.fromList([1])),
      throwsArgumentError,
    );
  });

  test("deleteTree rejects the OPFS root", () async {
    await expectLater(store.deleteTree(""), throwsArgumentError);
    await expectLater(store.deleteTree(RepoPaths.schemaResourcesPath), throwsArgumentError);
  });

  test("write under a path occupied by a file fails and leaves the file intact", () async {
    final path = "$base/conflict";
    final bytes = Uint8List.fromList([5, 6, 7]);
    await store.write(path, bytes);

    await expectLater(store.write("$path/child", bytes), throwsA(anything));
    expect(await store.read(path), bytes);
  });

  test("paths without the resources/v2 prefix resolve to the same OPFS location", () async {
    final prefixed = "$base/prefix_blob";
    final bytes = Uint8List.fromList([11, 12]);
    await store.write(prefixed, bytes);

    final unprefixed = prefixed.substring(RepoPaths.schemaResourcesPath.length);
    expect(await store.read(unprefixed), bytes);
    expect(await store.exists(unprefixed), isTrue);
  });
}
