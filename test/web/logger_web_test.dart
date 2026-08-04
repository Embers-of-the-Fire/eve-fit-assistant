@TestOn("browser")
library;

import "dart:js_interop";
import "dart:js_interop_unsafe";

import "package:eve_fit_assistant/config/logger.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("web console logger", () {
    const methods = ["debug", "info", "warn", "error"];
    final console = globalContext.getProperty("console".toJS)! as JSObject;

    late Map<String, JSAny?> originals;
    late Map<String, List<String>> calls;

    setUp(() {
      originals = {};
      calls = {};
      for (final method in methods) {
        final key = method.toJS;
        originals[method] = console.getProperty(key);
        final recorded = <String>[];
        calls[method] = recorded;
        console.setProperty(key, ((JSString message) => recorded.add(message.toDart)).toJS);
      }
    });

    tearDown(() {
      for (final method in methods) {
        console.setProperty(method.toJS, originals[method]);
      }
    });

    test("emits a multi-line message as a single console entry", () {
      info("line one\nline two\nline three");

      expect(calls["info"], ["[INFO] line one\nline two\nline three"]);
    });

    test("routes levels to the matching console method", () {
      debug("d");
      info("i");
      warning("w");
      error("e");
      fatal("f");

      expect(calls["debug"], ["[DEBUG] d"]);
      expect(calls["info"], ["[INFO] i"]);
      expect(calls["warn"], ["[WARN] w"]);
      expect(calls["error"], ["[ERROR] e", "[ERROR] f"]);
    });

    test("appends the error and stack trace to the same console entry", () {
      error("boom", error: StateError("bad"), stackTrace: StackTrace.fromString("#0 foo\n#1 bar"));

      expect(calls["error"], ["[ERROR] boom | Bad state: bad\n#0 foo\n#1 bar"]);
    });
  });
}
