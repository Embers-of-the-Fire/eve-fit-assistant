@TestOn("browser")
library;

import "package:eve_fit_assistant/storage/fs/hive_doc_store.dart";
import "package:flutter_test/flutter_test.dart";
import "package:hive_ce/hive_ce.dart";

void main() {
  late HiveDocStore store;
  late String boxName;

  setUpAll(() {
    Hive.init(null);
  });

  setUp(() async {
    boxName = "efa_doc_test_${DateTime.now().microsecondsSinceEpoch}";
    store = HiveDocStore(boxName);
    await store.init();
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(boxName);
  });

  test("write then read round-trips a document", () async {
    await store.write("settings.json", '{"a":1}');
    expect(await store.read("settings.json"), '{"a":1}');
  });

  test("read returns null for a missing key", () async {
    expect(await store.read("missing.json"), isNull);
  });

  test("exists reflects presence", () async {
    expect(await store.exists("k.json"), isFalse);
    await store.write("k.json", "v");
    expect(await store.exists("k.json"), isTrue);
  });

  test("delete removes a key", () async {
    await store.write("del.json", "v");
    await store.delete("del.json");
    expect(await store.exists("del.json"), isFalse);
  });

  test("keys lists all stored keys", () async {
    await store.write("a.json", "1");
    await store.write("b.json", "2");
    expect(await store.keys(), containsAll(["a.json", "b.json"]));
  });

  test("overwriting a key updates the value", () async {
    await store.write("o.json", "first");
    await store.write("o.json", "second");
    expect(await store.read("o.json"), "second");
  });
}
