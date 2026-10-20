import "package:efa_proto/server_history.pb.dart";
import "package:eve_fit_assistant/features/remote_content/channel.dart";

/// Client-side data cadence tiers over a channel's promoted history.
///
/// The tier selects which history entry a checkout tracks: [immediate] follows
/// the head, [weekly]/[monthly] lag behind fixed UTC boundaries. On the
/// testing channel the effective tier is always [immediate]
/// ([effectiveTier]); the stored preference is retained but inert there.
enum DataCadence {
  immediate("immediate"),
  weekly("weekly"),
  monthly("monthly");

  const DataCadence(this.value);

  final String value;

  /// The default tier for new installations.
  static const fallback = DataCadence.weekly;

  static DataCadence? tryParse(String value) {
    for (final tier in DataCadence.values) {
      if (tier.value == value) return tier;
    }
    return null;
  }

  static DataCadence parse(String value) => tryParse(value) ?? fallback;
}

/// The effective tier for [channel]: testing always tracks immediately.
DataCadence effectiveTier(Channel channel, DataCadence preference) =>
    channel == Channel.testing ? DataCadence.immediate : preference;

/// The most recent Monday 00:00:00 UTC at or before [now].
DateTime weekBoundaryUtc(DateTime now) {
  final n = now.toUtc();
  final midnight = DateTime.utc(n.year, n.month, n.day);
  return midnight.subtract(Duration(days: midnight.weekday - DateTime.monday));
}

/// The most recent 1st-of-month 00:00:00 UTC at or before [now].
DateTime monthBoundaryUtc(DateTime now) {
  final n = now.toUtc();
  return DateTime.utc(n.year, n.month);
}

/// Resolves the tracked history entry for [tier] over a newest-first
/// [history] (the promoted sequence of one server).
///
/// - [DataCadence.immediate]: the head entry.
/// - [DataCadence.weekly]: the newest entry promoted strictly before the most
///   recent Monday 00:00:00 UTC.
/// - [DataCadence.monthly]: the newest entry promoted strictly before the most
///   recent 1st-of-month 00:00:00 UTC.
///
/// When no entry precedes the boundary (bootstrap states only), resolves to
/// the oldest entry. Returns null for an empty history.
ServerHistory_Snapshot? resolveCheckout(
  DataCadence tier,
  List<ServerHistory_Snapshot> history,
  DateTime nowUtc,
) {
  if (history.isEmpty) return null;
  return switch (tier) {
    DataCadence.immediate => history.first,
    DataCadence.weekly => _resolveBeforeBoundary(history, weekBoundaryUtc(nowUtc)),
    DataCadence.monthly => _resolveBeforeBoundary(history, monthBoundaryUtc(nowUtc)),
  };
}

ServerHistory_Snapshot _resolveBeforeBoundary(
  List<ServerHistory_Snapshot> history,
  DateTime boundary,
) {
  for (final entry in history) {
    final promotedAt = DateTime.tryParse(entry.timestamp)?.toUtc();
    if (promotedAt != null && promotedAt.isBefore(boundary)) return entry;
  }
  return history.last;
}
