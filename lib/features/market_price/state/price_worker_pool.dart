import "dart:async";
import "dart:collection";

/// Fetches the unit price for a typeID; `null` when unavailable.
typedef PriceFetcher = Future<double?> Function(int typeId);

class _PriceRequest {
  _PriceRequest({required this.typeId});

  final int typeId;
  final Completer<double?> completer = Completer<double?>();
}

/// Fixed pool of workers draining a queue of price requests.
///
/// - In-flight requests are deduplicated by typeId: a second request for a
///   type already queued or in flight returns the same future.
/// - At most `workerCount` fetches run concurrently (default 4), shielding
///   the fragile upstream API from request bursts when a fit opens.
/// - Individual failures resolve to `null`; they never fail other requests.
class PriceWorkerPool {
  PriceWorkerPool({required PriceFetcher fetcher, int workerCount = defaultWorkerCount})
    : _fetcher = fetcher,
      _workerCount = workerCount;

  static const defaultWorkerCount = 4;

  final PriceFetcher _fetcher;
  final int _workerCount;
  final Queue<_PriceRequest> _queue = Queue<_PriceRequest>();
  final Map<int, _PriceRequest> _pending = {};
  var _activeWorkers = 0;

  /// Requests the unit price for [typeId].
  Future<double?> request({required int typeId}) {
    final existing = _pending[typeId];
    if (existing != null) return existing.completer.future;

    final request = _PriceRequest(typeId: typeId);
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

  Future<void> _work(_PriceRequest request) async {
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
