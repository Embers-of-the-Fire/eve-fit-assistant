// ignore_for_file: avoid_annotating_with_dynamic
// ignore_for_file: avoid_dynamic_calls

import "dart:convert";

/// Encode `any` with json, using the `toJson` function.
/// For example,  `@freezed` or `@JsonSerializable()` values.
String debugDisplayJsonSerializable(dynamic any) =>
    const JsonEncoder.withIndent("    ").convert(any.toJson());
