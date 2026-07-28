import "dart:async";
import "dart:collection";

/// Fetches a value for a typeID; `null` when unavailable.
typedef PriceFetcher<T> = Future<T?> Function(int typeId);

class _PriceRequest<T> {
  _PriceRequest({required this.typeId});

  final int typeId;
  final Completer<T?> completer = Completer<T?>();
}

/// Fixed pool of workers draining a queue of price requests.
///
/// - In-flight requests are deduplicated by typeId: a second request for a
///   type already queued or in flight returns the same future.
/// - At most `workerCount` fetches run concurrently (default 4), shielding
///   the fragile upstream API from request bursts when a fit opens.
/// - Individual failures resolve to `null`; they never fail other requests.
class PriceWorkerPool<T> {
  PriceWorkerPool({required PriceFetcher<T> fetcher, int workerCount = defaultWorkerCount})
    : _fetcher = fetcher,
      _workerCount = workerCount;

  static const defaultWorkerCount = 4;

  final PriceFetcher<T> _fetcher;
  final int _workerCount;
  final Queue<_PriceRequest<T>> _queue = Queue<_PriceRequest<T>>();
  final Map<int, _PriceRequest<T>> _pending = {};
  var _activeWorkers = 0;

  /// Requests the value for [typeId].
  Future<T?> request({required int typeId}) {
    final existing = _pending[typeId];
    if (existing != null) return existing.completer.future;

    final request = _PriceRequest<T>(typeId: typeId);
    _pending[typeId] = request;
    _queue.add(request);
    _pump();
    return request.completer.future;
  }

  void _pump() {
    while (_activeWorkers < _workerCount && _queue.isNotEmpty) {
      final request = _queue.removeFirst();
      _activeWorkers++;
      unawaited(_work(request));
    }
  }

  Future<void> _work(_PriceRequest<T> request) async {
    try {
      final price = await _fetcher(request.typeId);
      request.completer.complete(price);
    } on Object {
      request.completer.complete(null);
    } finally {
      _pending.remove(request.typeId);
      _activeWorkers--;
      _pump();
    }
  }
}
