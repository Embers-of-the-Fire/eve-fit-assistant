import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:intl/intl.dart";

extension DateTimeConstructorExt on DateTime {
  DateTime fromSecondsSinceEpoch(int seconds) =>
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
}

DateFormat yMMMMdHmsLocalized(BuildContext context) =>
    (DateFormat.yMMMMd(context.locale.toString())..add_Hms());
