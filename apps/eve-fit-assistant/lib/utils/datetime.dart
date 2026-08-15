import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";

extension DateTimeConstructorExt on DateTime {
  DateTime fromSecondsSinceEpoch(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
}

DateFormat yMMMMdHmsLocalized(BuildContext context) =>
    (DateFormat.yMMMMd(context.locale.toString())..add_Hms());

extension DurationExt on Duration {
  String format() {
    final sign = isNegative ? "-" : "";
    String pad(int n) => n.toString().padLeft(2, "0");
    final hour = pad(inHours);
    final min = pad(inMinutes.remainder(60).abs());
    final sec = pad(inSeconds.remainder(60).abs());
    return "$sign$hour:$min:$sec";
  }
}
