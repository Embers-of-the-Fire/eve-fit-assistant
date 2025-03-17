part of 'utils.dart';

extension DurationExt on Duration {
  String format() {
    final sign = isNegative ? '-' : '';
    String pad(int n) => n.toString().padLeft(2, '0');
    final hour = pad(inHours);
    final min = pad(inMinutes.remainder(60).abs());
    final sec = pad(inSeconds.remainder(60).abs());
    return '$sign$hour:$min:$sec';
  }
}

DateTime fromSecondsSinceEpoch(int seconds) => DateTime.fromMillisecondsSinceEpoch(seconds * 1000);

DateTime fromDaysSinceEpoch(int days) => DateTime.fromMillisecondsSinceEpoch(days * 86400000);
