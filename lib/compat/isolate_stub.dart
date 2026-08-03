/// Web stub for `dart:isolate`.
///
/// Web has no isolates, so [Isolate.run] executes the computation inline on
/// the main event loop. [ReceivePort]/[SendPort] are inert stubs: sending is
/// a no-op and ports never emit events.
// ignore_for_file: avoid_annotating_with_dynamic
library;

import "dart:async";

/// Stub for `dart:isolate` `Isolate`.
abstract final class Isolate {
  /// Runs [computation] inline (web has no background isolates).
  static Future<R> run<R>(FutureOr<R> Function() computation, {String? debugName}) =>
      Future<R>.sync(computation);
}

/// Stub for `dart:isolate` `SendPort`. Sending is a no-op.
class SendPort {
  const SendPort._();

  void send(Object? message) {}
}

/// Stub for `dart:isolate` `ReceivePort`. Never emits events.
class ReceivePort extends Stream<dynamic> {
  ReceivePort();

  final SendPort sendPort = const SendPort._();

  void close() {}

  @override
  StreamSubscription<dynamic> listen(
    void Function(dynamic event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => const Stream<dynamic>.empty().listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}
