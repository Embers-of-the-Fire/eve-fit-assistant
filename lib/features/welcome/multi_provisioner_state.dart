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
  const MultiProvisionerDownloading({required this.downloaded, required this.total});

  final int downloaded;
  final int total;

  double get progress => total > 0 ? downloaded / total : 0;
}

class MultiProvisionerCreating extends MultiProvisionerState {
  const MultiProvisionerCreating({this.done = 0, this.total = 0});

  final int done;
  final int total;
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
