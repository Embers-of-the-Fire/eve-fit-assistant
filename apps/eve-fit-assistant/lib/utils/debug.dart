// ignore_for_file: avoid_annotating_with_dynamic
// ignore_for_file: avoid_dynamic_calls

import "dart:convert";

import "package:eve_fit_assistant/config/logger.dart";

/// Encode `any` with json, using the `toJson` function.
/// For example,  `@freezed` or `@JsonSerializable()` values.
String debugDisplayJsonSerializable(dynamic any) =>
    const JsonEncoder.withIndent("    ").convert(any.toJson());

T debugInspect<T>(T value, [String? label]) {
  debug("DEBUG${label != null ? " [$label]" : ""}: $value");
  return value;
}
