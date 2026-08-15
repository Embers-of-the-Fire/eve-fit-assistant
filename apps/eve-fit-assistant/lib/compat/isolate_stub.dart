/// Web stub for `dart:isolate`.
///
/// Web has no isolates, so [Isolate.run] executes the computation inline on
/// the main event loop. [ReceivePort]/[SendPort] are inert stubs: sending is
/// a no-op and ports never emit events, but closing a port terminates its
/// listeners so `onDone`/`await port.first` behave like a drained port. In
/// debug builds `send`/`close` log via [debugPrint] so silent message-dropping
/// does not go unnoticed.
// ignore_for_file: avoid_annotating_with_dynamic
library;

import "dart:async";

import "package:flutter/foundation.dart";

/// Stub for `dart:isolate` `Isolate`.
abstract final class Isolate {
  /// Runs [computation] inline (web has no background isolates).
  static Future<R> run<R>(FutureOr<R> Function() computation, {String? debugName}) =>
      Future<R>.sync(computation);
}

/// Stub for `dart:isolate` `SendPort`. Sending is a no-op; in debug builds it
/// logs so silent message-dropping is visible while developing.
class SendPort {
  const SendPort._();

  void send(Object? message) {
    if (kDebugMode) {
      debugPrint(
        "web SendPort stub dropped a message (${message.runtimeType}); web ports are inert, "
        "so any listener expecting this message will never fire",
      );
    }
  }
}

/// Stub for `dart:isolate` `ReceivePort`. Never emits events; [close]
/// terminates listeners. In debug builds [close] logs for the same reason as
/// [SendPort.send].
class ReceivePort extends Stream<dynamic> {
  ReceivePort();

  final SendPort sendPort = const SendPort._();
  final StreamController<dynamic> _controller = StreamController<dynamic>();

  void close() {
    if (kDebugMode) {
      debugPrint("web ReceivePort stub closed; no message was ever delivered through it");
    }
    unawaited(_controller.close());
  }

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _controller.stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}
