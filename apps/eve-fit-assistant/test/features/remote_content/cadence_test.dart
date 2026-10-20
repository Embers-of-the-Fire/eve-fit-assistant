@TestOn("vm")
library;

import "package:efa_proto/server_history.pb.dart";
import "package:eve_fit_assistant/features/remote_content/cadence.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";
import "package:flutter_test/flutter_test.dart";

ServerHistory_Snapshot _snap(String hash, String timestamp) =>
    ServerHistory_Snapshot(snapshotHash: hash, timestamp: timestamp);

void main() {
  group("boundary math", () {
    test("weekBoundaryUtc returns the most recent Monday 00:00:00 UTC", () {
      // 2026-06-17 is a Wednesday.
      final boundary = weekBoundaryUtc(DateTime.utc(2026, 6, 17, 12, 34, 56));
      expect(boundary, DateTime.utc(2026, 6, 15));
      expect(boundary.isUtc, isTrue);
      expect(boundary.weekday, DateTime.monday);
    });

    test("weekBoundaryUtc at exactly Monday midnight is that midnight", () {
      final boundary = weekBoundaryUtc(DateTime.utc(2026, 6, 15));
      expect(boundary, DateTime.utc(2026, 6, 15));
    });

    test("monthBoundaryUtc returns the most recent 1st-of-month 00:00:00 UTC", () {
      expect(monthBoundaryUtc(DateTime.utc(2026, 6, 17, 12)), DateTime.utc(2026, 6, 1));
      expect(monthBoundaryUtc(DateTime.utc(2026, 6, 1)), DateTime.utc(2026, 6, 1));
      expect(monthBoundaryUtc(DateTime.utc(2026, 3, 1, 0, 0, 1)), DateTime.utc(2026, 3, 1));
    });

    test("boundaries are computed in UTC regardless of input zone", () {
      // A local-time DateTime one hour ahead of UTC must not shift the boundary.
      final local = DateTime(2026, 6, 17, 14, 0, 0);
      final boundary = weekBoundaryUtc(local);
      expect(boundary.isUtc, isTrue);
      expect(boundary.weekday, DateTime.monday);
      expect(boundary.hour, 0);
    });
  });

  group("resolveCheckout", () {
    // 2026-06-17 (Wed): weekly boundary 2026-06-15, monthly boundary 2026-06-01.
    final now = DateTime.utc(2026, 6, 17, 12);

    test("immediate resolves to the head entry", () {
      final history = [_snap("s3", "2026-06-16T00:00:00Z"), _snap("s2", "2026-06-10T00:00:00Z")];
      expect(resolveCheckout(DataCadence.immediate, history, now)?.snapshotHash, "s3");
    });

    test("weekly resolves the newest entry before the Monday boundary", () {
      final history = [
        _snap("s3", "2026-06-16T00:00:00Z"), // after the boundary — not yet eligible
        _snap("s2", "2026-06-10T00:00:00Z"),
        _snap("s1", "2026-05-20T00:00:00Z"),
      ];
      expect(resolveCheckout(DataCadence.weekly, history, now)?.snapshotHash, "s2");
    });

    test("monthly resolves the newest entry before the 1st-of-month boundary", () {
      final history = [
        _snap("s3", "2026-06-16T00:00:00Z"),
        _snap("s2", "2026-06-10T00:00:00Z"),
        _snap("s1", "2026-05-20T00:00:00Z"),
      ];
      expect(resolveCheckout(DataCadence.monthly, history, now)?.snapshotHash, "s1");
    });

    test("an entry exactly at the weekly boundary is not yet eligible", () {
      final history = [
        _snap("s2", "2026-06-15T00:00:00Z"), // exactly at the boundary
        _snap("s1", "2026-06-10T00:00:00Z"),
      ];
      expect(resolveCheckout(DataCadence.weekly, history, now)?.snapshotHash, "s1");
    });

    test("an entry exactly at the monthly boundary is not yet eligible", () {
      final history = [
        _snap("s2", "2026-06-01T00:00:00Z"), // exactly at the boundary
        _snap("s1", "2026-05-20T00:00:00Z"),
      ];
      expect(resolveCheckout(DataCadence.monthly, history, now)?.snapshotHash, "s1");
    });

    test("falls back to the oldest entry when none precedes the boundary", () {
      final history = [_snap("s2", "2026-06-16T00:00:00Z"), _snap("s1", "2026-06-15T12:00:00Z")];
      expect(resolveCheckout(DataCadence.weekly, history, now)?.snapshotHash, "s1");
      expect(resolveCheckout(DataCadence.monthly, history, now)?.snapshotHash, "s1");
    });

    test("single-entry history resolves to itself on every tier", () {
      final history = [_snap("s1", "2026-06-16T00:00:00Z")];
      for (final tier in DataCadence.values) {
        expect(resolveCheckout(tier, history, now)?.snapshotHash, "s1");
      }
    });

    test("empty history resolves to null", () {
      expect(resolveCheckout(DataCadence.immediate, const [], now), isNull);
    });

    test("unparseable timestamps are skipped during boundary resolution", () {
      final history = [_snap("s2", "not-a-date"), _snap("s1", "2026-06-10T00:00:00Z")];
      expect(resolveCheckout(DataCadence.weekly, history, now)?.snapshotHash, "s1");
    });
  });

  group("effectiveTier", () {
    test("testing always tracks immediately", () {
      for (final tier in DataCadence.values) {
        expect(effectiveTier(Channel.testing, tier), DataCadence.immediate);
      }
    });

    test("stable uses the stored preference", () {
      for (final tier in DataCadence.values) {
        expect(effectiveTier(Channel.stable, tier), tier);
      }
    });
  });

  group("DataCadence parsing", () {
    test("round-trips all tiers", () {
      for (final tier in DataCadence.values) {
        expect(DataCadence.parse(tier.value), tier);
      }
    });

    test("unknown values fall back to weekly", () {
      expect(DataCadence.parse("yearly"), DataCadence.weekly);
      expect(DataCadence.tryParse("yearly"), isNull);
    });
  });
}
