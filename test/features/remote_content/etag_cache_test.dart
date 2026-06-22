import "dart:convert";
import "dart:io";

import "package:eve_fit_assistant/config/logger.dart";
import "package:eve_fit_assistant/config/paths.dart";
import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;

File _cacheFile() => File(p.join(PathProvider.settingsPath, "etag_cache.json"));

void main() {
  late Directory tempDir;

  setUpAll(() {
    GlobalLogger.init(
      Directory.systemTemp.createTempSync("efa_etag_log_").path,
      enableDebugLog: false,
    );
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync("efa_etag_test_");
    PathProvider.documentsPath = tempDir.path;
    EtagCache.init();
    // Reset static in-memory state for isolation between tests.
    EtagCache.clearAll();
    await EtagCache.flush();
    final f = _cacheFile();
    if (f.existsSync()) f.deleteSync();
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test("update is reflected by getEtag/getLastModified", () {
    final uri = Uri.parse("https://example.com/a");
    EtagCache.update(uri, etag: '"e1"', lastModified: "lm1");
    expect(EtagCache.getEtag(uri), '"e1"');
    expect(EtagCache.getLastModified(uri), "lm1");
  });

  test("flush writes valid JSON atomically with no orphaned temp file", () async {
    final uri = Uri.parse("https://example.com/a");
    EtagCache.update(uri, etag: '"e1"', lastModified: "lm1");
    await EtagCache.flush();

    final f = _cacheFile();
    expect(f.existsSync(), isTrue);
    expect(File("${f.path}.tmp").existsSync(), isFalse, reason: "temp must be renamed away");

    final decoded = jsonDecode(f.readAsStringSync());
    expect(decoded, isA<Map<String, dynamic>>());
    final entry = (decoded as Map<String, dynamic>)[uri.toString()] as Map<String, dynamic>;
    expect(entry["etag"], '"e1"');
    expect(entry["lastModified"], "lm1");
  });

  test("debounce coalesces rapid writes into a single deferred flush", () async {
    final f = _cacheFile();
    expect(f.existsSync(), isFalse);

    for (var i = 0; i < 100; i++) {
      EtagCache.update(Uri.parse("https://example.com/$i"), etag: '"e$i"');
    }

    // The debounce timer cannot fire while this synchronous loop holds the
    // event loop, so no intermediate writes have hit disk yet.
    expect(f.existsSync(), isFalse, reason: "rapid updates must not each write");

    await EtagCache.flush();
    expect(f.existsSync(), isTrue);
    final decoded = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    expect(decoded.length, 100);
  });

  test("clearAll empties memory and the persisted file", () async {
    final uri = Uri.parse("https://example.com/a");
    EtagCache.update(uri, etag: '"e1"');
    await EtagCache.flush();

    EtagCache.clearAll();
    expect(EtagCache.getEtag(uri), isNull);

    await EtagCache.flush();
    final decoded = jsonDecode(_cacheFile().readAsStringSync()) as Map<String, dynamic>;
    expect(decoded, isEmpty);
  });

  test("persisted entries are readable back from disk (restart survival)", () async {
    final uri = Uri.parse("https://example.com/a");
    EtagCache.update(uri, etag: '"persisted"');
    await EtagCache.flush();

    // Simulate a restart by reading the file directly, as init() would.
    final decoded = jsonDecode(_cacheFile().readAsStringSync()) as Map<String, dynamic>;
    expect((decoded[uri.toString()] as Map<String, dynamic>)["etag"], '"persisted"');
  });
}
