import "package:eve_fit_assistant/features/remote_content/etag_cache.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  // This file's isolate never calls EtagCache.init(), so any access must throw
  // a clear StateError instead of a LateInitializationError.
  test("accessing EtagCache before init throws StateError", () {
    final uri = Uri.parse("https://example.com/a");
    expect(() => EtagCache.getEtag(uri), throwsStateError);
    expect(() => EtagCache.getLastModified(uri), throwsStateError);
    expect(() => EtagCache.update(uri, etag: '"e"'), throwsStateError);
    expect(() => EtagCache.remove(uri), throwsStateError);
    expect(EtagCache.clearAll, throwsStateError);
  });
}
