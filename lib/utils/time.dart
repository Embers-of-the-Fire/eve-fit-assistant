extension DurationExt on Duration {
  String format() {
    String sign = isNegative ? '-' : '';
    String pad(int n) => n.toString().padLeft(2, '0');
    String hour = pad(inHours);
    String min = pad(inMinutes.remainder(60).abs());
    String sec = pad(inSeconds.remainder(60).abs());
    return '$sign$hour:$min:$sec';
  }
}
