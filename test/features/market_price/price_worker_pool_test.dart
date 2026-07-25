import "dart:async";

import "package:eve_fit_assistant/features/market_price/state/state.dart";
import "package:flutter_test/flutter_test.dart";

void main() {
  group("PriceWorkerPool", () {
    test("deduplicates concurrent requests for the same typeId", () async {
      var fetchCount = 0;
      final pool = PriceWorkerPool(
        fetcher: (typeId) async {
          fetchCount++;
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 1.0;
        },
      );

      final results = await Future.wait([
        pool.request(typeId: 587),
        pool.request(typeId: 587),
        pool.request(typeId: 587),
      ]);

      expect(fetchCount, 1);
      expect(results, [1.0, 1.0, 1.0]);
    });

    test("caps concurrency at the worker count", () async {
      const workerCount = 2;
      const requestCount = 6;
      var active = 0;
      var maxActive = 0;
      final completers = <Completer<double?>>[];

      final pool = PriceWorkerPool(
        workerCount: workerCount,
        fetcher: (typeId) {
          active++;
          if (active > maxActive) maxActive = active;
          final completer = Completer<double?>();
          completers.add(completer);
          return completer.future.whenComplete(() => active--);
        },
      );

      final futures = [for (var i = 0; i < requestCount; i++) pool.request(typeId: i)];

      // Only workerCount requests should have started.
      await Future<void>.delayed(Duration.zero);
      expect(completers.length, workerCount);
      expect(maxActive, workerCount);

      // Drain the queue one at a time; concurrency must never exceed the cap.
      for (var i = 0; i < requestCount; i++) {
        completers[i].complete(i.toDouble());
        await Future<void>.delayed(Duration.zero);
        expect(maxActive, workerCount);
      }

      expect(await Future.wait(futures), [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]);
    });

    test("defaults to 4 workers", () async {
      var active = 0;
      var maxActive = 0;
      final gate = Completer<void>();

      final pool = PriceWorkerPool(
        fetcher: (typeId) async {
          active++;
          if (active > maxActive) maxActive = active;
          await gate.future;
          active--;
          return 1.0;
        },
      );

      final futures = [for (var i = 0; i < 8; i++) pool.request(typeId: i)];
      await Future<void>.delayed(Duration.zero);
      expect(maxActive, PriceWorkerPool.defaultWorkerCount);

      gate.complete();
      await Future.wait(futures);
    });

    test("a fetcher throw resolves to null without failing other requests", () async {
      final pool = PriceWorkerPool(
        fetcher: (typeId) async {
          if (typeId == 1) throw StateError("boom");
          return 2.0;
        },
      );

      final results = await Future.wait([pool.request(typeId: 1), pool.request(typeId: 2)]);

      expect(results, [isNull, 2.0]);
    });

    test("a typeId can be requested again after the first request resolves", () async {
      var fetchCount = 0;
      final pool = PriceWorkerPool(fetcher: (typeId) async => ++fetchCount * 1.0);

      expect(await pool.request(typeId: 587), 1.0);
      expect(await pool.request(typeId: 587), 2.0);
      expect(fetchCount, 2);
    });
  });
}
