import "package:fast_immutable_collections/fast_immutable_collections.dart";

sealed class MultiProvisionerState {
  const MultiProvisionerState();
}

class MultiProvisionerFetching extends MultiProvisionerState {
  const MultiProvisionerFetching({this.done = 0, this.total = 0});

  final int done;
  final int total;

  double get progress => total > 0 ? done / total : 0;
}

class MultiProvisionerDownloading extends MultiProvisionerState {
  const MultiProvisionerDownloading({
    required this.downloaded,
    required this.total,
    this.downloadedBytes = 0,
    this.totalBytes = 0,
    this.elapsedSeconds = 0,
    this.filesPerSecond = 0,
    this.bytesPerSecond = 0,
  });

  final int downloaded;
  final int total;
  final int downloadedBytes;
  final int totalBytes;
  final double elapsedSeconds;
  final double filesPerSecond;
  final double bytesPerSecond;

  /// Byte-based completion fraction; falls back to file counts when byte
  /// totals are unknown.
  double get progress =>
      totalBytes > 0 ? downloadedBytes / totalBytes : (total > 0 ? downloaded / total : 0);
}

class MultiProvisionerCreating extends MultiProvisionerState {
  const MultiProvisionerCreating({this.done = 0, this.total = 0});

  final int done;
  final int total;

  double get progress => total > 0 ? done / total : 0;
}

class MultiProvisionerComplete extends MultiProvisionerState {
  const MultiProvisionerComplete({required this.checkoutIds});

  final IList<String> checkoutIds;
}

class MultiProvisionerFatal extends MultiProvisionerState {
  const MultiProvisionerFatal({required this.message, this.retryable = true});

  final String message;
  final bool retryable;
}
