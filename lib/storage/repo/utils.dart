/// Shared utilities for the repo storage module.
///
/// This file is safe for import by any module that needs repo-level helpers,
/// including migration action code and fit/character persistence.
library;

import "dart:convert";
import "dart:io";

import "package:protobuf/protobuf.dart";

/// Default concurrency for parallel blob downloads across all fetch pipelines.
const kBlobDownloadConcurrency = 32;

/// Writes [json] to [target] atomically via a temporary file + rename.
///
/// The payload is first serialized with [jsonEncode] and written to a `.tmp`
/// sibling file.  Once the write completes successfully the temp file is
/// atomically renamed over the original target.  If the write is interrupted
/// the original file is left untouched.
///
/// Throws on any I/O or encoding error.
Future<void> atomicWriteJson(File target, Map<String, dynamic> json) async {
  final tmp = File("${target.path}.tmp");
  await tmp.writeAsString(jsonEncode(json));
  await tmp.rename(target.path);
}

/// Synchronous variant of [atomicWriteJson].
void atomicWriteJsonSync(File target, Map<String, dynamic> json) {
  File("${target.path}.tmp")
    ..writeAsStringSync(jsonEncode(json), flush: true)
    ..renameSync(target.path);
}

/// Writes a protobuf message to [path] atomically (write-to-tmp-then-rename).
void writeProtobufSync(String path, GeneratedMessage message) {
  final file = File(path);
  if (!file.parent.existsSync()) {
    file.parent.createSync(recursive: true);
  }
  File("$path.tmp")
    ..writeAsBytesSync(message.writeToBuffer(), flush: true)
    ..renameSync(path);
}

/// Reads a protobuf message from [path] using [fromBuffer].
///
/// Returns `null` if the file does not exist or is unreadable.
T? readProtobufSync<T extends GeneratedMessage>(
  String path,
  T Function(List<int> bytes) fromBuffer,
) {
  final file = File(path);
  if (!file.existsSync()) return null;
  try {
    return fromBuffer(file.readAsBytesSync());
  } on Exception {
    return null;
  }
}

/// Formats [dt] as an ISO 8601 timestamp string (UTC, seconds precision).
String formatTimestamp(DateTime dt) {
  final y = dt.year.toString().padLeft(4, "0");
  final mo = dt.month.toString().padLeft(2, "0");
  final d = dt.day.toString().padLeft(2, "0");
  final h = dt.hour.toString().padLeft(2, "0");
  final mi = dt.minute.toString().padLeft(2, "0");
  final s = dt.second.toString().padLeft(2, "0");
  return "$y-$mo-${d}T$h:$mi:${s}Z";
}

/// Human-readable bandwidth (B/s, KiB/s, MiB/s).
String formatBytesPerSec(double bytesPerSec) {
  if (bytesPerSec < 1024) return "${bytesPerSec.toStringAsFixed(0)} B/s";
  if (bytesPerSec < 1024 * 1024) return "${(bytesPerSec / 1024).toStringAsFixed(1)} KiB/s";
  return "${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MiB/s";
}

/// Tracks aggregate byte progress across many concurrent blob downloads and
/// computes a sliding-window throughput rate.
///
/// Each worker reports cumulative per-response byte counts via [blobProgress]
/// and folds a blob's full size into the completed total via [blobComplete].
/// [bytesPerSecond] averages over the trailing [window] using wall-clock now
/// as the window end, so the reported rate decays towards zero during stalls
/// instead of sticking at a stale value.
class BlobTransferTracker {
  BlobTransferTracker({
    required this.totalBytes,
    int initialCompletedBytes = 0,
    this.window = const Duration(seconds: 5),
  }) : _completedBytes = initialCompletedBytes {
    _stopwatch.start();
  }

  /// Total bytes expected across all blobs (cached + downloaded).
  final int totalBytes;

  /// Sliding window used for the throughput estimate.
  final Duration window;

  int _completedBytes;
  final Map<int, int> _inflightBytes = {};
  final List<(int, int)> _samples = [];
  final Stopwatch _stopwatch = Stopwatch();
  int _lastSampleMs = -1;

  static const _minSampleIntervalMs = 100;

  /// Records received bytes for an in-flight blob. [receivedBytes] is the
  /// cumulative count for the current response; regressive values (e.g. after
  /// a retry restarts the response) are ignored.
  void blobProgress(int index, int receivedBytes) {
    final previous = _inflightBytes[index] ?? 0;
    if (receivedBytes <= previous) return;
    _inflightBytes[index] = receivedBytes;
    _sample();
  }

  /// Marks a blob as finished, folding its full [size] into the completed total.
  void blobComplete(int index, int size) {
    _inflightBytes.remove(index);
    _completedBytes += size;
    _sample(force: true);
  }

  /// Drops any in-flight bytes for a blob that failed or was aborted.
  void blobAborted(int index) {
    _inflightBytes.remove(index);
  }

  /// Bytes transferred so far, including partial in-flight blobs.
  int get transferredBytes => _completedBytes + _inflightBytes.values.fold(0, (sum, v) => sum + v);

  /// Byte-based completion fraction in [0, 1].
  double get progress => totalBytes > 0 ? (transferredBytes / totalBytes).clamp(0.0, 1.0) : 0;

  /// Throughput averaged over the trailing [window], in bytes per second.
  double get bytesPerSecond {
    if (_samples.isEmpty) return 0;
    final nowMs = _stopwatch.elapsedMilliseconds;
    final cutoff = nowMs - window.inMilliseconds;
    var anchorMs = _samples.first.$1;
    var anchorBytes = _samples.first.$2;
    for (final (t, b) in _samples) {
      if (t > cutoff) break;
      anchorMs = t;
      anchorBytes = b;
    }
    final dt = (nowMs - anchorMs) / 1000.0;
    if (dt <= 0) return 0;
    return (transferredBytes - anchorBytes) / dt;
  }

  void _sample({bool force = false}) {
    final nowMs = _stopwatch.elapsedMilliseconds;
    if (!force && _lastSampleMs >= 0 && nowMs - _lastSampleMs < _minSampleIntervalMs) {
      return;
    }
    _lastSampleMs = nowMs;
    _samples.add((nowMs, transferredBytes));
    final cutoff = nowMs - window.inMilliseconds;
    while (_samples.length > 2 && _samples[1].$1 <= cutoff) {
      _samples.removeAt(0);
    }
  }
}
