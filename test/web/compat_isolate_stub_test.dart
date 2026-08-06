@TestOn("browser")
library;

import "package:eve_fit_assistant/compat/isolate.dart";
import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("web Isolate stub", () {
    test("Isolate.run executes inline and returns the value", () async {
      final result = await Isolate.run(() => 42);
      expect(result, 42);
    });

    test("Isolate.run accepts a debug name", () async {
      final result = await Isolate.run(() => "ok", debugName: "web-test");
      expect(result, "ok");
    });

    test("Isolate.run propagates errors", () {
      expect(() => Isolate.run(() => throw StateError("boom")), throwsA(isA<StateError>()));
    });
  });

  group("web ReceivePort/SendPort stubs", () {
    test("ports are inert: send and close do not throw", () {
      final port = ReceivePort();
      expect(() => port.sendPort.send("message"), returnsNormally);
      expect(port.close, returnsNormally);
    });

    test("port stream never emits; close terminates listeners", () async {
      final port = ReceivePort();
      port.sendPort.send("ignored");
      final done = expectLater(port, emitsDone);
      port.close();
      await done;
    });

    test("send and close log in debug mode so message-dropping is visible", () {
      // kDebugMode is always true under flutter test.
      final messages = <String>[];
      final previous = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) messages.add(message);
      };
      addTearDown(() => debugPrint = previous);

      final port = ReceivePort();
      port.sendPort.send("message");
      port.close();

      expect(messages, hasLength(2));
    });
  });
}
